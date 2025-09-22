---
title: "a. Setup"
weight: 31
---

## 1. Build a docker image

On your x86-64 based development environment:

1. Navigate to your home directory or your preferred project directory, clone the repo. 

    ``` bash
    cd ~
    git clone https://github.com/aws-samples/awsome-distributed-training/
    cd awsome-distributed-training/3.test_cases/17.SM-modelparallelv2
    ```


1. Pull the SageMaker Distributed Model-parallel image locally

    Login to ECR and pull the `smdistributed-modelparallel` image

    ``` bash
    region=us-west-2
    dlc_account_id=658645717510
    aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $dlc_account_id.dkr.ecr.$region.amazonaws.com

    docker pull $dlc_account_id.dkr.ecr.$region.amazonaws.com/smdistributed-modelparallel:2.2.0-gpu-py310-cu121
    ```


1. Build `smpv2` image

    Build a container image for this example using the code below:

    ``` bash
    export REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
    export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    export REGISTRY=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/
    export IMAGE=smpv2
    export TAG=:latest
    docker build $DOCKER_NETWORK -t ${REGISTRY}${IMAGE}${TAG} .
    ```
    :::::alert{type="info"}
    :::expand{header="Why $DOCKER_NETWORK?" defaultExpanded=false}
    The environment variable`$DOCKER_NETWORK` is set to `--network=sagemaker` only if you deployed the SageMaker Studio Code Editor CloudFormation stack in the [Set Up Your Development Environment](/00-setup/own-account/01-env-setup.md) section. This is necessary because SageMaker Studio uses a specific network configuration for its containers. Otherwise, it remains unset. 
    :::
    :::::

    If successful, you should see following success message at the end.

    ```
    Successfully built 123ab12345cd
    Successfully tagged 123456789012.dkr.ecr.us-west-2.amazonaws.com/smpv2:latest
    ```


1. Push the image to Amazon ECR

    In this step we create a container registry if one does not exist, and push the container image to it.

    ``` bash
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

    Pushing the image may take some time depending on your network bandwidth. If you use EC2 / CloudShell as your development machine, it will take 6~8 min.

