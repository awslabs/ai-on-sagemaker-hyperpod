---
title: "3. SageMaker model parallelism library (g5/p4/p5)"
weight: 4
---

This example showcases how to use SageMaker model parallelism library for model training.

The Amazon SageMaker model parallelism library (SMP) is a capability of SageMaker that enables high performance and optimized large scale training on SageMaker accelerated compute instances. Its core features are hybrid sharded data parallelism, tensor parallelism, activation checkpointing, and activation offloading. You can use SMP to accelerate the training and fine-tuning of large language models (LLMs), large vision models (LVMs), and foundation models (FMs) with hundreds of billions of parameters such as [Llama2](https://huggingface.co/docs/transformers/model_doc/llama2) and [GPT-NeoX](https://huggingface.co/docs/transformers/model_doc/gpt_neox).

The latest release of Amazon SageMaker model parallelism (SMP v2) aligns the library’s APIs and methods with open source PyTorch Fully Sharded Data Parallelism ([FSDP](https://pytorch.org/docs/stable/fsdp.html)), allowing users to easily enable SMP’s performance optimizations with minimal code change. Now, you can achieve state-of-the-art large model training performance on SageMaker in minutes by migrating your existing FSDP training scripts to SMP. We added support for FP8 training for Llama2 and GPT-NeoX Hugging Face transformer models on P5 instances with Transformer Engine integration.


## 0. Prerequisites

Before running this training, you'll need to create a cluster with Amazon EKS on SageMaker HyperPod with an FSx for Lustre file system. Instructions can be found in [1. Cluster Setup](/01-cluster). Please follow them if you haven't done so already.

Please also make sure that you deployed GPU device plugin, EFA device plugin, and Kubeflow training operator to your cluster. See the [install dependencies](/01-cluster/03-install-dependencies.md) page.

To build a container image, you need a x86-64 based development environment with Docker installed. If you use recent Mac with Apple Silicon, they are not x86-64 based but ARM based. You can use SageMaker Code Editor for this purpose.

## Verified instance types, instance counts

- ml.g5.8xlarge x 8