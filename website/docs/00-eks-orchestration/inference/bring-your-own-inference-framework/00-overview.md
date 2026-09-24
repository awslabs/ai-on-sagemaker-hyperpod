---
title: Bring Your Own Inference Framework with HyperPod Managed KV Cache
sidebar_position: 1
sidebar_label: Overview
---

# Bring Your Own Inference Framework with HyperPod Managed KV Cache

This guide shows how to run open source inference frameworks on SageMaker HyperPod and reuse HyperPod managed tiered KV cache through LMCache.

The examples cover:

- NVIDIA Dynamo with a Dynamo frontend and vLLM worker
- llm-d with a vLLM model server
- SGLang with LMCache IP mode

All three examples use the same HyperPod managed tiered-storage daemon on the GPU node:

```text
sagemaker-hyperpod://$(NODE_IP):9200
```

## When To Use This Pattern

Use this pattern when you want HyperPod to provide the managed cluster and KV-cache tiering substrate, but you want to bring your own serving framework, router, or scheduler.

Use the HyperPod Inference Operator path when you want the managed operator workflow and its supported model-serving abstractions.

## Common Architecture

Each example has the same core components:

- A SageMaker HyperPod EKS cluster with GPU nodes
- HyperPod tiered storage enabled
- The `ai-toolkit` daemon running on each GPU node
- A framework-specific serving pod
- LMCache configured to use the HyperPod daemon as remote storage
- A store, restart, replay validation that proves KV cache reuse survives the serving pod restart

## Install HyperPod Managed Tiered Storage

Before deploying Dynamo, llm-d, or SGLang, enable HyperPod managed tiered storage on the cluster. Follow the [SageMaker HyperPod managed tiered checkpointing setup guide](https://docs.aws.amazon.com/sagemaker/latest/dg/managed-tier-checkpointing-setup.html).

That setup installs the HyperPod `ai-toolkit` daemon on GPU nodes. The daemon owns the local shared-memory segment and exposes the node-local tiered-storage endpoint that LMCache uses:

```text
sagemaker-hyperpod://$(NODE_IP):9200
```

For these examples, verify that:

- The HyperPod cluster has tiered storage enabled.
- The `ai-toolkit` daemon pod is running on the target GPU node.
- The node has `/dev/shm/ai_toolkit_cache`.
- The serving pod mounts `/dev/shm/ai_toolkit_cache` as a `hostPath` file.

The examples in this section are intentionally small and use `Qwen/Qwen3-0.6B` so that they can run on a single-GPU HyperPod node. They were designed for a G6-class GPU instance group and use `g6-workers` as the example HyperPod instance-group label. Replace that value with your GPU instance-group name if your cluster uses a different label.
