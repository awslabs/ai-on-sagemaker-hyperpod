---
title: "Training Lab"
sidebar_position: 2
weight: 21
---

![Tranium](/img/02-llama/trn1.png)

In this section, we'll download our training scripts and start training Llama3 on a Trainium `trn1.32xlarge` instance.

## Step 1: Download Training Artifacts

Download and un-tar `training_artifacts.tar.gz` into the home directory, this is shared to the rest of the cluster via the `/fsx` filesystem: 

```bash
cd ~
curl -o training_artifacts.tar.gz ':assetUrl{path="/training_artifacts.tar.gz" source=s3}'
tar -xvf training_artifacts.tar.gz
```
This contains the data, a precompiled model, and all the same scripts included in this repo.

We use a small sample of the C4 (Cleaned Collosal Common Crawl) dataset. This is part of the data that was used to train Llama 3 originally. The entire dataset is available from [AllenAI on HuggingFace](https://huggingface.co/datasets/allenai/c4). Included with the data is the [Llama 3 tokenizer](https://huggingface.co/docs/transformers/model_doc/llama3), also available from HuggingFace.

## Step 2: Create the Python Virtual Environment

Before running training, build your environment. Make sure this repo is stored on the shared FSX volume of your cluster so all nodes have access to it.

Run below to build your virtual environment with all the required libraries including `torch_neuronx` and `nemo_neuronx` required to run Llama3 training.

:::caution Important
If you see an error `srun: command not found` make sure to exit back to the headnode:
```bash
exit
```
:::

```bash
cd training_artifacts/
srun ./create_env.sh
```
## Step 3: Download the dataset

```bash
mkdir ~/training_artifacts/neuronx-distributed-training/examples/examples_datasets/
cd ~/training_artifacts/neuronx-distributed-training/examples
python3 get_dataset.py --llama-version 3
```

This will use your compute node to build the environment. We need to build on a compute node because some of the packages expect to see Neuron devices when they're being installed.
