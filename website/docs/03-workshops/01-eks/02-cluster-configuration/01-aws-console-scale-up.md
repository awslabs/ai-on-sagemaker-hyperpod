---
title: View the AWS Console & Scale Up
sidebar_position: 1
---

# 🎮 Level 1: Cluster Inspection

> **Objective**: Check out your HyperPod cluster and scale up the GPU nodes.
>
> **Why**: The infrastructure team left the GPU instances at 0 to save costs while they were setting up. Now it's time to power them up for training!

Navigate to the SageMaker console to monitor cluster status, running instances, node groups, and modify the cluster.

Notice there are two instance groups:
- **general-purpose-worker-group**: 1 CPU instance (ml.m5.2xlarge) — best practice for non-GPU pods
- **gpu-worker-group**: 0 GPU instances (ml.g5.2xlarge) — your GPU instances to scale up!

:::warning
If you see 0 CPU nodes in `general-purpose-worker-group`, wait a few minutes for the cluster to fully initialize.
:::

## Scaling Up Your GPU Instances 🚀

For this workshop, we'll use **2 x `ml.g5.2xlarge`** instances.

1. Navigate to your HyperPod cluster in the SageMaker console
2. Select the `gpu-worker-group` instance group
3. Click **"Edit"** and change the count from 0 to **2**
4. Save the changes

That's it! Wait a few minutes, and your cluster will soon be back to **InService**!
