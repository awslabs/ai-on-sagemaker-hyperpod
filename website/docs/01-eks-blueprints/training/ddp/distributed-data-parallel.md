---
title: Distributed Data Parallel (DDP)
sidebar_position: 2
---

# Get Started Training a Model using PyTorch DDP in 5 Minutes (CPU)

This guide provides step-by-step instructions for setting up Distributed Data Parallel (DDP) training on EKS using PyTorch.

## Prerequisites

Before starting, ensure you have completed the following setup:

### Infrastructure Requirements

- ✅ **SageMaker HyperPod EKS cluster** deployed and running
- ✅ **EKS node groups** with appropriate instance types (e.g., ml.m5.2xlarge)
- ✅ **FSx for Lustre filesystem** provisioned and mounted to the cluster
- ✅ **Kubeflow Training Operator** installed on the cluster

### Development Environment

- ✅ **AWS CLI v2** installed and configured with appropriate permissions
- ✅ **kubectl** installed and configured to access your EKS cluster
- ✅ **Docker** installed on your development machine
- ✅ **envsubst** utility for template processing
- ✅ **Git** for cloning repositories

### AWS Permissions

Your AWS credentials should have permissions for:
- ✅ **Amazon ECR** - push/pull container images
- ✅ **Amazon EKS** - access cluster resources
- ✅ **Amazon FSx** - access shared filesystem
- ✅ **Amazon EC2** - describe instances and availability zones
- ✅ **AWS STS** - get caller identity

### Cluster Validation

Verify your cluster is ready:

```bash
# Check cluster status
kubectl get nodes

# Verify Kubeflow Training Operator is running
kubectl get pods -n kubeflow

# Check FSx storage is available
kubectl get pvc

# Verify you can create resources
kubectl auth can-i create pytorchjobs
```

## Step 1: Setup Your Training Job Image

### 1.1 Clone the Repository

The first step is to get the training code and Docker configuration. We'll clone the AWS distributed training examples repository which contains pre-built PyTorch DDP examples optimized for Kubernetes.

```bash
cd ~
git clone https://github.com/aws-samples/awsome-distributed-training/
cd awsome-distributed-training/3.test_cases/pytorch/cpu-ddp/kubernetes
```

### 1.2 Build a Docker Image

Now we'll build a container image that includes PyTorch, the training code, and all necessary dependencies. The `$DOCKER_NETWORK` variable handles SageMaker Studio's specific network requirements if you're running from that environment.

```bash
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/
docker build $DOCKER_NETWORK -t ${REGISTRY}fsdp:pytorch2.2-cpu ..
```

<details>
    <summary>Why $DOCKER_NETWORK?</summary>
    
    The environment variable <code>$DOCKER_NETWORK</code> is set to <code>--network=sagemaker</code> only if you deployed the SageMaker Studio Code Editor CloudFormation stack in the <a href="/docs/category/getting-started">Set Up Your Development Environment</a> section. This is necessary because SageMaker Studio uses a specific network configuration for its containers. Otherwise, it remains unset. 
    
</details>

Building the image can take 3~5 minutes. If successful, you should see the following success message at the end:

```
Successfully built 123ab12345cd
Successfully tagged 123456789012.dkr.ecr.us-east-2.amazonaws.com/fsdp:pytorch2.2-cpu
```

### 1.3 Push the Image to Amazon ECR

In this step we create a container registry if one does not exist, and push the container image to it. This makes the image available to your EKS cluster nodes.

```bash
# Create registry if needed
REGISTRY_COUNT=$(aws ecr describe-repositories | grep \"fsdp\" | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
        aws ecr create-repository --repository-name fsdp
fi

# Login to registry
echo "Logging in to $REGISTRY ..."
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

# Push image to registry
docker image push ${REGISTRY}fsdp:pytorch2.2-cpu
```

Pushing the image may take some time depending on your network bandwidth. If you use EC2 / CloudShell as your development machine, it will take 6~8 minutes.

## Step 2: Preparing Your Training Job Script

### 2.1 Install envsubst

This example uses [`envsubst`](https://github.com/a8m/envsubst) to generate a Kubernetes manifest file from a template file and parameters. If you don't have `envsubst` on your development environment, install it by following the [Installation instruction](https://github.com/a8m/envsubst?tab=readme-ov-file#installation).

### 2.2 Generate Manifest from Template

With the `envsubst` command, generate `fsdp.yaml` from `fsdp.yaml-template`. Please configure instance type, number of nodes, number of CPUs, based on your cluster's specification.

You can check your cluster's specification by running the following command:

```bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,CPU:.status.capacity.cpu"
```

```
NAME                           INSTANCETYPE    CPU
hyperpod-i-0427a1830f8e4a49e   ml.m5.2xlarge   4
hyperpod-i-052768f9f54856cd6   ml.m5.2xlarge   4
```

Set environment variables and run `envsubst` to generate `fsdp.yaml`.

For ml.m5.2xlarge x 2:

```bash
export IMAGE_URI=${REGISTRY}fsdp:pytorch2.2-cpu
export INSTANCE_TYPE=ml.m5.2xlarge
export NUM_NODES=2
export CPU_PER_NODE=4
cat fsdp.yaml-template | envsubst > fsdp.yaml
```

The template file assumes that the FSx Lustre volume is claimed as `fsx-pvc`. You can check the claim name of the FSx Lustre filesystem in your cluster by executing the following command.

```bash
kubectl get pvc
```

```
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
fsx-claim   Bound    pvc-ed0fd2cb-33da-498d-bab4-bf08cb4d555c   1200Gi     RWX            fsx-sc         <unset>                 6d22h
```

If your FSx Lustre volume is claimed in different name than `fsx-pvc` (e.g., `fsx-claim`), you can execute the following command to update the claim name in `fsdp.yaml`:

```bash
sed 's/fsx-pv/fsx-claim/g' -i ./fsdp.yaml
```

If you wish the training job to run for longer so you may test resiliency against a running job, increase the number of epochs by increasing the number of epochs specified by the torchrun command in `fsdp.yaml`:

```bash
sed 's/5000/50000/g' -i ./fsdp.yaml
```

In this example the number of epochs (line 107) was increased from `5000` to `50000`.

## Step 3: Deploy Training Workload

### 3.1 Deploy the Training Job

Now the manifest file `fsdp.yaml` is generated, and you are ready to deploy the training workload. Run the following command to deploy the training workload.

```bash
kubectl apply -f ./fsdp.yaml
```

You should see the following message:

```
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/fsdp created
```

### 3.2 Monitor

To see the status of your job, use the commands below:

```bash
kubectl get pytorchjob
kubectl get pods
```

```
NAME   STATE     AGE
fsdp   Running   40s

NAME                    READY   STATUS    RESTARTS   AGE
etcd-7787559c74-msgpq   1/1     Running   0          49s
fsdp-worker-0           1/1     Running   0          49s
fsdp-worker-1           1/1     Running   0          49s
```

> Note: When you run for the first time, it takes 2~3min until the Pod statuses change from `ContainerCreating` to `Running`.

Each of the pods produces job logs. You can monitor the logs by running the command below.

```bash
kubectl logs -f fsdp-worker-0
```

```
2024-07-19 04:39:07,890] torch.distributed.run: [WARNING] *****************************************
INFO 2024-07-19 04:39:07,958 Etcd machines: ['http://0.0.0.0:2379']
INFO 2024-07-19 04:39:07,964 Attempting to join next rendezvous
INFO 2024-07-19 04:39:07,965 Observed existing rendezvous state: {'status': 'joinable', 'version': '1', 'participants': [0]}
INFO 2024-07-19 04:39:08,062 Joined rendezvous version 1 as rank 1. Full state: {'status': 'frozen', 'version': '1', 'participants': [0, 1], 'keep_alives': []}
INFO 2024-07-19 04:39:08,062 Waiting for remaining peers.
INFO 2024-07-19 04:39:08,063 All peers arrived. Confirming membership.
INFO 2024-07-19 04:39:08,149 Waiting for confirmations from all peers.
INFO 2024-07-19 04:39:08,161 Rendezvous version 1 is complete. Final state: {'status': 'final', 'version': '1', 'participants': [0, 1], 'keep_alives': ['/torchelastic/p2p/run_none/rdzv/v_1/rank_1', '/torchelastic/p2p/run_none/rdzv/v_1/rank_0'], 'num_workers_waiting': 0}
INFO 2024-07-19 04:39:08,161 Creating EtcdStore as the c10d::Store implementation
...
[RANK 1] Epoch 4991 | Batchsize: 32 | Steps: 8
Epoch 4990 | Training snapshot saved at /fsx/snapshot.pt
[RANK 0] Epoch 4991 | Batchsize: 32 | Steps: 8
[RANK 1] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 0] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 3] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 2] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 1] Epoch 4993 | Batchsize: 32 | Steps: 8
[RANK 2] Epoch 4993 | Batchsize: 32 | Steps: 8
```

### 3.3 Stop

To stop the current training job, use the following command.

```bash
kubectl delete -f ./fsdp.yaml
```

## Alternative: Start Your Training Job Execution (Simple Method)

If you prefer a simpler approach without building your own container image, you can use the pre-built example that doesn't require custom image building.

### 4.1 Clone the Repository

Navigate to your home directory or your preferred project directory, clone the repo.

```bash
cd ~
git clone https://github.com/aws-samples/awsome-distributed-training/
cd awsome-distributed-training/3.test_cases/pytorch/cpu-ddp/kubernetes
```

If you wish to test the resiliency feature, please run the following command to increase the number of training epochs so the job runs longer:

```bash
sed 's/5000/50000/g' -i ./fsdp-simple.yaml
```

### 4.2 Deploy Training Workload

Run the following command to deploy the training workload.

```bash
kubectl apply -f ./fsdp-simple.yaml
```

You should see the following message:

```
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/fsdp created
```

### 4.3 Monitor

To see the status of your job, use the commands below:

```bash
kubectl get pytorchjob
kubectl get pods
```

```
NAME   STATE     AGE
fsdp   Running   40s

NAME                    READY   STATUS    RESTARTS   AGE
etcd-7787559c74-msgpq   1/1     Running   0          49s
fsdp-worker-0           1/1     Running   0          49s
fsdp-worker-1           1/1     Running   0          49s
```

> Note: When you run for the first time, it takes 2~3min until the Pod statuses change from `ContainerCreating` to `Running`.

Each of the pods produces job logs. You can monitor the logs by running the command below.

```bash
kubectl logs -f fsdp-worker-0
```

```
2024-07-19 04:39:07,890] torch.distributed.run: [WARNING] *****************************************
INFO 2024-07-19 04:39:07,958 Etcd machines: ['http://0.0.0.0:2379']
INFO 2024-07-19 04:39:07,964 Attempting to join next rendezvous
INFO 2024-07-19 04:39:07,965 Observed existing rendezvous state: {'status': 'joinable', 'version': '1', 'participants': [0]}
INFO 2024-07-19 04:39:08,062 Joined rendezvous version 1 as rank 1. Full state: {'status': 'frozen', 'version': '1', 'participants': [0, 1], 'keep_alives': []}
INFO 2024-07-19 04:39:08,062 Waiting for remaining peers.
INFO 2024-07-19 04:39:08,063 All peers arrived. Confirming membership.
INFO 2024-07-19 04:39:08,149 Waiting for confirmations from all peers.
INFO 2024-07-19 04:39:08,161 Rendezvous version 1 is complete. Final state: {'status': 'final', 'version': '1', 'participants': [0, 1], 'keep_alives': ['/torchelastic/p2p/run_none/rdzv/v_1/rank_1', '/torchelastic/p2p/run_none/rdzv/v_1/rank_0'], 'num_workers_waiting': 0}
INFO 2024-07-19 04:39:08,161 Creating EtcdStore as the c10d::Store implementation
...
[RANK 1] Epoch 4991 | Batchsize: 32 | Steps: 8
Epoch 4990 | Training snapshot saved at /fsx/snapshot.pt
[RANK 0] Epoch 4991 | Batchsize: 32 | Steps: 8
[RANK 1] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 0] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 3] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 2] Epoch 4992 | Batchsize: 32 | Steps: 8
[RANK 1] Epoch 4993 | Batchsize: 32 | Steps: 8
[RANK 2] Epoch 4993 | Batchsize: 32 | Steps: 8
```

### 4.4 Stop

To stop the current training job, use the following command.

```bash
kubectl delete -f ./fsdp-simple.yaml
```