---
title: Training Operator Overview
sidebar_position: 1
---

# HyperPod Training Operator Job

:::tip Reference Documentation
For production guidance, see [HyperPod Training Operator overview](/docs/eks-orchestration/add-ons/hp-training-operator/overview) and [Fully Sharded Data Parallel (FSDP)](/docs/eks-orchestration/training-and-fine-tuning/fsdp/fully-sharded-data-parallel).
:::

> You: "Challenge accepted. Give me 15 minutes."

## 🧬 The Mission: Train ESM2

**Your task**: Train the ESM2 protein language model on the UniRef50 dataset using the HyperPod Training Operator.

**Why ESM2?** It's a state-of-the-art protein language model from Meta AI that understands protein sequences like GPT understands text. It can predict protein structure, function, and properties directly from amino acid sequences.

**The dataset**: [UniRef50](https://huggingface.co/datasets/agemagician/uniref50) — millions of protein sequences, preprocessed and tokenized into Apache Arrow format, ready at `/fsx/arrow` (the `DATASET_DIR`)

## 🎯 What You'll Learn

- How to submit distributed training jobs with the HyperPod Training Operator
- Understanding `HyperPodPyTorchJob` YAML configurations
- Monitoring training with `kubectl` and `kubetail`
- Automatic fault recovery and hang detection
- Checkpoint management with FSx for Lustre

This example showcases how to submit a training job with the HyperPod training operator using the [Hugging Face Transformers Library](https://huggingface.co/docs/transformers/en/index).

## HyperPod Training Operator Overview

The [Amazon SageMaker HyperPod training operator](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-eks-operator.html) helps you accelerate generative AI model development by efficiently managing distributed training across large GPU clusters. It introduces intelligent fault recovery, hang job detection, and process-level management capabilities that minimize training disruptions and reduce costs. Unlike traditional training infrastructure that requires complete job restarts when failures occur, this operator implements surgical process recovery to keep your training jobs running smoothly.

The operator also works with HyperPod's health monitoring and observability functions, providing real-time visibility into training execution and automatic monitoring of critical metrics like loss spikes and throughput degradation. You can define recovery policies through simple YAML configurations without code changes, allowing you to quickly respond to and recover from unrecoverable training states. These monitoring and recovery capabilities work together to maintain optimal training performance while minimizing operational overhead.

## ESM2 Model

In this example, we will be training the SOTA general-purpose protein language model. It can be used to predict structure, function and other protein properties directly from individual sequences. Released with Lin et al. 2022 (Aug 2022 update).

- More about the model from [facebook research GitHub](https://github.com/facebookresearch/esm)
- [Evolutionary-scale prediction of atomic-level protein structure with a language model](https://www.science.org/doi/10.1126/science.ade2574)
