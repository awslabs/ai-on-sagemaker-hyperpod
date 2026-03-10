---
title: Fully Sharded Data Parallelism (FSDP2)
sidebar_position: 1
---
# Get Started Training Llama 2 with PyTorch FSDP2 in 5 Minutes

This example showcases an easy way to get started with multi node [FSDP2](https://pytorch.org/tutorials/intermediate/FSDP_tutorial.html) training on Amazon EKS on SageMaker HyperPod. FSDP2 is the next generation of PyTorch's Fully Sharded Data Parallel, offering improved memory management, DTensor integration, and a cleaner API.

## What's New in FSDP2

FSDP2 introduces several improvements over FSDP1:
- **DTensor representation**: Parameters are represented as DTensor with Shard(0) placement for easier manipulation
- **Better memory management**: Lower and deterministic GPU memory without `recordStream` and no CPU synchronization
- **Simplified API**: `fully_shard` function instead of `FullyShardedDataParallel` class wrapper
- **Improved checkpointing**: Communication-free sharded state dicts using DTensor APIs
- **Meta device initialization**: Cleaner initialization flow with explicit device placement
- **Elastic training support**: Built-in support for dynamic node scaling 

## Prerequisites

Before starting, ensure you have completed the following setup:

### Infrastructure Requirements

- ✅ **SageMaker HyperPod EKS cluster** deployed and running
- ✅ **GPU node groups** with appropriate instance types (e.g., ml.g5.8xlarge, ml.p5en.48xlarge)
- ✅ **GPU device plugin** installed on the cluster
- ✅ **EFA device plugin** installed for high-performance networking
- ✅ **Kubeflow Training Operator** installed on the cluster

### Development Environment

- ✅ **AWS CLI v2** installed and configured with appropriate permissions
- ✅ **kubectl** installed and configured to access your EKS cluster
- ✅ **Docker** installed on your development machine (x86-64 based)
- ✅ **envsubst** utility for template processing
- ✅ **Git** for cloning repositories
- ✅ **HuggingFace account and token** for dataset access

### AWS Permissions

Your AWS credentials should have permissions for:
- ✅ **Amazon ECR** - push/pull container images
- ✅ **Amazon EKS** - access cluster resources
- ✅ **Amazon EC2** - describe instances and availability zones
- ✅ **AWS STS** - get caller identity

### Cluster Validation

Verify your cluster is ready:

```bash
# Check cluster status and GPU availability
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa"

# Verify Kubeflow Training Operator is running
kubectl get pods -n kubeflow

# Check GPU device plugin
kubectl get daemonset -n kube-system | grep nvidia

# Verify EFA device plugin
kubectl get daemonset -n kube-system | grep aws-efa

# Verify you can create resources
kubectl auth can-i create pytorchjobs
```

### Verified Instance Types and Counts

This example has been verified with:
- **ml.p5en.48xlarge x 2** - High-performance training setup

Please note you can change the model size to accommodate for other instance types.

### Model Size Configurations

The following table shows the parameters for different Llama model sizes based on the [Llama 2](https://arxiv.org/abs/2307.09288) and [Llama 3](https://arxiv.org/abs/2407.21783) papers:

| Parameter | Llama 2 7B | Llama 2 13B | Llama 2 70B | Llama 3.1 8B | Llama 3.1 70B | Llama 3.2 1B | Llama 3.2 3B |
|-----------|------------|-------------|-------------|--------------|---------------|--------------|--------------|
| **intermediate_size** | 11008 | 13824 | 28672 | 14336 | 28672 | 8192 | 11008 |
| **num_key_value_heads** | 32 | 40 | 8 | 8 | 8 | 8 | 8 |
| **hidden_width** | 4096 | 5120 | 8192 | 4096 | 8192 | 2048 | 3072 |
| **num_layers** | 32 | 40 | 80 | 32 | 80 | 16 | 28 |
| **num_heads** | 32 | 40 | 64 | 32 | 64 | 32 | 24 |
| **max_context_length** | 4096 | 4096 | 4096 | 8192 | 8192 | 8192 | 8192 |

These configurations can be used to adjust the model parameters in your training scripts based on your compute requirements and available instance types.

## Step 1: Setup the Docker Image

### 1.1 Clone the Repository

The first step is to get the FSDP training code and Docker configuration. We'll clone the AWS distributed training examples repository which contains pre-built PyTorch FSDP examples optimized for Kubernetes.

```bash
cd ~
git clone https://github.com/aws-samples/awsome-distributed-training/
cd awsome-distributed-training/3.test_cases/pytorch/FSDP
```

### 1.2 Build a Docker Image

Now we'll build a container image that includes PyTorch 2.6.0+ (required for FSDP2), training code, and all necessary dependencies. First, we need to authenticate with the public ECR registry to access base images.

```bash
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/hpc-cloud
export REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/
```

Build the container image:

### For EKS (Base target)

If you are on a Mac, use `buildx` to target `linux/amd64` architecture: 

    ```bash 
    docker buildx build --platform linux/amd64 --target base -t ${REGISTRY}fsdp:pytorch2.6.0 .
    ```
   
    **Alternatively,** if you are running in a SageMaker Studio environment

    ```bash 
    docker build $DOCKER_NETWORK --target base -t ${REGISTRY}fsdp:pytorch2.6.0 .    
    ```

### For HyperPod (HPTO target with elastic agent)

If you are on a Mac, use `buildx` to target `linux/amd64` architecture: 

    ```bash 
    docker buildx build --platform linux/amd64 --target hpto -t ${REGISTRY}fsdp:pytorch2.6.0 .
    ```
   
    **Alternatively,** if you are running in a SageMaker Studio environment

    ```bash 
    docker build $DOCKER_NETWORK --target hpto -t ${REGISTRY}fsdp:pytorch2.6.0 .    
    ```

<details>
    <summary>Why $DOCKER_NETWORK?</summary>
    
    The environment variable <code>$DOCKER_NETWORK</code> is set to <code>--network=sagemaker</code> only if you deployed the SageMaker Studio Code Editor CloudFormation stack in the <a href="/docs/category/getting-started">Set Up Your Development Environment</a> section. This is necessary because SageMaker Studio uses a specific network configuration for its containers. Otherwise, it remains unset. 
    
</details>

Building the image can take 5~7 minutes. If successful, you should see the following success message at the end:

```
Successfully built 123ab12345cd
Successfully tagged 123456789012.dkr.ecr.us-west-2.amazonaws.com/fsdp:pytorch2.6.0
```

### 1.3 Push the Image to Amazon ECR

In this step we create a container registry if one does not exist, and push the container image to it. This makes the image available to your EKS cluster nodes.

```bash
# Create registry if needed
REGISTRY_COUNT=$(aws ecr describe-repositories | grep "fsdp" | wc -l)
if [ "$REGISTRY_COUNT" -eq 0 ]; then
    aws ecr create-repository --repository-name fsdp
fi

# Login to registry
echo "Logging in to $REGISTRY ..."
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

# Push image to registry
docker image push ${REGISTRY}fsdp:pytorch2.6.0
```

Pushing the image may take some time depending on your network bandwidth. If you use EC2 / CloudShell as your development machine, it will take 6~8 minutes.

## Step 2: Data and HuggingFace Setup

### 2.1 Understanding the Dataset

For this example, we'll be using the [allenai/c4](https://huggingface.co/datasets/allenai/c4) dataset. Instead of downloading the whole thing, the `create_streaming_dataloaders` function will stream the dataset from [HuggingFace](https://huggingface.co/datasets), so there's no data prep required for running this training.

If you'd like to instead use your own dataset, you can do so by [formatting it as a HuggingFace dataset](https://huggingface.co/docs/datasets/create_dataset), and passing its location to the `--dataset_path` argument.

### 2.2 Create HuggingFace Token

**For this dataset, we will need a Hugging Face access token**. First, create a [Hugging Face account](https://huggingface.co/welcome). Then [generate your access token with read permissions](https://huggingface.co/docs/hub/en/security-tokens).

We will reference this token in the next step by setting it as an environment variable.

## Step 3: Start Your Training Run

### 3.1 Install envsubst

This example uses [`envsubst`](https://github.com/a8m/envsubst) to generate a Kubernetes manifest file from a template file and parameters. If you don't have `envsubst` on your development environment, install it by following the [Installation instruction](https://github.com/a8m/envsubst?tab=readme-ov-file#installation).

### 3.2 Generate Manifest from Template

With the `envsubst` command, generate `fsdp.yaml` from `fsdp.yaml-template`. Please configure instance type, number of nodes, number of GPUs, number of EFAs, based on your cluster's specification.

You can check your cluster's specification by running the following command:

```bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa"
```

```
NAME                           INSTANCETYPE    GPU   EFA
hyperpod-i-055aeff9546187dee   ml.g5.8xlarge   1     1
hyperpod-i-09662f64f615c96f5   ml.g5.8xlarge   1     1
hyperpod-i-099e2a84aba621d52   ml.g5.8xlarge   1     1
hyperpod-i-0a6fea3329235be91   ml.g5.8xlarge   1     1
hyperpod-i-0ac3feb733dc0f00e   ml.g5.8xlarge   1     1
hyperpod-i-0bf7dce836e063fa6   ml.g5.8xlarge   1     1
hyperpod-i-0ddf28f3ff2870f1b   ml.g5.8xlarge   1     1
hyperpod-i-0fe48912b03d2c22e   ml.g5.8xlarge   1     1
```

Change directories to the `kubernetes` directory:

```bash
cd kubernetes/
```

Set environment variables and run `envsubst` to generate `fsdp.yaml`.

For ml.g5.8xlarge x 2 with elastic training (1-2 nodes):

```bash
export IMAGE_URI=${REGISTRY}fsdp:pytorch2.6.0
export INSTANCE_TYPE=ml.g5.8xlarge
export MIN_NODES=1  # Minimum nodes for elastic training
export MAX_NODES=2  # Number of nodes
export GPU_PER_NODE=1
export EFA_PER_NODE=1
export FI_PROVIDER=efa
export HF_TOKEN=<Your HuggingFace Token>
```

For ml.p5.48xlarge x 4 with elastic training (1-4 nodes):

```bash
export IMAGE_URI=${REGISTRY}fsdp:pytorch2.6.0
export INSTANCE_TYPE=ml.p5.48xlarge
export MIN_NODES=1  # Minimum nodes for elastic training
export MAX_NODES=4  # Number of nodes
export GPU_PER_NODE=8
export EFA_PER_NODE=32
export FI_PROVIDER=efa
export HF_TOKEN=<Your HuggingFace Token>
```

```bash
cat fsdp.yaml-template | envsubst > fsdp.yaml
```

### 3.3 Deploy the Training Job

Now the manifest file `fsdp.yaml` is generated, and you are ready to deploy the training workload. Run the following command to deploy the training workload.

```bash
kubectl apply -f ./fsdp.yaml
```

You should see the following message:

```
pytorchjob.kubeflow.org/fsdp created
```

### 3.4 Monitor Your Training Job

To see the status of your job, use the commands below:

```bash
kubectl get pytorchjob
kubectl get pods
```

```
NAME   STATE     AGE
fsdp   Running   5m

NAME                    READY   STATUS              RESTARTS   AGE
etcd-7787559c74-pw4jp   1/1     Running             0          74s
fsdp-worker-0           0/1     ContainerCreating   0          74s
fsdp-worker-1           0/1     ContainerCreating   0          74s
fsdp-worker-2           0/1     ContainerCreating   0          74s
fsdp-worker-3           0/1     ContainerCreating   0          74s
fsdp-worker-4           0/1     ContainerCreating   0          74s
fsdp-worker-5           0/1     ContainerCreating   0          74s
fsdp-worker-6           0/1     ContainerCreating   0          74s
fsdp-worker-7           0/1     ContainerCreating   0          74s
```

When you run for the first time, it takes 3~4 minutes until the Pod statuses change from `ContainerCreating` to `Running`.

```
NAME                    READY   STATUS    RESTARTS   AGE
etcd-7787559c74-pw4jp   1/1     Running   0          3m43s
fsdp-worker-0           1/1     Running   0          3m43s
fsdp-worker-1           1/1     Running   0          3m43s
fsdp-worker-2           1/1     Running   0          3m43s
fsdp-worker-3           1/1     Running   0          3m43s
fsdp-worker-4           1/1     Running   0          3m43s
fsdp-worker-5           1/1     Running   0          3m43s
fsdp-worker-6           1/1     Running   0          3m43s
fsdp-worker-7           1/1     Running   0          3m43s
```

Each of the pods produces job logs. One of the pods is elected master during job initialization. Only this pod will show the progress of the training job in its log. To find out which pod is currently the master, run the command below:

```bash
kubectl logs fsdp-worker-0 | grep master_addr=
```

```
[2024-06-25 22:20:17,556] torch.distributed.elastic.agent.server.api: [INFO]   master_addr=fsdp-worker-1
```

This shows that the pod fsdp-worker-1 is currently the master. To look at the current job logs, use the command below:

```bash
kubectl logs -f fsdp-worker-1
```

```
    :
2024-06-25 22:22:36 I [train.py:102] Batch 0 Loss: 11.63946, Speed: 0.27 samples/sec, lr: 0.000006
2024-06-25 22:22:57 I [train.py:102] Batch 1 Loss: 11.66096, Speed: 0.39 samples/sec, lr: 0.000013
2024-06-25 22:23:17 I [train.py:102] Batch 2 Loss: 11.56659, Speed: 0.40 samples/sec, lr: 0.000019
2024-06-25 22:23:37 I [train.py:102] Batch 3 Loss: 11.14039, Speed: 0.40 samples/sec, lr: 0.000025
    :
```

You can execute `nvtop` command inside a running container within a Pod to see GPU utilization:

```bash
kubectl exec -it fsdp-worker-4 -- nvtop
```

### 3.5 Stop the Training

To stop the current training job, use the following command:

```bash
kubectl delete -f ./fsdp.yaml
```

## Understanding FSDP2 Implementation

### Key Differences from FSDP1

The FSDP2 implementation uses several new patterns that simplify distributed training:

**1. Meta Device Initialization**
```python
# Initialize model on meta device (no memory allocation)
with torch.device("meta"):
    model = AutoModelForCausalLM.from_config(model_config)
```

**2. Layer-by-Layer Sharding**
```python
# Apply fully_shard to transformer layers first
for module in model.modules():
    if isinstance(module, transformer_layer):
        fully_shard(module, **fsdp_kwargs)

# Then apply to root model
fully_shard(model, **fsdp_kwargs)
```

**3. Explicit Device Placement**
```python
# Move from meta to CUDA after sharding
model.to_empty(device=torch.device("cuda"))
```

**4. DTensor Parameters**
All model parameters are now DTensor with Shard(0) placement, enabling:
- Seamless optimizer integration
- Communication-free sharded checkpoints
- Easier parameter manipulation

**5. Elastic Training Support**
The template now supports elastic training with dynamic node scaling:
- Uses `--nnodes=$MIN_NODES:$MAX_NODES` format
- Jobs can start with minimum nodes and scale up
- Automatic handling of node failures and recovery

### Checkpoint Storage

FSDP2 uses FSx for Lustre for distributed checkpoint storage:
- Checkpoints are stored in `/checkpoints` directory
- Mounted via PersistentVolumeClaim (`fsx-claim`)
- Enables communication-free checkpoint save/load with DTensor APIs

### Performance Considerations

**Implicit Prefetching (Default)**
- Works out of the box
- CPU thread issues all-gather before each layer
- Good for non-CPU-bound workloads

**Explicit Prefetching (Advanced)**
For better performance, you can manually control prefetching in your training code.

## Alternative: Start Training with the HyperPod CLI

> **Note:**
> This page shows how to run the sample application with HyperPod CLI, instead of `kubectl`. If you didn't install the HyperPod CLI, see the [Install HyperPod CLI](/docs/eks-orchestration/add-ons/installing-the-hyperpod-cli) page.


### Set environment variables

Check your cluster's specification by running following command:

``` bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa"
```

```
NAME                           INSTANCETYPE    GPU   EFA
hyperpod-i-055aeff9546187dee   ml.g5.8xlarge   1     1
hyperpod-i-09662f64f615c96f5   ml.g5.8xlarge   1     1
hyperpod-i-099e2a84aba621d52   ml.g5.8xlarge   1     1
hyperpod-i-0a6fea3329235be91   ml.g5.8xlarge   1     1
hyperpod-i-0ac3feb733dc0f00e   ml.g5.8xlarge   1     1
hyperpod-i-0bf7dce836e063fa6   ml.g5.8xlarge   1     1
hyperpod-i-0ddf28f3ff2870f1b   ml.g5.8xlarge   1     1
hyperpod-i-0fe48912b03d2c22e   ml.g5.8xlarge   1     1
```

Set following environment variables based on your cluster configuration.

``` bash
export IMAGE_URI=${REGISTRY}fsdp:pytorch2.6.0
export INSTANCE_TYPE=ml.g5.8xlarge
export MIN_NODES=1  # Minimum nodes for elastic training
export MAX_NODES=2  # Number of nodes
export GPU_PER_NODE=1
export HF_TOKEN=<Your HuggingFace Token>
```

### Generate a job configuration file

Run following command to generate a job configuration file (`hpcli-fsdp.yaml`) for HyperPod CLI.

``` yaml
cat > hpcli-fsdp.yaml << EOL
defaults:
 - override hydra/job_logging: stdout

hydra:
 run:
  dir: .
 output_subdir: null

training_cfg:
 entry_script: /fsdp/train.py
 script_args:
    - --max_context_width: 4096
    - --num_key_value_heads: 32
    - --intermediate_size: 11008
    - --hidden_width: 4096
    - --num_layers: 32
    - --num_heads: 32
    - --model_type: llama_v2
    - --tokenizer: hf-internal-testing/llama-tokenizer
    - --checkpoint_freq: 5000
    - --validation_freq: 500
    - --max_steps: 5000
    - --checkpoint_dir: /checkpoints
    - --dataset: allenai/c4
    - --dataset_config_name: en
    - --resume_from_checkpoint: /checkpoints
    - --train_batch_size: 1
    - --val_batch_size: 1
    - --sharding_strategy: full
    - --offload_activation: 1

 run:
  name: fsdp
  nodes: ${MAX_NODES}
  ntasks_per_node: ${GPU_PER_NODE}
cluster:
 cluster_type: k8s
 instance_type: ${INSTANCE_TYPE}
 cluster_config:
  service_account_name: null

  volumes:
    - volumeName: local
      hostPath: "/mnt/k8s-disks/0"
      mountPath: "/local"

  namespace: kubeflow
  label_selector:
      required:
          sagemaker.amazonaws.com/node-health-status:
              - Schedulable
      preferred:
          sagemaker.amazonaws.com/deep-health-check-status:
              - Passed
      weights:
          - 100
  pullPolicy: Always
  restartPolicy: OnFailure

  annotations:
    sagemaker.amazonaws.com/enable-job-auto-resume: True
    sagemaker.amazonaws.com/job-max-retry-count: 10

base_results_dir: ./result
container: ${IMAGE_URI}

env_vars:
 LOGLEVEL: DEBUG
 TORCH_DISTRIBUTED_DEBUG: DETAIL
 TORCH_NCCL_ENABLE_MONITORING: 1
 TORCH_NCCL_TRACE_BUFFER_SIZE: 20000
 TORCH_NCCL_DUMP_ON_TIMEOUT: 1
 TORCH_NCCL_DEBUG_INFO_TEMP_FILE: /local/nccl_trace_rank_
 PYTORCH_CUDA_ALLOC_CONF: "expandable_segments:True"
 NCCL_DEBUG: INFO
 NCCL_SOCKET_IFNAME: ^lo
 TORCH_NCCL_ASYNC_ERROR_HANDLING: 1
 HF_TOKEN: ${HF_TOKEN}
EOL
```

### Start training job

Now the job configuration file `hpcli-fsdp.yaml` is generated, and you are ready to start the training job.


Before startuing the job, you need to select the cluster with `hyperpod connect-cluster` command.

``` bash
hyperpod connect-cluster --cluster-name ml-cluster
```

Then run `hyperpod start-job` command to start the job.

``` bash
hyperpod start-job --config-file ./hpcli-fsdp.yaml
```

```
{
 "Console URL": "https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/cluster-management/ml-cluster"
}
```

### Monitor

To see the status of your job, use the commands below:

``` bash
hyperpod get-job --job-name fsdp -n kubeflow
```

``` json
{
 "Name": "fsdp",
 "Namespace": "kubeflow",
 "Label": {
  "app": "fsdp",
  "app.kubernetes.io/managed-by": "Helm"
 },
 "CreationTimestamp": "2024-09-26T01:06:51Z",
 "Status": {
  "conditions": [
   {
    "lastTransitionTime": "2024-09-26T01:06:51Z",
    "lastUpdateTime": "2024-09-26T01:06:51Z",
    "message": "PyTorchJob fsdp is created.",
    "reason": "PyTorchJobCreated",
    "status": "True",
    "type": "Created"
   },
   {
    "lastTransitionTime": "2024-09-26T01:07:02Z",
    "lastUpdateTime": "2024-09-26T01:07:02Z",
    "message": "PyTorchJob kubeflow/fsdp is running.",
    "reason": "PyTorchJobRunning",
    "status": "True",
    "type": "Running"
   }
  ],
  "replicaStatuses": {
   "Worker": {
    "active": 8,
    "selector": "training.kubeflow.org/job-name=fsdp,training.kubeflow.org/operator-name=pytorchjob-controller,training.kubeflow.org/replica-type=worker"
   }
  },
  "startTime": "2024-09-26T01:07:00Z"
 },
 "ConsoleURL": "https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/cluster-management/k8-g5-8x-4"
}
```

If you need more detailed information of the job, you can use `--verbose` option.

``` bash
hyperpod get-job --job-name fsdp -n kubeflow --verbose
```

``` json
{
 "Name": "fsdp",
 "Namespace": "kubeflow",
 "Label": {
  "app": "fsdp",
  "app.kubernetes.io/managed-by": "Helm"
 },
 "Annotations": {
  "meta.helm.sh/release-name": "fsdp",
  "meta.helm.sh/release-namespace": "kubeflow",
  "sagemaker.amazonaws.com/enable-job-auto-resume": "true",
  "sagemaker.amazonaws.com/job-max-retry-count": "10"
 },
 "Metadata": {
  "CreationTimestamp": "2024-09-26T01:06:51Z",
  "Generation": 1,
  "ResourceVersion": "4240104",
  "UID": "39364a40-70c7-4d03-abab-160c124e7367"
 },
 "Kind": "PyTorchJob",
 "ApiVersion": "kubeflow.org/v1",
 "Spec": {
  "pytorchReplicaSpecs": {
   "Worker": {
    "replicas": 8,
    "template": {
     "spec": {
      "affinity": {
       "nodeAffinity": {
        "preferredDuringSchedulingIgnoredDuringExecution": [
         {
          "preference": {
           "matchExpressions": [
            {
             "key": "sagemaker.amazonaws.com/deep-health-check-status",
             "operator": "In",
             "values": [
              "Passed"
             ]
            }
           ]
          },
          "weight": 100
         }
        ],
        "requiredDuringSchedulingIgnoredDuringExecution": {
         "nodeSelectorTerms": [
          {
           "matchExpressions": [
            {
             "key": "sagemaker.amazonaws.com/node-health-status",
             "operator": "In",
             "values": [
              "Schedulable"
             ]
            }
           ]
          }
         ]
        }
       }
      },
      "containers": [
       {
        "command": [
         "/etc/config/train-script.sh"
        ],
        "env": [
         {
          "name": "CUDA_DEVICE_MAX_CONNECTIONS",
          "value": "1"
         },
         {
          "name": "CUDA_VISIBLE_DEVICES",
          "value": "0"
         },
         {
          "name": "FI_EFA_FORK_SAFE",
          "value": "1"
         },
         {
          "name": "FI_PROVIDER",
          "value": "efa"
         },
         {
          "name": "LOGLEVEL",
          "value": "DEBUG"
         },
         {
          "name": "NCCL_DEBUG",
          "value": "INFO"
         },
         {
          "name": "NCCL_IGNORE_DISABLED_P2P",
          "value": "1"
         },
         {
          "name": "NCCL_PROTO",
          "value": "simple"
         },
         {
          "name": "NCCL_SOCKET_IFNAME",
          "value": "^lo,docker0"
         },
         {
          "name": "PYTORCH_CUDA_ALLOC_CONF",
          "value": "expandable_segments:True"
         },
         {
          "name": "TORCH_DISTRIBUTED_DEBUG",
          "value": "DETAIL"
         },
         {
          "name": "TORCH_DIST_INIT_BARRIER",
          "value": "1"
         },
         {
          "name": "TORCH_NCCL_ASYNC_ERROR_HANDLING",
          "value": "1"
         },
         {
          "name": "TORCH_NCCL_DEBUG_INFO_TEMP_FILE",
          "value": "/local/nccl_trace_rank_"
         },
         {
          "name": "TORCH_NCCL_DUMP_ON_TIMEOUT",
          "value": "1"
         },
         {
          "name": "TORCH_NCCL_ENABLE_MONITORING",
          "value": "1"
         },
         {
          "name": "TORCH_NCCL_TRACE_BUFFER_SIZE",
          "value": "20000"
         }
        ],
        "image": "842413447717.dkr.ecr.us-west-2.amazonaws.com/fsdp:pytorch2.2",
        "imagePullPolicy": "Always",
        "name": "pytorch",
        "resources": {
         "limits": {
          "nvidia.com/gpu": 1,
          "vpc.amazonaws.com/efa": 1
         },
         "requests": {
          "nvidia.com/gpu": 1,
          "vpc.amazonaws.com/efa": 1
         }
        },
        "securityContext": {
         "capabilities": {
          "add": [
           "IPC_LOCK"
          ]
         }
        },
        "volumeMounts": [
         {
          "mountPath": "/local",
          "name": "local"
         },
         {
          "mountPath": "/etc/config",
          "name": "train-script"
         },
         {
          "mountPath": "/dev/shm",
          "name": "shm"
         }
        ]
       }
      ],
      "restartPolicy": "OnFailure",
      "volumes": [
       {
        "hostPath": {
         "path": "/mnt/k8s-disks/0"
        },
        "name": "local"
       },
       {
        "hostPath": {
         "path": "/dev/shm",
         "type": "Directory"
        },
        "name": "shm"
       },
       {
        "configMap": {
         "defaultMode": 420,
         "items": [
          {
           "key": "train-script.sh",
           "mode": 365,
           "path": "train-script.sh"
          }
         ],
         "name": "train-script-fsdp"
        },
        "name": "train-script"
       }
      ]
     }
    }
   }
  }
 },
 "Status": {
  "conditions": [
   {
    "lastTransitionTime": "2024-09-26T01:06:51Z",
    "lastUpdateTime": "2024-09-26T01:06:51Z",
    "message": "PyTorchJob fsdp is created.",
    "reason": "PyTorchJobCreated",
    "status": "True",
    "type": "Created"
   },
   {
    "lastTransitionTime": "2024-09-26T01:07:02Z",
    "lastUpdateTime": "2024-09-26T01:07:02Z",
    "message": "PyTorchJob kubeflow/fsdp is running.",
    "reason": "PyTorchJobRunning",
    "status": "True",
    "type": "Running"
   }
  ],
  "replicaStatuses": {
   "Worker": {
    "active": 8,
    "selector": "training.kubeflow.org/job-name=fsdp,training.kubeflow.org/operator-name=pytorchjob-controller,training.kubeflow.org/replica-type=worker"
   }
  },
  "startTime": "2024-09-26T01:07:00Z"
 },
 "ConsoleURL": "https://us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/cluster-management/k8-g5-8x-4"
}
```

You can use `hyperpod list-pods` command to list pods.

``` bash
hyperpod list-pods --job-name fsdp -n kubeflow
```

``` json
{
 "pods": [
  {
   "PodName": "fsdp-worker-0",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  },
  {
   "PodName": "fsdp-worker-1",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  },
  {
   "PodName": "fsdp-worker-2",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  },
  {
   "PodName": "fsdp-worker-3",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  },
  {
   "PodName": "fsdp-worker-4",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  },
  {
   "PodName": "fsdp-worker-5",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  },
  {
   "PodName": "fsdp-worker-6",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  },
  {
   "PodName": "fsdp-worker-7",
   "Namespace": "kubeflow",
   "Status": "Running",
   "CreationTime": "2024-09-26 01:07:01+00:00"
  }
 ]
}
```

You can use `hyperpod get-log` command to print logs from a pod.

``` bash
hyperpod get-log --job-name fsdp --pod fsdp-worker-0 -n kubeflow
```

```
    :
2024-09-26 01:09:17 I [train.py:102] Batch 0 Loss: 11.67824, Speed: 0.40 samples/sec, lr: 0.000006
2024-09-26 01:09:34 I [train.py:102] Batch 1 Loss: 11.71413, Speed: 0.47 samples/sec, lr: 0.000013
2024-09-26 01:09:52 I [train.py:102] Batch 2 Loss: 11.55315, Speed: 0.46 samples/sec, lr: 0.000019
2024-09-26 01:10:09 I [train.py:102] Batch 3 Loss: 11.21573, Speed: 0.47 samples/sec, lr: 0.000025
2024-09-26 01:10:26 I [train.py:102] Batch 4 Loss: 10.91101, Speed: 0.46 samples/sec, lr: 0.000031
    :
```

### Troubleshoot

When you don't see logs from pods, use `kubectl` to check the status of underlying Kubernetes resources.

``` bash
# List PyTorchJobs
kubectl get pytorchjobs -n kubeflow

# Get details of a PyTorchJob
kubectl describe pytorchjob fsdp -n kubeflow

# List Pods
kubectl get pods -n kubeflow

# Get details of a Pod
kubectl describe pod fsdp-worker-0 -n kubeflow
```


### Stop

To stop the current training job, use the following command.

``` bash
hyperpod cancel-job --job-name fsdp -n kubeflow
```

And verify that list of jobs is empty.

``` bash
hyperpod list-jobs -n kubeflow
```

``` json
{
 "jobs": []
}
```


## Migration from FSDP1 to FSDP2

If you have existing FSDP1 training code, the key changes to migrate to FSDP2 include:

### Code Changes
- Replace `FullyShardedDataParallel` with `fully_shard` function
- Use meta device initialization for all ranks
- Update to `MixedPrecisionPolicy` and `CPUOffloadPolicy`
- Migrate checkpointing to DTensor state dict APIs (`get_model_state_dict`, `set_model_state_dict`)
- Use `torch.nn.utils.clip_grad_norm_` instead of `model.clip_grad_norm_`

### Configuration Changes
- Update `--nnodes` to elastic range format: `$MIN_NODES:$MAX_NODES`
- Add FSx PersistentVolumeClaim for checkpoint storage
- Update PyTorch version to 2.6.0 or later

For detailed migration instructions, refer to the training code in the repository.

## Additional Resources

- [PyTorch FSDP2 Tutorial](https://pytorch.org/tutorials/intermediate/FSDP_tutorial.html)
- [DTensor Documentation](https://pytorch.org/docs/stable/distributed.tensor.html)
- [AWS Distributed Training Examples](https://github.com/aws-samples/awsome-distributed-training)
- [PyTorch Distributed Checkpoint](https://pytorch.org/docs/stable/distributed.checkpoint.html)
