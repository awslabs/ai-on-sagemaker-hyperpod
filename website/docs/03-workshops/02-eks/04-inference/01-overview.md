---
title: Inference on HyperPod
sidebar_position: 1
---

# Inference on HyperPod: the grand finale

This section shows how to set up your cluster for inference and provides examples to deploy LLMs using the HyperPod Inference Operator.

## 🎬 The final challenge

> **Investor:** "Impressive. You've shown me the cluster setup, training, resiliency. But here's the real question: can you deploy your model in PRODUCTION?"
>
> **Jane Doe:** "ML Engineer, show them the inference deployment."
>
> **You:** "Time for the grand finale. Let me deploy a production-ready model using the HyperPod Inference Operator."
>
> **Investor:** "I want to see: (1) a real model deployed, (2) auto-scaling for production load, (3) something I can actually interact with. Can you do that?"

## 🎯 Mission: production deployment

**The challenge:** deploy a production-ready inference endpoint that:

- Uses the HyperPod Inference Operator
- Auto-scales based on demand
- Provides real-time predictions
- Has an interactive demo the investors can use

**What you'll deploy:** the Gemma 2B Instruct model from SageMaker JumpStart as a proof of concept.

**Why this matters:** this is the culmination of Project Helix — from training to production deployment!

## 🤔 Why Gemma 2B Instruct and not your ESM2 model?

You just trained ESM2, so why pivot to a different model for the finale? Because the star of this section is **the deployment platform, not the model**. We want the investors to see, type, and react — and a conversational LLM like Gemma 2B Instruct delivers an instantly interactive moment in the Playground that anyone in the room can understand.

ESM2 speaks a different language entirely: it reasons over **protein sequences**, returning embeddings and masked-residue predictions rather than chat replies. Showcasing it well calls for a purpose-built protein inference experience — sequence generation, structure and function prediction — which is a rich demo in its own right and deserves its own stage rather than being squeezed into a five-minute grand finale.

So we choose the right tool for the moment: Gemma 2B Instruct to demonstrate the production-grade muscle of the HyperPod Inference Operator — one-click deploy, autoscaling, a live SageMaker endpoint — using a model whose value is obvious at a glance. The exact same operator and workflow deploy your own ESM2 checkpoints when you're ready to build that protein-native experience.

## Two ways to deploy

This module shows two ways to get a model serving on your HyperPod EKS cluster. Both use the HyperPod Inference Operator and both end in a SageMaker endpoint backed by an internal ALB:

- **JumpStart:** pick a model from the SageMaker JumpStart catalog and the operator picks the serving container and settings for you. This is the fastest route to a production endpoint and is what the [first subsection](./02-jumpstart-overview.md) walks through.
- **Bring your own container:** you choose the model (from the Hugging Face Hub, Amazon S3 or Amazon FSx), the serving container (here the AWS vLLM Deep Learning Container) and its serving flags. This is the second subsection: [Deploy Qwen2.5 with vLLM](./05-vllm-overview.md).

:::warning
Both paths share the same two NVIDIA RTX PRO 4500 Blackwell GPUs on this cluster, so only one deployment should run at a time. The vLLM subsection starts by deleting the JumpStart deployment.
:::

## Beyond JumpStart: deploy from S3, FSx, or Hugging Face Hub

In this workshop, we deploy a model using the SageMaker JumpStart UI for simplicity. However, the HyperPod Inference Operator also supports deploying models directly from **Amazon S3**, **Amazon FSx**, or the **Hugging Face Hub** using `kubectl` and a custom resource definition (CRD). This gives you full flexibility to deploy fine-tuned models from your own storage, including the ESM2 checkpoint you just trained on FSx. For step-by-step instructions on deploying models from these sources, see [Deploy models from Amazon S3, Amazon FSx, or Hugging Face Hub using kubectl](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-model-deployment-deploy-ftm.html).

The vLLM subsection, [Deploy Qwen2.5 with vLLM](./06-deploy-vllm.md), is a hands-on example: an `InferenceEndpointConfig` that loads a model from the Hugging Face Hub. Pointing `modelSourceConfig` at FSx instead is how you would serve your ESM2 checkpoint.
