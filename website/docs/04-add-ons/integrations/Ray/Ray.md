---
sidebar_position: 1
---

# Ray
[Ray](https://www.ray.io/) is an open-source distributed computing framework designed to run highly scalable and parallel python applications. Ray manages, executes, and optimizes compute needs across AI workloads. It unifies infrastructure via a single, flexible framework—enabling any AI workload from data processing to model training to model serving and beyond.

For this part of the workshop, we will be utilizing the aws-do-ray repository which containerizes all tools necessary to deploy and manage Ray clusters, jobs, and services.
<div className="text--center"> 
![Ray on Hyperpod](/img/ray/ray-hyperpod-arch.png)
</div>


## 1. Verify connection to hyperpod cluster

Please run:

``` bash
kubectl get nodes -L node.kubernetes.io/instance-type -L sagemaker.amazonaws.com/node-health-status -L sagemaker.amazonaws.com/deep-health-check-status $@
```

Example output:
  ```
  NAME                           STATUS   ROLES    AGE   VERSION               INSTANCE-TYPE   NODE-HEALTH-STATUS   DEEP-HEALTH-CHECK-STATUS
  hyperpod-i-01f3dccc49d2f1292   Ready    <none>   15d   v1.31.6-eks-1552ad0   ml.g5.8xlarge   Schedulable          Passed
  hyperpod-i-0499da6bcd94f240b   Ready    <none>   15d   v1.31.6-eks-1552ad0   ml.g5.8xlarge   Schedulable          Passed
  ...
  ...
  ```
## 2. Install Ray
Please install Ray by running:

``` bash
pip install -U "ray[default]"
```

Source is from this [documentation](https://docs.ray.io/en/latest/ray-overview/installation.html). 

## 2. Setup dependencies

Let's set up dependences to deploy a Ray cluster by running:

``` bash
# Create KubeRay namespace
kubectl create namespace kuberay
# Deploy the KubeRay operator with the Helm chart repository
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update
#Install both CRDs and Kuberay operator v1.1.0
helm install kuberay-operator kuberay/kuberay-operator --version 1.1.0 --namespace kuberay
# Kuberay operator pod will be deployed onto head pod
kubectl get pods --namespace kuberay

```


  To ensure we have the KubeRay operator, please run:
``` bash
  kubectl get pods -n kuberay
```

You should see example output:

```
NAME                               READY   STATUS    RESTARTS   AGE
kuberay-operator-cdc889475-dfmsc   1/1     Running   0          15d
```
## 3. List avaialble persistent volume claims (PVC) (required only for training)
A PVC is needed for distributed training jobs. If you only inted to run inference jobs, you may skip this step.
Please ensure you have an active PVC with status bound by running:
``` bash
kubectl get pvc
```
Example output:
```
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
fsx-claim   Bound    pvc-8a696249-051d-4d4e-8908-bdb6c66ddbca   1200Gi     RWX            fsx-sc         <unset>                 18d
```

Now we are all set to use Ray, next up is setting up a Ray cluster and running a training job. 

# Training a PyTorch Lightning Text Classifier with Ray Data
In this section we will be using a RayCluster to do our training jobs. The RayCluster is the primary resource for managing Ray instances on Kubernetes. It represents a cluster of Ray nodes, including a head node and multiple worker nodes. The RayCluster CRD determines how the Ray nodes are set up, how they communicate, and how resources are allocated among them. The nodes in a Ray cluster manifest as pods in the EKS cluster.

## 1. Create a RayCluster

### 1a. Create a Ray Container image for the Ray Cluster manifest.

With the recent [deprecation](https://github.com/ray-project/ray/issues/46378) of the `rayproject/ray-ml` images starting from Ray version 2.31.0, it's necessary to create a custom container image from our Ray cluster. Therefore, we will build on top of the `rayproject/ray:2.42.1-py310-gpu` image, which will have all necessary Ray dependencies, and include our training dependencies to build our own custom image. 

First create a Dockerfile that builds upon the base Ray GPU image and includes only the necessary dependencies:

``` bash
cat <<EOF > Dockerfile
 
FROM rayproject/ray:2.42.1-py310-gpu
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

Then, build and push the image to your container registry ([Amazon ECR](https://aws.amazon.com/ecr/)) using the provided script:

::alert[If you are running an AWS event hosted workshop, you may need to enter `AWS_REGION` and `ACCOUNT` manually in the following code snippet. `AWS_REGION` can be found within the `env_vars` file, and `ACCOUNT` can be found on the upper right hand corner of the AWS console.]{header="Note:"}

``` bash
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
aws ecr get-login-password --region $AWS_REGION| docker login --username AWS --password-stdin $REGISTRY
 
echo "Pushing image to $REGISTRY ..."
 
# Push image to registry
docker image push ${REGISTRY}aws-ray-custom:latest 
```

Now, our Ray container image is in the Amazon ECR with all necessary Ray dependencies, as well as code library dependencies.

### 1b. Create a Ray cluster manifest

Create a Ray cluster manifest. We use a Ray cluster to host our training jobs. The Ray cluster is the primary resource for managing Ray instances on Kubernetes. It represents a cluster of Ray nodes, including a head node and multiple worker nodes. The Ray cluster CRD determines how the Ray nodes are set up, how they communicate, and how resources are allocated among them. The nodes in a Ray cluster manifest as pods in the SageMaker HyperPod cluster.


``` bash
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
    # The `rayStartParams` are used to configure the `ray start` command.
    # See https://github.com/ray-project/kuberay/blob/master/docs/guidance/rayStartParams.md for the default settings of `rayStartParams` in KubeRay.
    # See https://docs.ray.io/en/latest/cluster/cli.html#ray-start for all available options in `rayStartParams`.
    rayStartParams:
      dashboard-host: '0.0.0.0'
    #pod template
    template:
      spec:
        #        nodeSelector:  
        #node.kubernetes.io/instance-type: "ml.m5.2xlarge"
        securityContext:
          runAsUser: 0
          runAsGroup: 0
          fsGroup: 0
        containers:
        - name: ray-head
          image: ${REGISTRY}aws-ray-custom:latest     ## IMAGE: Here you may choose which image your head pod will run
          env:                                ## ENV: Here is where you can send stuff to the head pod
            - name: RAY_GRAFANA_IFRAME_HOST   ## PROMETHEUS AND GRAFANA
              value: http://localhost:3000
            - name: RAY_GRAFANA_HOST
              value: http://prometheus-grafana.prometheus-system.svc:80
            - name: RAY_PROMETHEUS_HOST
              value: http://prometheus-kube-prometheus-prometheus.prometheus-system.svc:9090
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh","-c","ray stop"]
          resources:
            limits:                                    ## LIMITS: Set resource limits for your head pod
              cpu: 1
              memory: 8Gi
            requests:                                    ## REQUESTS: Set resource requests for your head pod
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
          volumeMounts:                                    ## VOLUMEMOUNTS
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
  # the pod replicas in this group typed worker
  - replicas: 8                                    ## REPLICAS: How many worker pods you want 
    minReplicas: 1
    maxReplicas: 10
    # logical group name, for this called small-group, also can be functional
    groupName: gpu-group
    rayStartParams:
      num-gpus: "1"
    #pod template
    template:
      spec:
        #nodeSelector:
        # node.kubernetes.io/instance-type: "ml.g5.8xlarge"
        securityContext:
          runAsUser: 0
          runAsGroup: 0
          fsGroup: 0
        containers:
        - name: ray-worker
          image: ${REGISTRY}aws-ray-custom:latest             ## IMAGE: Here you may choose which image your head node will run
          env:
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh","-c","ray stop"]
          resources:
            limits:                                    ## LIMITS: Set resource limits for your worker pods
              nvidia.com/gpu: 1
              #vpc.amazonaws.com/efa: 1  
            requests:                                    ## REQUESTS: Set resource requests for your worker pods
              nvidia.com/gpu: 1
              #vpc.amazonaws.com/efa: 1
          volumeMounts:                                    ## VOLUMEMOUNTS
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

This template has all the basic configurations for a raycluster that will work out of the box, and of course for your own workloads, you can modify this YAML. 

The three main roles of a ray cluster, is the head pod, the worker pods, and the shared file system that will be attached to both the head and worker pods. 


::alert[If you wanted to use another file system, please change claimName to the file system PVC you want to use. To look at your available PVC's, please run `kubectl get pvc`.]{header="Note:"}


::alert[For more information regarding the RayCluster configurations, please see [here](https://docs.ray.io/en/latest/cluster/kubernetes/user-guides/config.html)]{header="Note:"}

Now, our RayCluster is ready to be deployed.



### 1c. Deploy the RayCluster

To deploy our RayCluster, please run:
``` bash
envsubst < raycluster.yaml | kubectl apply -f -
```
::alert[We are using `envsubst` so our `${REGISTRY}` variable gets substituted. If you don't have envsubst, you may manually replace the variable in the yaml, or you can follow this [documentation](https://github.com/a8m/envsubst) to install it.]{header="Note:"}

### 1d. Check RayCluster

To check the status of your RayCluster, please run:

``` bash
kubectl get pods
```

Example output:
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

### 1e. Expose Ray Dashboard

To access the Ray dashboard to see your cluster, job submissions, resource utilization, etc., please run:

``` bash
# Gets name of kubectl service that runs the head pod
export SERVICEHEAD=$(kubectl get service | grep head-svc | awk '{print $1}' | head -n 1)
# Port forwards the dashboard from the head pod service
kubectl port-forward --address 0.0.0.0 service/${SERVICEHEAD} 8265:8265 > /dev/null 2>&1 &
```


Example output:
``` 
Port-forward started, PID 1034 saved in /root/port-forward.pid
Port forwarded, visit http://localhost:8265
```


### 1f. Access Ray Dashboard (Optional)
- Option 1 (Will not work within CloudShell)
This port forwards the Ray Dashboard from the head pod. Please visit `http://localhost:8265` to access dashboard. 

<div className="text--center"> 
![Ray Dashboard](/img/ray/dashboard.png)
</div>

- Option 2 via Load Balancing



Step 1: Create `Ray Dashboard Service` yaml.
``` bash
cat > ray-dashboard.yaml << EOL
apiVersion: v1
kind: Service
metadata:
  name: ray-dashboard
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  selector:
    ray.io/identifier: rayml-head # rayml-head identifies head pod label to forward the dashboard from
  ports:
    - protocol: TCP
      port: 8265
      targetPort: 8265
  type: LoadBalancer
EOL

kubectl apply -f ray-dashboard.yaml
```

Step 2: Please run:
``` bash
kubectl get service
```

Identify the external IP in the `ray-dashboard` service. 
Example:
```
ray-dashboard    LoadBalancer   172.20.113.92   k8s-default-raydashb-48fde72d0e-6b577d91ba407cfc.elb.us-west-2.amazonaws.com   8265:32086/TCP                                  22m
```

**You may need to wait ~2 minutes** for the Load Balancer to finish provisioning. You can check the status in the EC2 Console under EC2 -> Load Balancers. 

Please visit http://< externalIP >:8265

Example:
```
http://k8s-default-raydashb-48fde72d0e-6b577d91ba407cfc.elb.us-west-2.amazonaws.com:8265/
```

## 2. Submit a Training Job

### 2a. Download GitHub repo [aws-do-ray](https://github.com/aws-samples/aws-do-ray/tree/main)

Download aws-do-ray repo. This contains our training code. 

``` bash
git clone https://github.com/aws-samples/aws-do-ray.git
```

Go to job folder directory

``` bash
cd aws-do-ray/Container-Root/ray/raycluster/jobs/
ls
```

### 2b. Submit Training Job
The job we will submit for this workshop is [fsdp-ray](https://docs.ray.io/en/latest/train/examples/lightning/lightning_cola_advanced.html). 

In this code, we:
- Preprocess the CoLA dataset with Ray Data.
- Define a training function with PyTorch Lightning.
- Launch distributed training with Ray Train’s TorchTrainer.

- Note: If you want to look at the code, it is in the `fsdp-ray` folder. 


To launch training job, there are a few options:

1. Using the Ray Jobs submission SDK where you can submit jobs to the RayCluster via the Ray Dashboard port (8265 by default) where Ray listens for Job requests. To learn more, please visit [here](https://docs.ray.io/en/latest/cluster/running-applications/job-submission/quickstart.html#jobs-quickstart)

2. Execute a Ray job in the head pod where you exec directly into the head pod then submit your job. To learn more, please visit [here](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/raycluster-quick-start.html)

I will provide both options where you can choose which you'd like to do, or do both!


Before we submit, to utilize all GPU nodes, we will modify the scaling config in the code. To do this, please run
``` bash
vim fsdp-ray/fsdp-ray.py
```
In the main function (towards the bottom), in the `scaling_config` definition, please edit `num_workers` to be equal to 8. This ensures we will have 8 Ray workers... 1 for each g5 instance. 

Like so:
```
    # Schedule four workers for FSDP training (1 GPU/worker by default)
    scaling_config = ScalingConfig(
        num_workers=8, # Change from 2 to 8
        use_gpu=True,
        resources_per_worker={"GPU": 1, "CPU": 3}
    )
```

1. Ray Jobs Submission SDK
``` bash
# Within jobs/ folder
ray job submit --address http://localhost:8265 --working-dir "fsdp-ray" -- python3 fsdp-ray.py
```

Example output:
```
Job submission server address: http://localhost:8265
2024-11-11 21:58:51,386	INFO dashboard_sdk.py:385 -- Package gcs://_ray_pkg_81c6d19be32949eb.zip already exists, skipping upload.

-------------------------------------------------------
Job 'raysubmit_evBnN4bFCbMZRD22' submitted successfully
-------------------------------------------------------

Next steps
  Query the logs of the job:
    ray job logs raysubmit_evBnN4bFCbMZRD22
  Query the status of the job:
    ray job status raysubmit_evBnN4bFCbMZRD22
  Request the job to be stopped:
    ray job stop raysubmit_evBnN4bFCbMZRD22

Tailing logs until the job exits (disable with --no-wait):
2024-11-11 13:58:51,644	INFO job_manager.py:530 -- Runtime env is setting up.
2024-11-11 13:58:52,994	INFO worker.py:1445 -- Using address 10.1.255.29:6379 set in the environment variable RAY_ADDRESS
2024-11-11 13:58:52,994	INFO worker.py:1585 -- Connecting to existing Ray cluster at address: 10.1.255.29:6379...
2024-11-11 13:58:53,001	INFO worker.py:1761 -- Connected to Ray cluster. View the dashboard at 10.1.255.29:8265 

Parquet Files Sample 0:   0%|          | 0/1 [00:00<?, ?it/s]
                                                             

Parquet Files Sample 0:   0%|          | 0/1 [00:00<?, ?it/s]
                                                             
View detailed results here: /fsx/fsdp/ptl-sent-classification
To visualize your results with TensorBoard, run: `tensorboard --logdir /tmp/ray/session_2024-11-05_13-58-58_643291_8/artifacts/2024-11-11_13-59-18/ptl-sent-classification/driver_artifacts`

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

2. Submitting via head pod

```bash
# Grab name of head pod
head_pod=$(kubectl get pods --selector=ray.io/node-type=head -o custom-columns=POD:metadata.name --no-headers)
# Copy the script to the head pod
kubectl cp "fsdp-ray/fsdp-ray.py" "$head_pod:/tmp/fsdp-ray.py"
# Run the Python script on the head pod
kubectl exec -it "$head_pod" -- python /tmp/fsdp-ray.py
```

Example output:
```
2024-11-11 14:06:58,265	INFO worker.py:1445 -- Using address 127.0.0.1:6379 set in the environment variable RAY_ADDRESS
2024-11-11 14:06:58,265	INFO worker.py:1585 -- Connecting to existing Ray cluster at address: 10.1.255.29:6379...
2024-11-11 14:06:58,272	INFO worker.py:1761 -- Connected to Ray cluster. View the dashboard at 10.1.255.29:8265 
                                                                                                                                        
View detailed results here: /fsx/fsdp/ptl-sent-classification
To visualize your results with TensorBoard, run: `tensorboard --logdir /tmp/ray/session_2024-11-05_13-58-58_643291_8/artifacts/2024-11-11_14-07-22/ptl-sent-classification/driver_artifacts`

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



Now if you wanted to see job logs, resource utilization, etc., not through the terminal, you can access the Ray Dashboard. 

In the dashboard, you will be able to see the submitted job and resource utilization. 
<div className="text--center"> 
![Ray Dashboard Jobs](/img/ray/dashboard-jobs.png)
</div>
<div className="text--center"> 
![Ray Dashboard Metrics](/img/ray/dashboard-metrics.png)
</div>


Your trained model will be outputted in your shared file system! Please feel free to train the other examples models that are listed and check out the code to see the Ray decorators!

Now that we have done some training, let's serve a model for inference. 


# Serving Stable Diffusion Model for Inference


[Ray Serve](https://docs.ray.io/en/latest/serve/index.html) is a scalable model serving library for building online inference APIs. Serve is framework-agnostic, so you can use a single toolkit to serve everything from deep learning models built with frameworks like PyTorch, TensorFlow, and Keras, to Scikit-Learn models, to arbitrary Python business logic.

A Ray Serve manages these components:

- RayCluster: Manages resources in a Kubernetes cluster.

- Ray Serve Applications: Manages users’ applications.



## 1. Create a RayService

Ensure you have aws-do-ray downloaded. If not, please run:

``` bash
git clone https://github.com/aws-samples/aws-do-ray.git
```

Go to job folder directory

Within the /ray directory in `aws-do-ray` repo, you will find the /raycluster directory.

``` bash
cd aws-do-ray/Container-Root/ray/rayservice/
ls
```
As you can see, there are multiple models we can serve for inference. For this workshop we will be deploying the [Stable Diffusion](https://docs.ray.io/en/latest/serve/tutorials/stable-diffusion.html) model. 
These instructions will run Stable Diffusion on CPU. If you prefer to run on a GPU that is available in your cluster, then replace `_cpu` with `_gpu` in the commands below.

Please list files in `stable_diffusion_cpu`:
``` bash
cd stable_diffusion_cpu
ls -alh
```

In here we have 3 files:
1. `rayservice.stable_diffusion_cpu.yaml`: Ray Service yaml 

Here is more information regarding the configuration for Ray Serve applications in the yaml. More details [here](https://docs.ray.io/en/latest/serve/production-guide/kubernetes.html): 

    - applications: A list of applications to be deployed.
    - name: The name of the application, in this case, stable-diffusion-cpu.
    - import_path: The import path for the application's module, stable_diffusion_cpu:entrypoint
    - route_prefix: The route prefix for accessing the application.
    - runtime_env: Specifies the runtime environment for the application.
    - working_dir: The working directory for the application, must point to a zip file locally or through a URI.
    - pip: A list of Python packages to be installed in the runtime environment.
    - deployments: A list of deployments for the application.
    - name: The name of the deployment, stable-diffusion-cpu.
    - num_replicas: The number of replicas for the deployment, set to 1.
    - ray_actor_options: Options for the Ray actors.
    - num_cpus: The number of CPUs allocated for each actor, set to 1.

2. `stable_diffusion_cpu.py`: Python code for processing stable diffusion requests
    - **Scalable Deployment**: Ray Serve dynamically scales the APIIngress and StableDiffusionV2 components based on traffic, managing resources efficiently by adjusting the number of replicas.
    - **Asynchronous Execution**: Using .remote(), Ray handles multiple requests concurrently, distributing tasks across the cluster for responsive API performance.
    - **GPU Resource Management**: If GPU's are used, ray ensures each model replica has a dedicated GPU and optimizes performance through mixed-precision, making inference faster and memory-efficient.

3. `stable_diffusion_req.py`: Python code to send stable diffusion requests


To create a Ray Service deployment, please execute:

```bash
kubectl apply -f rayservice.stable_diffusion_cpu.yaml
```

As our cluster is deploying, we will wait for the RayService Kubernetes service, which is created after the Serve applications are ready and running. This process may take approximately 1 minute after all pods in the RayCluster are running.


To check pods:
```bash
kubectl get pods
```
## 2. Access Ray Dashboard (Optional)

We will provide two ways through which the Ray dashboard can be accessed. 

a. Port-forward the service locally and use a terminal-based browser to view the dashoard

***Open a new bash shell*** by using the `+` button in the upper-right corner of your terminal,
then execute the following command block to display the dashboard using a terminal-based browser:

```bash
kubectl port-forward svc/$(kubectl get svc | grep stable-diffusion-cpu-raycluster | grep head | cut -d ' ' -f 1) 8265 &
docker run $DOCKER_NETWORK --rm -it fathyb/carbonyl http://localhost:8265
```
<div className="text--center"> 
![Terminal-based Ray Dashboard](/img/ray/serve-dashboard-tui.png)
</div>
To exit the browser, just close the shell window.

::alert[If you are having issues port-forwarding, please run: `pkill -f "kubectl port-forward"`, then retry.]{header="Note:"}

or


b. Deploy a load balancer and access the Ray dashboard via public URL (not recommended)

Please note that this method is insecure and is not recommended for use with non-temporary accounts.
Before we can use an ingress object, we must deploy the Load Balancer Controller to the cluster. 
Please follow the instructions in section 9a of this workshop, then return here to create the ingress object. 

1. Please follow steps to create a load balancer in section [Setup Load Balancer Controller in Hyperpod Cluster](/content/09-inference/01-setup.md)

2. Create an Ingress template:

``` bash
# Retrieves name of head pod service
export HEAD_SERVICE=$(kubectl get service --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "raycluster")
export PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters "[ {\"Name\":\"vpc-id\",\"Values\":[\"${VPC_ID}\"]}, {\"Name\":\"map-public-ip-on-launch\",\"Values\":[\"true\"]} ]" --query 'Subnets[*].{SubnetId:SubnetId}' --output text)
export SUBNET1=$(echo $PUBLIC_SUBNETS | cut -d ' ' -f 1)
export SUBNET2=$(echo $PUBLIC_SUBNETS | cut -d ' ' -f 2)

cat > ray-dashboard.yaml << EOL
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ray-cluster-ingress
  annotations:
    # WARNING: Do not expose this ALB publicly without additional authentication/authorization.
    # The Ray Dashboard provides read and write access to the cluster. Anyone with access to the
    # ALB can launch arbitrary code execution on the Ray Cluster.
    alb.ingress.kubernetes.io/scheme: internet-facing
      #alb.ingress.kubernetes.io/tags: Environment=dev,Team=test
    # See ingress.md for more details about how to choose subnets.
    alb.ingress.kubernetes.io/subnets: ${SUBNET1}, ${SUBNET2}
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${HEAD_SERVICE} # Your head pod service
                port:
                  number: 8265
EOL
```

Generate an Ingress manifest and apply it to the cluster

``` bash
envsubst < ray-dashboard.yaml | kubectl apply  -f -

kubectl get ingress
```

It takes about 6 minutes for the load balancer to be created and become active. Then you can paste the address you find on the ingress into your local browser to access the Ray dashboard.

```
NAME                  CLASS   HOSTS   ADDRESS                                                                  PORTS   AGE
ray-cluster-ingress   alb     *       k8s-default-rayclust-14ceb20792-1681229536.us-west-2.elb.amazonaws.com   80      5m52s
```
<div className="text--center"> 
![Ray Dashboard](/img/ray/dashboard.png)
</div>

Please visit the `Serve` Tab to see your application:
<div className="text--center"> 
![Ray Dashboard](/img/ray/serve-dashboard.png)
</div>

To hide the Ray dashboard from the Internet, remove the Ingress object

```bash
kubectl delete ingress ray-cluster-ingress
```



## 3. Inference

To check for the Kubernetes service:
```bash
kubectl get services
```

when you see the service `stable-diffusion-cpu-serve-svc`, we can now forward the port for Stable Diffusion query:

```bash
kubectl port-forward svc/stable-diffusion-cpu-serve-svc 8000 > /dev/null 2>&1 &
```


Now the query is ready.

Now let's send a query request.
::alert[If you'd like to change the prompt request, please enter `vi stable_diffusion_cpu/stable_diffusion_cpu_req.py` and change the variable `prompt` to your request.]{header="Note:"}

To send query request, please run
```bash
python3 stable_diffusion_cpu_req.py
```

On CPU it takes about 5 min to generate an image. On GPU a new image is created within 10 sec.

Now we have a few options to view the image:

### OPTION #1: 
A fun way to view the image output, we can use the [VIU tool](https://github.com/atanunq/viu). 
To download the tool, please run:

``` bash
# Download Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Download VIU
cargo install viu
```

To quickly view a low-resolution version of the image, please run
``` bash
viu output.png
```
<div className="text--center"> 
![Image Viu](/img/ray/viu-image.png)
</div>

### OPTION #2: 
If you are using SageMaker Code Editor, we can  view the image directly in code editor. 

Please use the Code editor explorer to navigate to `output.png` and open the image.
<div className="text--center"> 
![Open File](/img/ray/open-file.png)
</div>

The following prompt was used to generate this image: `"cat wearing a fancy hat on a purple mat"`.

If you'd like to download the image to your desktop, you can right-click the file `output.png` in the Code Editor File Explorer and select "Download...".  

That was our inference example using Ray Service! Please feel free to try other prompts or other inference examples that are available within the rayservice directory.
