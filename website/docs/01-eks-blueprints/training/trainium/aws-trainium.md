---
title: AWS Trainium
sidebar_position: 1
---

# Train Llama 3.1 8B model using SageMaker HyperPod

In this section, we showcase how to pre-train Llama3.1-8B, Llama3 8B model using Trn1.32xlarge/Trn1n.32xlarge instances using the Neuron Distributed library. To train the LLama model in this example, we will apply the following optimizations using the Neuron Distributed library:

1. [Tensor Parallelism](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/neuronx-distributed/tensor_parallelism_overview.html#tensor-parallelism-overview)

2. [Sequence Parallel](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/neuronx-distributed/activation_memory_reduction.html#sequence-parallelism)

3. [Selective checkpointing](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/neuronx-distributed/activation_memory_reduction.html#activation-memory-reduction)

4. [ZeRO-1](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/frameworks/torch/torch-neuronx/tutorials/training/zero1_gpt2.html#zero1-gpt2-pretraining-tutorial)

## Setup your environment

Login to ECR and pull the `pytorch-training-neuronx` image

```sh
region=us-east-2
dlc_account_id=763104351884
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $dlc_account_id.dkr.ecr.$region.amazonaws.com

docker pull 763104351884.dkr.ecr.us-east-2.amazonaws.com/pytorch-training-neuronx:2.1.2-neuronx-py310-sdk2.19.1-ubuntu20.04
```

On your x86-64 based development environment:

Navigate to your home directory or your preferred project directory, clone the repo. 

``` bash
cd ~
git clone https://github.com/aws-samples/awsome-distributed-training/
cd awsome-distributed-training/3.test_cases/pytorch/neuronx-distributed/llama3/kubernetes
```

We will build docker image using the [Dockerfile](/docs/add-ons/integrations/skypilot) in this directory.  

```sh
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/
export IMAGE=llama3_trn
export TAG=:latest
docker build $DOCKER_NETWORK -t ${REGISTRY}${IMAGE}${TAG} .
```

<details>
<summary>Why $DOCKER_NETWORK?</summary>

> The environment variable <code>$DOCKER_NETWORK</code> is set to <code>--network=sagemaker</code> only if you deployed the SageMaker Studio Code Editor CloudFormation stack in the <a href="/docs/category/getting-started">Set Up Your Development Environment</a> section. This is necessary because SageMaker Studio uses a specific network configuration for its containers. Otherwise, it remains unset. 

</details>

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

## Create your training job and start it

### Generate Job Spec Files for tokenization and training

The default config in the script launches a 8B Llama 3.1 model. When you run the generate-jobspec.sh script it creates 2 yaml files tokenize_data.yaml and llama3_train.yaml

You will have to update the HF_ACCESS_TOKEN in order for the tokenization to work.

Please edit the `./generate-jobspec.sh` script with your desired environment settings.

```bash
./generate-jobspec.sh
```

### Tokenize Data

The example uses [wikicorpus](https://huggingface.co/datasets/gboleda/wikicorpus) dataset from Hugginface Hub. The tokenize_data.yaml job downloads the dataset and tokenizes it. Finally store the dataset in Fsx Lustre which can be used for training the model.

```bash
kubectl apply -f ./tokenize_data.yaml
```

### Train Model

The train_llama3.yaml job spec file trains llama 3.1 8B model with the tokenized data from previous step. By default the code uses 1 trn1.32xlarge but can be changed to any number of nodes. 

```bash
kubectl apply -f ./llama3_train.yaml
```