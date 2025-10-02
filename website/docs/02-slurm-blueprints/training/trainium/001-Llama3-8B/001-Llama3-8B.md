---
title: "Llama3 8B (trn1.32xlarge)"
sidebar_position: 1
weight: 40
---

# Llama3 8B (trn1.32xlarge)

![Llama](/img/02-llama/llama3.jpg)

This tutorial demonstrates launching a Llama 3 8B training job on SageMaker HyperPod. Scripts are included for Llama 3 8B which requires at least one `trn1.32xlarge`. 

## Parallelism

The model training script uses Neuronx Distributed Training (NxDT) library, which includes both tensor and pipeline parallelism techniques. For more information about Neuronx Distributed Training design, see [NxD Training](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/libraries/nxd-training/index.html). NxDT implements tensor parallelism through a special transformer that can be split by attention head across multiple devices, but reducing the number of communications between attention heads. Pipeline parallelism is achieved by placing groups of transformer layers on different devices.

We'll be using a single `trn1.32xlarge` instance for training. This instance contains 16 x Trainium chips, each with 2 x neuron cores. PyTorch sees each core as an individual device, so we'll be training across 32 devices. In the Llama 8B example provided, the transformers use 32 attention heads and 32 layers. We use 8 way tensor parallelism, so 4 attention head are placed on each Neuron core. After splitting by 8, each piece of the model is small enough to fit on a single Neuron core, so we don't use pipeline parallelism. The model is split across 8 neuron cores, with 4 way data parallelism.

## Compilation

To get the best performance on Trainium, it's a good idea to compile the model before training. This can be done by running `neuron_parallel_compile torchrun your_model.py` and setting the model to train for a few steps (5-10). This will build the graphs of the model, and store them in a cache so the next time you run `torchrun your_model.py` training will start much faster.

In this case, we've already compiled the model and stored the graphs in `neuron_cache` in the training artifact package. 

## Software Environment

The current setup uses a virtual environment however it's possible to also use a [container image](https://swsmith.cc/posts/containers-aws-parallelcluster.html).
