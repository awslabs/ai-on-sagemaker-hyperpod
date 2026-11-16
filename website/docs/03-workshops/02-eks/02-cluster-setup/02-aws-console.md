---
title: View the AWS Console & Scale Up
sidebar_position: 2
---

# View the AWS Console & Scale Up

:::tip Reference Documentation
For a full tour of the cluster console, see [Reviewing the cluster console](/docs/eks-orchestration/getting-started/Reviewing%20the%20cluster%20console).
:::

## 🎮 Level 1: Cluster Inspection

**Objective**: Check out your HyperPod cluster and understand how to scale up the GPU nodes.

Now that we've created a cluster, we can monitor the status in the [SageMaker console](https://console.aws.amazon.com/sagemaker/home). This will show us cluster status, running instances, node groups, and allow us to easily modify the cluster.

Notice that there are two instance groups:

- **`general-purpose-worker-group`** — As a best practice, it is recommended to have non-GPU instances in your cluster to delegate pods that don't require GPU resources to.
- **`accelerated-worker-group-1`** — This is your instance group with your GPU instances.

:::caution If you see 0 CPU nodes in `general-purpose-worker-group`
Scale the general purpose group up to at least one instance before continuing, so that non-GPU pods (operators, sidecars, `etcd` for the task governance examples) have somewhere to be scheduled.
:::

## How to Scale up your GPU instances 🚀

For this workshop, we will be using 2 x `ml.g5.2xlarge` instances.

Scale the `accelerated-worker-group-1` instance group to 2 instances:

1. In the [SageMaker console](https://console.aws.amazon.com/sagemaker/home), open your HyperPod cluster.
2. Select the `accelerated-worker-group-1` instance group and choose **Edit**.
3. Set the instance count to `2` and save/update the cluster.
4. Wait for the cluster status to return to `InService` and for the new nodes to appear in `kubectl get nodes`.

:::note At an AWS-hosted event
At an AWS-hosted event the GPU nodes are pre-provisioned, so `accelerated-worker-group-1` already shows 2 instances and you can read the steps above without running them. Running the workshop in your own account, perform the scale-up now — node provisioning takes a few minutes.
:::
