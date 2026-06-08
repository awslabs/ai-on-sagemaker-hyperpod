---
title: Resiliency Overview
sidebar_position: 1
---

# Resiliency

:::tip Reference Documentation
For production resiliency configuration and best practices, see [Slurm Resiliency](/docs/slurm-orchestration/validation-and-testing/resiliency/slurm-resiliency).
:::

## Overview

SageMaker HyperPod is built for [resilient training](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-resiliency.html) - it continuously monitors the cluster using the following health checks:

| Health Check | Instance Type | Description |
|---|---|---|
| DCGM policies | NVIDIA GPUs | Continuously monitors all GPU-related policies from [NVIDIA DCGM](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/index.html#automate-gpu-management-policies) |
| NVIDIA SMI | NVIDIA GPUs | [nvidia-smi](https://developer.nvidia.com/nvidia-system-management-interface) utility to manage and monitor GPUs |
| XID | NVIDIA GPUs | Monitors kernel logs for any [XID message](https://docs.nvidia.com/deploy/xid-errors/index.html) |
| Neuron sysfs | Trainium/Inferentia | Health of Neuron devices via [Neuron sysfs](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/tools/neuron-sys-tools/neuron-sysfs-user-guide.html) |
| EFA | All | Diagnostic of Elastic Fabric Adaptor devices |
| DCGM Diagnostic | NVIDIA GPUs | [DCGM diagnostics level 2](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/dcgm-diagnostics.html) stress testing |
| CPU stress | All | [Linux stress](https://manpages.ubuntu.com/manpages/noble/man1/stress.1.html) tool for CPU health |

## Test Case

In this example we'll:
1. Submit a training job using Picotron with [checkpointing](https://github.com/NVIDIA/Megatron-LM#activation-checkpointing-and-recomputation) enabled
2. Inject an [Xid Error](https://docs.nvidia.com/deploy/xid-errors/index.html)
3. Observe the cluster to ensure it properly recovers from the last checkpoint file

:::info Prerequisites
Before proceeding, make sure you've completed the [Picotron Training](../03-picotron/02-distributed-training-docker.md) section.
:::
