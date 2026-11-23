---
title: Verify Cluster Connection
sidebar_position: 3
---

# Verify cluster connection

## 🔌 Level 2: connection check

**Objective:** verify you can actually access the cluster and that everything is configured correctly.

**Why:** before we start training, we need to make sure that:

- Environment variables are set
- `kubectl` can talk to the cluster

**Where to run these commands:** in the terminal of your Code Editor instance (not your local machine!).

All the required environment variables are already set up for you on your Code Editor instance. Additionally, you should already have access to your EKS cluster from the terminal of your Code Editor instance. Let's verify that that's the case.

:::warning
Please make sure that you follow these instructions from the terminal of your Code Editor instance. If you execute them from anywhere else, these commands will fail.
:::

## Verify that environment variables were set

In your Code Editor instance, under **Explorer**, open up the `fsx-shared/env_vars` file. This file should look like the following:

```bash
export AWS_REGION=us-west-2
export EKS_CLUSTER_NAME=sagemaker-hyperpod-eks-cluster
export PRIVATE_SUBNET_ID=subnet-02de352491f5d57a8
export SECURITY_GROUP_ID=sg-040898e7aae186441
export S3_BUCKET_NAME=ws-assets-prod-iad-r-pdx-f3b3f9f1a7d6a3d0
export EKS_CLUSTER_ARN=arn:aws:eks:us-west-2:339712812531:cluster/sagemaker-hyperpod-eks-cluster
export VPC_ID=vpc-0aaa1703ffd6b1fd3
export EXECUTION_ROLE=arn:aws:iam::339712812531:role/sagemaker-hyperpod-eks-SMHP-Exec-Role-us-west-2
export INSTANCE_TYPE=ml.g7.2xlarge
export TARGET_PATH=/fsx/esm
export DOCKER_IMAGE_NAME=esm
export TAG=aws
export MODEL=facebook/esm2_t6_8M_UR50D
export ACCOUNT=339712812531
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/
export GPU_PER_NODE=1
export EFA_PER_NODE=0
export NUM_NODES=2
export TOTAL_GPUS=2
export OUTPUT_DIR=/fsx/esm/output
export DATASET_DIR=/fsx/arrow
```

:::warning
Do not copy and paste the environment variables that you see here. These are just examples for an example account. The values are set dynamically based on your account ID and Region.
:::

You can verify that all these environment variables were set and sourced by trying to `echo` one of them out from your Code Editor instance terminal:

```bash
echo $EKS_CLUSTER_NAME
```

An example output:

```text
sagemaker-hyperpod-eks-cluster
```

Verify again that the environment variables have taken effect:

```bash
echo "Total number of GPU nodes: $NUM_NODES"
echo "Total number of GPUs: $TOTAL_GPUS"
```

Example output (for `ml.g7.2xlarge`):

```text
Total number of GPU nodes: 2
Total number of GPUs: 2
```

:::note
The live workshop has an expandable troubleshooting block here for "No output when you ran `echo $EKS_CLUSTER_NAME`?" whose contents were not captured in the crawl. See the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/01-cluster/05-verification) if your variables are unset.
:::

## Verify access to your SageMaker HyperPod cluster with kubectl

```bash
kubectl config current-context
kubectl get svc
```

An example output:

```text
arn:aws:eks:us-west-2:339712812531:cluster/sagemaker-hyperpod-eks-cluster
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   172.20.0.1   <none>        443/TCP   3h56m
```

:::note
The live workshop has an expandable "Unable to connect to cluster?" troubleshooting block here whose contents were not captured in the crawl. See the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/01-cluster/05-verification) if `kubectl` cannot reach the cluster.
:::

That's it! You're all configured. Let's proceed to train the model.
