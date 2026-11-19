---
title: Deploy Qwen2.5 with vLLM
sidebar_position: 5
---

# Deploy Qwen2.5 with vLLM on the HyperPod Inference Operator

## 🎯 The Plan

**What we're deploying**: An open-weights chat model, **Qwen2.5-1.5B-Instruct**, served by the vLLM inference engine.

**How we'll deploy**: With the same HyperPod Inference Operator you used for JumpStart, but this time you bring the serving container and the model yourself. The whole deployment is one Kubernetes resource, an `InferenceEndpointConfig`. The operator turns it into a running model behind a SageMaker endpoint.

## What is vLLM?

vLLM is a high-throughput, memory-efficient inference and serving engine for large language models. Two ideas make it fast:

- **PagedAttention** manages the attention key/value cache like virtual memory pages, so GPU memory is used efficiently and more requests fit on the same card.
- **Continuous batching** keeps the GPU busy by adding and retiring requests on every step instead of waiting for a whole batch to finish.

vLLM also ships an OpenAI-compatible HTTP server (`/v1/models`, `/v1/completions`, `/v1/chat/completions`), so any OpenAI client works against it.

## JumpStart vs. bring your own container

Both deployments in this module run on the HyperPod Inference Operator and both end in a SageMaker endpoint. What changes is how much you decide yourself:

| | JumpStart (`JumpStartModel`) | vLLM (`InferenceEndpointConfig`) |
|---|---|---|
| Model source | SageMaker JumpStart catalog | Any model on the Hugging Face Hub, Amazon S3, or Amazon FSx |
| Serving container | Chosen by JumpStart | You choose and pin it: the AWS vLLM Deep Learning Container |
| Serving flags | Chosen by JumpStart | You set them (context length, served model name, ...) |
| Front door | SageMaker endpoint backed by an internal ALB | The same: SageMaker endpoint backed by an internal ALB |
| Invoke with | `aws sagemaker-runtime invoke-endpoint` | The same, plus vLLM's OpenAI API on the pod |

JumpStart is the fastest way to a catalog model. `InferenceEndpointConfig` is what you use for your own models, such as a fine-tuned checkpoint, or when you need a specific engine version and specific serving flags. The operator still creates the load balancer, TLS certificate and SageMaker endpoint for you.

:::warning
This cluster has two A10G GPUs (one per `ml.g5.2xlarge` node), and the JumpStart deployment can autoscale to use both. The first step on the next page deletes the JumpStart deployment so vLLM has a GPU.
:::

## What to expect

- One GPU (24 GB) on one of the nodes.
- A small model, Qwen2.5-1.5B-Instruct (Apache-2.0). No Hugging Face token is needed.
- A single `kubectl apply` to get from manifest to a callable SageMaker endpoint. Most of the wait is the first pull of the roughly 9 GB vLLM image onto the node.

[So let's go ahead and deploy! →](./06-deploy-vllm.md)
