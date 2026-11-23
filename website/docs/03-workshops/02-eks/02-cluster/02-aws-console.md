---
title: View the AWS Console and Scale Up
sidebar_position: 2
---

# View the AWS console and scale up

## 🎮 Level 1: cluster inspection

**Objective:** check out your HyperPod cluster and understand how to scale up the GPU nodes.

Now that we have a cluster, we can monitor the status in the [SageMaker console](https://console.aws.amazon.com/sagemaker/home). This will show us cluster status, running instances and node groups, and allows us to easily modify the cluster.

Notice that there are two instance groups:

- `general-purpose-worker-group` — as a best practice, it is recommended to have non-GPU instances in your cluster to delegate pods that don't require GPU resources to.
- `accelerated-worker-group-1` — this is your instance group with your GPU instances.

:::note
The crawled source dropped the instance group names and instance types in this list. The group names above are taken from the callouts further down the same page; see the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/01-cluster/04-console) for the exact values and the accompanying console screenshots.
:::

:::important
If you see 0 CPU nodes in `general-purpose-worker-group`, follow the guidance in the live workshop — the expandable troubleshooting block for this case was not captured in the crawl.
:::

## How to scale up your GPU instances 🚀

For this workshop, we will be using 2 x `ml.g7.2xlarge` instances.

:::note
Normally, you would scale up the GPU instance group yourself, and the live workshop walks through exactly how to do that. To save time during this session, we have already pre-provisioned the cluster with the 2 GPU nodes up and running — so you should see `accelerated-worker-group-1` already at 2 instances. Feel free to read through the steps to understand the workflow; you can skip the actual scaling action.
:::

:::warning
Do not run the scaling steps, since the GPU nodes are pre-provisioned. The step-by-step scaling instructions and their screenshots were not captured in the crawl — see the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/01-cluster/04-console) for them.
:::
