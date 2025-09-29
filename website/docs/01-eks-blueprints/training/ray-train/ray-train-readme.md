---
title: Ray Train
sidebar_position: 2
sidebar_label: Ray Train
---

# Ray Train on HyperPod EKS

[Ray](https://www.ray.io/) is an open-source distributed computing framework designed to run highly scalable and parallel Python applications. Ray manages, executes, and optimizes compute needs across AI workloads. It unifies infrastructure via a single, flexible framework—enabling any AI workload from data processing to model training to model serving and beyond.

This example showcases how to get started with deploying a RayCluster for model training on SageMaker HyperPod. It demonstrates multi-node [FSDP](https://pytorch.org/tutorials/intermediate/FSDP_tutorial.html) training using [PyTorch Lightning](https://lightning.ai/docs/pytorch/stable/) with Ray on Amazon EKS.

## Prerequisites

Before running this training, ensure you have:

- A functional HyperPod EKS cluster on AWS with GPU device plugin deployed
- An FSx for Lustre filesystem with a persistent volume claim (PVC)
- Docker installed for building container images
- A x86-64 based development environment (use SageMaker Code Editor if on ARM-based systems)

### Verified Instance Types

- **ml.g5.8xlarge x 8** - used for training section

## 1. Setup

### 1.1 Verify Connection to HyperPod Cluster

Verify your connection to the HyperPod cluster:

```bash
kubectl get nodes -L node.kubernetes.io/instance-type -L sagemaker.amazonaws.com/node-health-status -L sagemaker.amazonaws.com/deep-health-check-status
```

Expected output:
```
NAME                           STATUS   ROLES    AGE   VERSION               INSTANCE-TYPE   NODE-HEALTH-STATUS   DEEP-HEALTH-CHECK-STATUS
hyperpod-i-01f3dccc49d2f1292   Ready    <none>   15d   v1.31.6-eks-1552ad0   ml.g5.8xlarge   Schedulable          Passed
hyperpod-i-0499da6bcd94f240b   Ready    <none>   15d   v1.31.6-eks-1552ad0   ml.g5.8xlarge   Schedulable          Passed
...
```

### 1.2 Install Ray

Install Ray on your local environment:

```bash
pip install -U "ray[default]"
```

### 1.3 Setup Dependencies

Set up the KubeRay operator to manage Ray clusters:

```bash
# Create KubeRay namespace
kubectl create namespace kuberay

# Deploy the KubeRay operator with the Helm chart repository
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Install both CRDs and KubeRay operator v1.1.0
helm install kuberay-operator kuberay/kuberay-operator --version 1.1.0 --namespace kuberay

# Verify KubeRay operator deployment
kubectl get pods --namespace kuberay
```

Verify the KubeRay operator is running:

```bash
kubectl get pods -n kuberay
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
kuberay-operator-cdc889475-dfmsc   1/1     Running   0          15d
```

### 1.4 Verify Persistent Volume Claims

Ensure you have an active PVC with status "Bound":

```bash
kubectl get pvc
```

Expected output:
```
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
fsx-claim   Bound    pvc-8a696249-051d-4d4e-8908-bdb6c66ddbca   1200Gi     RWX            fsx-sc         18d
```

## 2. Create Ray Container Image

### 2.1 Create Dockerfile

With the recent [deprecation](https://github.com/ray-project/ray/issues/46378) of the `rayproject/ray-ml` images starting from Ray version 2.31.0, create a custom container image using our [nccl-tests public container image](https://gallery.ecr.aws/hpc-cloud/nccl-tests) as a base image:

```bash
cat <<EOF > Dockerfile
FROM public.ecr.aws/hpc-cloud/nccl-tests:latest

# Create ray user and home directory
RUN useradd -m -d /home/ray ray && \
    chown -R ray:ray /home/ray

COPY --from=rayproject/ray:2.42.1-py310-gpu /home/ray/requirements_compiled.txt /tmp/

# Install anaconda if it's not in base image
RUN if [ ! -d "/opt/anaconda3" ]; then \
    wget https://repo.anaconda.com/archive/Anaconda3-2023.09-0-Linux-x86_64.sh -O /tmp/anaconda.sh && \
    bash /tmp/anaconda.sh -b -p /opt/anaconda3 && \
    rm /tmp/anaconda.sh; \
    fi

# Add anaconda to system-wide PATH
ENV PATH=/opt/anaconda3/bin:$PATH

# Install Ray and dependencies
RUN pip --no-cache-dir install -c /tmp/requirements_compiled.txt \
    "ray[all]==2.42.1"

# Install Python dependencies for PyTorch, Ray, Hugging Face, and more
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    numpy \
    pytorch-lightning \
    transformers datasets evaluate tqdm click \
    ray[train] ray[air] \
    ray[train-torch] ray[train-lightning] \
    torchdata \
    torchmetrics \
    torch_optimizer \
    accelerate \
    scikit-learn \
    Pillow==9.5.0 \
    protobuf==3.20.3

RUN pip install --upgrade datasets transformers

# Save pip freeze output
RUN pip freeze > /home/ray/pip-freeze.txt && \
    chown ray:ray /home/ray/pip-freeze.txt

# Cleanup
RUN rm -rf /tmp/requirements_compiled.txt

# Set the user
USER ray
WORKDIR /home/ray

# Verify ray installation
RUN which ray && \
    ray --version

# Default command
CMD [ "/bin/bash" ]
EOF
```

### 2.2 Build and Push Container Image

Build and push the image to Amazon ECR:

```bash
export AWS_REGION=$(aws configure get region)
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/

echo "This process may take 10-15 minutes to complete..."
echo "Building image..."

docker build --platform linux/amd64 -t ${REGISTRY}aws-ray-custom:latest .

# Create registry if needed
REGISTRY_COUNT=$(aws ecr describe-repositories | grep \"aws-ray-custom\" | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
    aws ecr create-repository --repository-name aws-ray-custom
fi

# Login to registry
echo "Logging in to $REGISTRY ..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY

echo "Pushing image to $REGISTRY ..."

# Push image to registry
docker image push ${REGISTRY}aws-ray-custom:latest
```

## 3. Create and Deploy RayCluster

### 3.1 Create RayCluster Manifest

Create a Ray cluster manifest that defines the head node and worker nodes:

```bash
cat <<'EOF' > raycluster.yaml
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  name: rayml
  labels:
    controller-tools.k8s.io: "1.0"
spec:
  # Ray head pod template
  headGroupSpec:
    rayStartParams:
      dashboard-host: '0.0.0.0'
    template:
      spec:
        securityContext:
          runAsUser: 0
          runAsGroup: 0
          fsGroup: 0
        containers:
        - name: ray-head
          image: ${REGISTRY}aws-ray-custom:latest
          env:
            - name: RAY_GRAFANA_IFRAME_HOST
              value: http://localhost:3000
            - name: RAY_GRAFANA_HOST
              value: http://prometheus-grafana.prometheus-system.svc:80
            - name: RAY_PROMETHEUS_HOST
              value: http://prometheus-kube-prometheus-prometheus.prometheus-system.svc:9090
            - name: FI_PROVIDER
              value: "efa"
            - name: NCCL_DEBUG
              value: "INFO"
            - name: FI_LOG_LEVEL
              value: "warn"
            - name: NCCL_SOCKET_IFNAME
              value: "eth0"
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh","-c","ray stop"]
          resources:
            limits:
              cpu: 1
              memory: 8Gi
            requests:
              cpu: 1
              memory: 8Gi
          ports:
          - containerPort: 6379
            name: gcs-server
          - containerPort: 8265 # Ray dashboard
            name: dashboard
          - containerPort: 10001
            name: client
          - containerPort: 8000
            name: serve
          volumeMounts:
          - name: fsx-storage
            mountPath: /fsx
          - name: ray-logs
            mountPath: /tmp/ray
        volumes:
          - name: ray-logs
            emptyDir: {}
          - name: fsx-storage
            persistentVolumeClaim:
              claimName: fsx-claim
  workerGroupSpecs:
  - replicas: 8
    minReplicas: 1
    maxReplicas: 10
    groupName: gpu-group
    rayStartParams:
      num-gpus: "1"
    template:
      spec:
        securityContext:
          runAsUser: 0
          runAsGroup: 0
          fsGroup: 0
        containers:
        - name: ray-worker
          image: ${REGISTRY}aws-ray-custom:latest
          env:
            - name: FI_PROVIDER
              value: "efa"
            - name: NCCL_DEBUG
              value: "INFO"
            - name: FI_LOG_LEVEL
              value: "warn"
            - name: NCCL_SOCKET_IFNAME
              value: "eth0"
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh","-c","ray stop"]
          resources:
            limits:
              nvidia.com/gpu: 1
              vpc.amazonaws.com/efa: 1
            requests:
              nvidia.com/gpu: 1
              vpc.amazonaws.com/efa: 1
          volumeMounts:
          - name: ray-logs
            mountPath: /tmp/ray
          - name: fsx-storage
            mountPath: /fsx
        volumes:
        - name: fsx-storage
          persistentVolumeClaim:
            claimName: fsx-claim
        - name: ray-logs
          emptyDir: {}
EOF
```

:::info
If you want to use a different file system, change `claimName` to your desired PVC. Check available PVCs with `kubectl get pvc`.
:::

### 3.2 Deploy the RayCluster

Deploy the RayCluster using environment variable substitution:

```bash
envsubst < raycluster.yaml | kubectl apply -f -
```

:::info
We use `envsubst` to substitute the `${REGISTRY}` variable. If you don't have envsubst, manually replace the variable in the YAML or install it following [this documentation](https://github.com/a8m/envsubst).
:::

### 3.3 Verify RayCluster Deployment

Check the status of your RayCluster:

```bash
kubectl get pods
```

Expected output:
```
NAME                           READY   STATUS    RESTARTS   AGE
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-gpu-group-worker-xxxx   1/1     Running   0          3d3h
rayml-head-xxxx               1/1     Running   0          3d3h
```

### 3.4 Expose Ray Dashboard

To access the Ray dashboard for monitoring cluster status, job submissions, and resource utilization:

```bash
# Get the name of the head service
export SERVICEHEAD=$(kubectl get service | grep head-svc | awk '{print $1}' | head -n 1)

# Port forward the dashboard
kubectl port-forward --address 0.0.0.0 service/${SERVICEHEAD} 8265:8265 > /dev/null 2>&1 &
```

You can now access the Ray dashboard at `http://localhost:8265`.

## 4. Submit Training Job

### 4.1 Download Training Code

Download the aws-do-ray repository which contains the training code:

```bash
git clone https://github.com/aws-samples/aws-do-ray.git
cd aws-do-ray/Container-Root/ray/raycluster/jobs/
```

### 4.2 Configure Training Parameters

The training job uses FSDP (Fully Sharded Data Parallel) with PyTorch Lightning. To utilize all GPU nodes, modify the scaling configuration:

```bash
vim fsdp-ray/fsdp-ray.py
```

In the main function, edit the `scaling_config` to use 8 workers (one for each GPU instance):

```python
# Schedule workers for FSDP training (1 GPU/worker by default)
scaling_config = ScalingConfig(
    num_workers=8,  # Change from 2 to 8
    use_gpu=True,
    resources_per_worker={"GPU": 1, "CPU": 3}
)
```

### 4.3 Submit Training Job

You can submit the training job using two methods:

#### Method 1: Ray Jobs Submission SDK

```bash
# Within jobs/ folder
ray job submit --address http://localhost:8265 --working-dir "fsdp-ray" -- python3 fsdp-ray.py
```

#### Method 2: Execute in Head Pod

```bash
# Get head pod name
head_pod=$(kubectl get pods --selector=ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers)

# Copy the script to the head pod
kubectl cp "fsdp-ray/fsdp-ray.py" "$head_pod:/tmp/fsdp-ray.py"

# Run the Python script on the head pod
kubectl exec -it "$head_pod" -- python /tmp/fsdp-ray.py
```

### 4.4 Monitor Training

The training job will:
- Preprocess the CoLA dataset with Ray Data
- Define a training function with PyTorch Lightning
- Launch distributed training with Ray Train's TorchTrainer

Expected output:
```
Training started with configuration:
╭──────────────────────────────────────╮
│ Training config                      │
├──────────────────────────────────────┤
│ train_loop_config/batch_size      16 │
│ train_loop_config/eps          1e-08 │
│ train_loop_config/lr           1e-05 │
│ train_loop_config/max_epochs       5 │
╰──────────────────────────────────────╯
```

You can monitor the training progress through:
- **Ray Dashboard**: View job status, resource utilization, and logs at `http://localhost:8265`
- **Terminal logs**: Follow the training progress in your terminal
- **Shared filesystem**: Trained models will be saved to your FSx filesystem

## 5. What's Next?

- **Model Output**: Your trained model will be saved to the shared file system (`/fsx`)
- **Experiment with other models**: Try training other example models in the repository
- **Explore Ray features**: Check out the Ray decorators and distributed computing capabilities
- **Scale your workloads**: Modify the RayCluster configuration for different instance types and counts
- **Inference**: We will deploy RayService for inference in the inference section of this repository. 

For more information on RayCluster configurations, see the [Ray documentation](https://docs.ray.io/en/latest/cluster/kubernetes/user-guides/config.html).

For additional examples and configurations, refer to the [aws-do-ray repository](https://github.com/aws-samples/aws-do-ray).