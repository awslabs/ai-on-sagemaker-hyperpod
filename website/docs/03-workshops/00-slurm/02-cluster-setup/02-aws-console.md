---
title: AWS Console
sidebar_position: 2
---

# AWS Console

Now that we've created a cluster, we can monitor the status in the [SageMaker console](https://console.aws.amazon.com/sagemaker/home). This will show us cluster status, running instances, node groups, and allow us to easily modify the cluster.

:::tip
Wait until your cluster status changes to **InService** before proceeding. This should take ~10 minutes.
:::

## About the ml.g5.8xlarge Instance

The g5.8xlarge instance is part of AWS's G5 series, designed for a wide range of graphics-intensive and machine learning use cases. It includes an NVIDIA A10G GPU, making it useful for tasks like 3D rendering, video processing, and machine learning. The g5.8xlarge comes equipped with [Amazon Elastic Fabric Adapter (EFA)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html) enabled networking, and contains 900 GiB NVMe SSD.

For the sake of this workshop, we will use 2 g5.8xlarge instances to train SmolLM-1.7B using 3D parallelism.

## Instance Specifications

| Specification | Value |
|---|---|
| vCPUs | 32 |
| Memory | 128 GiB |
| GPU | 1 x NVIDIA A10G (24 GiB GPU Memory) |
| Storage | 1 x 900 GiB NVMe SSD |
| Network Performance | Up to 25 Gbps |
| Hourly Pricing | Starting at $2.448 per hour |
