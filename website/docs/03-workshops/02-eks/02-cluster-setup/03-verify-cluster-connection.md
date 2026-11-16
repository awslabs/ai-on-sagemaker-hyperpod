---
title: Verify Cluster Connection
sidebar_position: 3
---

# Verify Cluster Connection

:::tip Reference Documentation
For the full set of connection methods and troubleshooting, see [Verifying cluster connection to EKS](/docs/eks-orchestration/getting-started/Verifying%20cluster%20connection%20to%20EKS).
:::

## 🔌 Level 2: Connection Check

**Objective**: Verify you can actually access the cluster and that everything is configured correctly.

**Why**: Before we start training, we need to make sure:

- Environment variables are set
- `kubectl` can talk to the cluster

**Where to run these commands**: In the terminal of your Code Editor instance (not your local machine!)

:::important
Please make sure that you follow these instructions from the terminal of your **Code Editor instance**. If you execute these from anywhere else, these commands will fail.
:::

## Verify that environment variables were set

In your Code Editor instance, under "Explorer", open up the `fsx-shared/env_vars` file.

This file should look like the following:

```bash
export AWS_REGION=us-west-2
export EKS_CLUSTER_NAME=sagemaker-hyperpod-eks-cluster
export PRIVATE_SUBNET_ID=subnet-0123456789abcdef0
export SECURITY_GROUP_ID=sg-0123456789abcdef0
export S3_BUCKET_NAME=<your-s3-bucket-name>
export EKS_CLUSTER_ARN=arn:aws:eks:us-west-2:<your-account-id>:cluster/sagemaker-hyperpod-eks-cluster
export VPC_ID=vpc-0123456789abcdef0
export EXECUTION_ROLE=arn:aws:iam::<your-account-id>:role/sagemaker-hyperpod-eks-SMHP-Exec-Role-us-west-2
export INSTANCE_TYPE=ml.g5.2xlarge
export TARGET_PATH=/fsx/esm
export DOCKER_IMAGE_NAME=esm
export TAG=aws
export MODEL=facebook/esm2_t6_8M_UR50D
export ACCOUNT=<your-account-id>
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/
export GPU_PER_NODE=1
export EFA_PER_NODE=0
export NUM_NODES=2
export TOTAL_GPUS=2
export OUTPUT_DIR=/fsx/esm/output
export DATASET_DIR=/fsx/arrow
```

:::warning
Do not copy paste the environment variables that you see here. These are just examples. The subnet, security group, VPC, bucket, account and role values must match your own account and region.
:::

If you are running the workshop in your own account, create the file and source it:

```bash
source fsx-shared/env_vars
```

:::note
In each new terminal you open, run `source fsx-shared/env_vars` again — the remaining sections assume these variables are set.
:::

You can verify that all these environment variables were set and sourced by trying to `echo` one of them out from your **Code Editor instance terminal**:

```bash
echo $EKS_CLUSTER_NAME
```

An example output:

```
sagemaker-hyperpod-eks-cluster
```

Verify again that the environment variables have taken effect:

```bash
echo "Total number of GPU nodes: $NUM_NODES"
echo "Total number of GPUs: $TOTAL_GPUS"
```

Example output (for `ml.g5.2xlarge`):

```
Total number of GPU nodes: 2
Total number of GPUs: 2
```

:::tip No output when you ran `echo $EKS_CLUSTER_NAME`?
The variables have not been sourced into your current shell. Run `source fsx-shared/env_vars` and try again.
:::

## Verify access to your SageMaker HyperPod cluster with kubectl

```bash
kubectl config current-context
kubectl get svc
```

An example output:

```
arn:aws:eks:us-west-2:<your-account-id>:cluster/sagemaker-hyperpod-eks-cluster
NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   172.20.0.1    <none>        443/TCP   3h56m
```

:::warning Unable to connect to cluster?
Update your kubeconfig against the EKS cluster and retry:

```bash
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION
```
:::

That's it! You're all configured. Let's proceed to train the model!
