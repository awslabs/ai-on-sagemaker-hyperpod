---
title: "Llama-3 70B (trn1.32xlarge) using NxD"
sidebar_position: 1
weight: 30
---

![Llama](/img/02-llama/llama3.jpg)

This tutorial demonstrates launching a Llama 3 70B training job on SageMaker HyperPod (cluster of 16 x ml.trn1.32xlarge instances). 

## Prerequisutes
- This guide assumes that you have a SMHP SLURM cluster of 16 x ml.trn1.32xlarge instances with a shared parallel filesystem like [Amazon FSx for Lustre](https://docs.aws.amazon.com/fsx/latest/LustreGuide/getting-started.html). If you don't have this yet, please follow the instructions listed in [1. Cluster Setup](/docs/slurm-orchestration/getting-started/initial-cluster-setup).
- WLOG, we assume that you are operating from the home directory of the controller machine as user `ubuntu` (default provisioned power user).

## Parallelism
For this sample, we will use the Neuronx Distributed (NxD) package alongside the PyTorch Neuron package. [NeuronX Distributed](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/frameworks/torch/training-torch-neuronx.html#training-torch-neuronx) is a package used to support different distributed training frameworks and provides a mechanism for those frameworks to run on xla based Neuron cores. NxD supports a bunch of data and model parallelism strategies that we will look into below. [PyTorch Neuron](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/frameworks/torch/torch-neuronx/programming-guide/training/pytorch-neuron-programming-guide.html#pytorch-neuronx) is a software package that enables PyTorch training, evaluation, and inference on Neuron devices.

We will be utilizing 3D parallelism for this sample. 3D parallelism combines data parallelism with model (tensor + pipeline) parallelism into a cohesive framework, creating a 3-D mesh of devices. Each axis of this "mesh" corresponds to one of:
- Data Parallelism Axis: Distributes training data across devices
- Tensor Parallelism Axis: Parallelizes tensor layers' computations/calculations across devices
- Pipeline Parallelism Axis: Distributes the model's layers across devices

This combination of data + model parallelism allows for efficient scaling and utilization of hardware resources. For instance, tensor parallelism requires the highest communication bandwidth and is best suited for Trainium chips within the same Trn1 node with strong NeuronLink interconnect. Pipeline parallelism, which has lower communication requirements, can be used across nodes. Data parallelism, which requires the least communication, can span across multiple nodes. To learn more about the Trainium Architecture, check the [Neuron Docs](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/general/arch/neuron-hardware/trainium.html).

## Compilation
To get the best performance on Trainium, it's a good idea to compile the model before training. This can be done by running `neuron_parallel_compile torchrun your_model.py` and setting the model to train for a few steps (5-10). This will build the graphs of the model, and store them in a cache so the next time you run `torchrun your_model.py` training will start much faster.

## Steps
We will be doing the following:
1. *Download the llama3 model and tokenizer:* Download the model weights (checkpoints) and the tokenizer. We will also convert the checkpoints based on the distributed training configuration
2. *Download and preprocess the wiki-corpus dataset*
3. *Train with NxD!*