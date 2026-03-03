---
title: "LoRA - Trainium"
sidebar_position: 2
weight: 3
---

This example showcases how to train llama 3.1 models using AWS Trainium instances and Huggingface Optimum Neuron. 🤗 Optimum Neuron is the interface between the 🤗 Transformers library and AWS Accelerators including AWS Trainium and AWS Inferentia. It provides a set of tools enabling easy model loading, training and inference on single- and multi-Accelerator settings for different downstream tasks. 


## Prerequisites

Before running this training, you'll need to create a SageMaker HyperPod cluster with at least 1 trn1.32xlarge/ trn1n.32xlarge instance group. 

Please  make sure that you deploy Neuron device plugin, EFA device plugin, and Kubeflow training operator to your cluster. 

See [What Dependencies are Installed on Your EKS Cluster](/docs/Introduction#prerequisites) for details.

To build a container image, you need a x86-64 based development environment with Docker installed. If you use recent Mac with Apple Silicon, they are not x86-64 based but ARM based. You can use SageMaker Code Editor for this purpose.

Since [llama 3.1](https://huggingface.co/meta-llama/Meta-Llama-3.1-8B) is a gated model users have to register in Huggingface and obtain an HF_Access_Token before running this example.

We need to setup an PVC for FSx to store the tokenized data and training checkpoints. Please follow the link [here](/docs/eks-orchestration/getting-started/Set%20up%20your%20shared%20file%20system) to setup FSx CSI Driver and PVC. 

## Verified instance types, instance counts

- ml.trn1.32xlarge x (1,2)
- ml.trn1n.32xlarge x (1,2)

## Validate the cluster configuration

* View the AWS Console following this [instruction](/docs/eks-orchestration/getting-started/Reviewing%20the%20cluster%20console).
* Set environment variables. This is done in [Verifying cluster connection to EKS](/docs/eks-orchestration/getting-started/Verifying%20cluster%20connection%20to%20EKS).


## Create and mount the FSx Lustre File System to the SageMaker HyperPod 

* First install the FSx for Lustre CSI driver following this [instruction](/docs/eks-orchestration/getting-started/Set%20up%20your%20shared%20file%20system), and we will use dynamic provisioning

* Create a persistent volume claim that uses the `fsx-claim` storage claim with namespace `kubeflow`:

```sh
cat <<EOF> pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fsx-claim
  namespace: kubeflow
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: fsx-sc
  resources:
    requests:
      storage: 1200Gi
EOF

kubectl apply -f pvc.yaml
```

This persistent volume claim will kick off the dynamic provisioning of an FSx for Lustre file system based on the specifications provided in the storage class.

View the status of the persistent volume claim:

```sh
kubectl describe pvc fsx-claim -n kubeflow
```

Mount the volume to container

After the pvc status is set to `Bound` before deploying any pods that reference the persistent volume claim. The status may remain in a Pending state ( ~10 mins) while the file system is being provisioned.
Use the following command to mount the volume.

```sh
cat <<EOF> pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fsx-app
  namespace: kubeflow
spec:
  containers:
  - name: app
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(date -u) >> /data/out.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: fsx-claim
EOF

kubectl apply -f pod.yaml
```


## Apply Low-Rank Adaptation (LoRA) Finetune Llama 3.1 8B model with Optimum Neuron using SageMaker HyperPod

In this section, we showcase how to finetune Llama3.1-8B, Llama3 8B model using Trn1.32xlarge/Trn1n.32xlarge instances using the Optimum Neuron library. To finetune the LLama model in this example, we will apply the following optimization techniques:

1. [Tensor Parallelism](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/neuronx-distributed/tensor_parallelism_overview.html#tensor-parallelism-overview)

2. [Sequence Parallel](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/neuronx-distributed/activation_memory_reduction.html#sequence-parallelism)

3. [Selective checkpointing](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/neuronx-distributed/activation_memory_reduction.html#activation-memory-reduction)

4. [Lora Finetuning](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/neuronx-distributed/lora_finetune_developer_guide.html)


Login to ECR and pull the `huggingface-pytorch-training-neuronx` image

```sh
region=us-east-1
dlc_account_id=763104351884
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $dlc_account_id.dkr.ecr.$region.amazonaws.com

docker pull ${dlc_account_id}.dkr.ecr.${region}.amazonaws.com/huggingface-pytorch-training-neuronx:2.1.2-transformers4.43.2-neuronx-py310-sdk2.20.0-ubuntu20.04-v1.0
```

On your x86-64 based development environment:

Navigate to your home directory or your preferred project directory, clone the repo. 

``` bash
cd ~
git clone https://github.com/Captainia/awsome-distributed-training.git
git checkout optimum-neuron-eks
cd 3.test_cases/pytorch/optimum-neuron/llama3/kubernetes/fine-tuning
```


Build Docker Image and push to ECR

```sh
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/
export IMAGE=peft-optimum-neuron
export TAG=:latest
docker build --network=sagemaker -t ${REGISTRY}${IMAGE}${TAG} .
```

We will build docker image using the [Dockerfile](https://github.com/Captainia/awsome-distributed-training/blob/optimum-neuron-eks/3.test_cases/pytorch/optimum-neuron/llama3/kubernetes/fine-tuning/Dockerfile) in this directory.  

:::note
:::expand{header="Why $DOCKER_NETWORK?" defaultExpanded=false}
The environment variable`$DOCKER_NETWORK` is set to `--network=sagemaker` only if you deployed the SageMaker Studio Code Editor. This is necessary because SageMaker Studio uses a specific network configuration for its containers. Otherwise, it remains unset. 
:::

Then push the image to your private registry

```sh
# Create registry if needed
export REGISTRY_COUNT=$(aws ecr describe-repositories | grep \"${IMAGE}\" | wc -l)
if [ "${REGISTRY_COUNT//[!0-9]/}" == "0" ]; then
    echo "Creating repository ${REGISTRY}${IMAGE} ..."
    aws ecr create-repository --repository-name ${IMAGE}
else
    echo "Repository ${REGISTRY}${IMAGE} already exists"
fi

# Login to registry
echo "Logging in to $REGISTRY ..."
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

# Push image to registry
docker image push ${REGISTRY}${IMAGE}${TAG}
```
## Generate Job Spec Files for tokenization and training

The default config in the script launches a 8B Llama 3.1 model. When you run the generate-jobspec.sh script it creates 2 yaml files tokenize_data.yaml and llama3_train.yaml

You will have to update the HF_ACCESS_TOKEN in order for the tokenization to work.

Please edit the `./generate-jobspec.sh` script with your desired environment settings.

```bash
./generate-jobspec.sh
```

## Tokenize Data

The example uses [wikicorpus](https://huggingface.co/datasets/gboleda/wikicorpus) dataset from Hugginface Hub. The tokenize_data.yaml job downloads the dataset and tokenizes it. Finally store the dataset in Fsx Lustre which can be used for training the model.

```bash
kubectl apply -f ./tokenize_data.yaml
```

## Compile the model

Training on Trainium requires model compilation using the neuron_parallel_compile utility.

```sh
kubectl apply -f ./compile_peft.yaml
```
This step does the following:

*    Extracts computation graphs from a trial run (~10 training steps)
*    Performs parallel pre-compilation of these graphs
*    Uses identical scripts to actual training but with reduced max_steps
*    Prepares the model for efficient execution on Trainium hardware

The compilation process is essential for optimizing model performance on the specialized Trainium architecture.

## Train Model

The launch_peft_train.yaml job spec file finetunes llama 3.1 8B model with the tokenized data from previous step. By default the code uses 1 trn1.32xlarge but can be changed to any number of nodes. 

```bash
kubectl apply -f ./launch_peft_train.yaml
```

The training process uses tensor parallelism with degree 8 and leverages all 32 NeuronCores in the ml.trn1.32xlarge instance. Key features include:

*    Data parallel degree of 4
*    BFloat16 precision (XLA_USE_BF16=1) for reduced memory footprint
*    Gradient accumulation steps of 3 for larger effective batch size
*    LoRA configuration with:
        r=16 (rank)
        lora_alpha=16
        lora_dropout=0.05
        Target modules: q_proj and v_proj


## Consolidation the trained weights

During distributed training, model checkpoints are split across multiple devices. The consolidation process:

*    Combines distributed checkpoints into a unified model
*    Processes tensors in memory-efficient chunks
*    Creates sharded outputs with an index file
*    Saves the consolidated weights in safetensor format

This step is crucial for bringing together the distributed training results into a usable format.

```sh
kubectl apply -f ./consolidation.yaml
```

## Merge LoRA weights

The final step merges the LoRA adapters with the base model.
```sh
kubectl apply -f ./merge_lora.yaml
```
This process does the following:

*    Loads the base model and LoRA configuration
*    Transforms LoRA weight names to match base model structure
*    Merges the adapters with the original model weights
*    Saves the final model in a sharded format

The resulting merged model combines the base model's knowledge with the task-specific adaptations learned during fine-tuning, while maintaining the efficiency benefits of LoRA training.
