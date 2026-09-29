---
title: Verify Cluster Connection
sidebar_position: 2
---

# 🔌 Level 2: Connection Check

> **Objective**: Verify you can actually access the cluster and that everything is configured correctly.
>
> **Why**: Before we start training, we need to make sure environment variables are set, kubectl can talk to the cluster, and Helm charts are installed.

:::important
Run all commands in the terminal of your **CodeEditor instance** (not your local machine!).
:::

## Verify Environment Variables

Open the `fsx-shared/env_vars` file in your CodeEditor. It should contain:

```bash
export AWS_REGION=us-west-2
export EKS_CLUSTER_NAME=sagemaker-hyperpod-eks-cluster
export INSTANCE_TYPE=ml.g5.2xlarge
export GPU_PER_NODE=1
export EFA_PER_NODE=0
export NUM_NODES=0
export TOTAL_GPUS=0
export OUTPUT_DIR=/fsx/esm/output
export DATASET_DIR=/fsx/arrow
# ... and more
```

Verify the variables are sourced:

```bash
echo $EKS_CLUSTER_NAME
```

### Update Node Count

Change the following values in `env_vars`:

```bash
export NUM_NODES=2
export TOTAL_GPUS=2
```

Then source the updated file:

```bash
source fsx-shared/env_vars
echo "Total number of GPU nodes: $NUM_NODES"
echo "Total number of GPUs: $TOTAL_GPUS"
```

## Verify kubectl Access

```bash
kubectl config current-context
kubectl get svc
```

## Verify Helm Chart Installation

```bash
helm list -n kube-system
```

That's it! You're all configured. Let's proceed to train the ESM model. 🚀
