---
title: Fully Sharded Data Parallel
sidebar_position: 1
sidebar_title: Fully Sharded Data Parallel
---

# Get Started Training Llama 2 with PyTorch FSDP in 5 Minutes

These scripts provide an easy way to get started with multinode [FSDP](https://pytorch.org/tutorials/intermediate/FSDP_tutorial.html) training on Slurm. It is designed to be as simple as possible, requires no data preparation, and uses a simple Conda environment. 


## Prerequisites

Before running this training, you'll need to create a Hyperpod cluster with an FSx for Lustre file system. Instructions can be found in [1. Cluster Setup](/docs/getting-started/orchestrated-by-slurm/initial-cluster-setup). Please follow them if you haven't done so already.

## Setup

### Create Environment

On your cluster head node:

TODO: we should stick with a single place for the ADT repo. Make this part of the initial cluster setup. Add it ot FSx. Every customer use it, so let's make it part of the required steps to deploy the cluster. 

1. Navigate to your home directory (assuming this was setup as a shared directory) and clone the repo:

    ```bash
    cd ~
    git clone https://github.com/aws-samples/awsome-distributed-training/
    cd awsome-distributed-training/3.test_cases/pytorch/FSDP/slurm
    ```

3. Run the `create_venv.sh` script. 

    * This script will first download and install [Miniconda](https://docs.conda.io/projects/miniconda/en/latest/), then create a Conda env called `pt_fsdp`.
    * By creating this environment on the shared FSx for Lustre volume, all compute nodes in our cluster will have access to it.

    ```bash
    . ./create_venv.sh
    ```

### Data

For this example, we'll be using the [allenai/c4](https://huggingface.co/datasets/allenai/c4) dataset. Instead of downloading the whole thing, the `create_streaming_dataloaders` function will stream the dataset from [HuggingFace](https://huggingface.co/datasets), so there's no data prep required for running this training.

If you'd like to instead use your own dataset, you can do so by [formatting it as a HuggingFace dataset](https://huggingface.co/docs/datasets/create_dataset), and passing its location to the `--dataset_path` argument.

## Training

### Create HuggingFace Token
**For this dataset, we will need a Hugging Face access token**. First, create a [Hugging Face account](https://huggingface.co/welcome). Then [generate your access token with read permissions](https://huggingface.co/docs/hub/en/security-tokens). Set your HuggingFace Token as an environment variable in your Python Virtual Environment by running:

TODO: we ask customers to create HF TOKENS all the time. As this is a pre-requisites for most of the content on the ADT repo, we SHOULD move this to the initial cluster setup part of the content. 

``` bash
export HF_TOKEN=<YOUR HF ACCESS TOKEN>
```

### Launch Training

The script to launch a Slurm batch training job can be found in `llama2_7b-training.sbatch`. You can adjust the number of training nodes by modifying `#SBATCH --nodes=4`. You can also adjust the training parameters in `TRAINING_ARGS`. Additional parameters can be found in `model_utils/arguments.py`. Note that we use the same directory for both `--checkpoint_dir` and `--resume_from_checkpoint`. If there are multiple checkpoints, `--resume_from_checkpoint` will automatically select the most recent one. This way if our training is interrupted for any reason, it will automatically pick up the most recent checkpoint.


To launch your training, run

```bash
sbatch llama2_7b-training.sbatch
```


You'll find a new file in the `logs` directory of the form `logs/llama2_7b-FSDP_[JOB ID].out`. This will be continuously updated with your training logs. Don't be worried if you see a long stream of NCCL logs (we prefer to use `NCCL_DEBUG=INFO` for verbose logging). After about a minute, you should see your model training, with an output similar to below for Llama2 :

```text
+ TORCHRUN_ARGS=('--nproc_per_node=8' '--nnodes=4' '--rdzv_id=2513' '--rdzv_backend=c10d' '--rdzv_endpoint=p5-dy-gpu-1')
+ TORCHRUN=torchrun
+ export TRAIN_SCRIPT=./train.py
+ TRAIN_SCRIPT=./train.py
+ TRAINING_ARGS=('--max_context_width=4096' '--num_key_value_heads=32' '--intermediate_size=11008' '--hidden_width=4096' '--num_layers=32' '--num_heads=32' '--model_type=llama_v2' '--tokenizer=hf-internal-testing/llama-tokenizer' '--checkpoint_freq=5000' '--validation_freq=500' '--max_steps=5000' '--checkpoint_dir=./checkpoints' '--dataset=c4' '--dataset_config_name=en' '--resume_from_checkpoint=./checkpoints' '--train_batch_size=1' '--val_batch_size=1' '--sharding_strategy=full' '--offload_activations=1')
...
0: 2025-04-04 19:56:52 I [train.py:156] Creating Model
0: 2025-04-04 19:57:57 I [train.py:172] Created model with total parameters: 6889410560 (6.89 B)
...
1: p5-dy-gpu-2:62571:62571 [1] NCCL INFO NCCL version 2.26.2+cuda12.2
1: p5-dy-gpu-2:62574:62574 [4] NCCL INFO cudaDriverVersion 12040
2: p5-dy-gpu-3:60823:61204 [2] NCCL INFO NET/OFI Initializing aws-ofi-nccl 1.14.0
2: p5-dy-gpu-3:60823:61204 [2] NCCL INFO NET/OFI Using Libfabric version 1.22
...
0: 2025-04-04 19:58:26 I [train.py:103] Batch 0 Loss: 11.63327, Speed: 2.80 samples/sec, lr: 0.000006
0: 2025-04-04 19:58:28 I [train.py:103] Batch 1 Loss: 11.64674, Speed: 17.06 samples/sec, lr: 0.000013
0: 2025-04-04 19:58:30 I [train.py:103] Batch 2 Loss: 11.56934, Speed: 17.61 samples/sec, lr: 0.000019
0: 2025-04-04 19:58:32 I [train.py:103] Batch 3 Loss: 11.30075, Speed: 17.66 samples/sec, lr: 0.000025
0: 2025-04-04 19:58:33 I [train.py:103] Batch 4 Loss: 11.00539, Speed: 17.66 samples/sec, lr: 0.000031
0: 2025-04-04 19:58:35 I [train.py:103] Batch 5 Loss: 10.39471, Speed: 17.28 samples/sec, lr: 0.000038
```

To modify training for different model sizes, change the corresponding parameters based on the values in the [Llama 2](https://arxiv.org/abs/2307.09288) and [Llama 3](https://arxiv.org/abs/2407.21783) papers:

| Parameter | Llama 2 7B | Llama 2 13B | Llama 2 70B | Llama 3.1 8B | Llama 3.1 70B | Llama 3.2 1B | Llama 3.2 3B |
|-----------|------------|-------------|-------------|--------------|---------------|--------------|--------------|
| **intermediate_size** | 11008 | 13824 | 28672 | 14336 | 28672 | 8192 | 11008 |
| **num_key_value_heads** | 32 | 40 | 8 | 8 | 8 | 8 | 8 |
| **hidden_width** | 4096 | 5120 | 8192 | 4096 | 8192 | 2048 | 3072 |
| **num_layers** | 32 | 40 | 80 | 32 | 80 | 16 | 28 |
| **num_heads** | 32 | 40 | 64 | 32 | 64 | 32 | 24 |
| **max_context_length** | 4096 | 4096 | 4096 | 8192 | 8192 | 8192 | 8192 |

If you need to cancel or modify your job, see the Slurm commands available in the [Slurm documentation](https://slurm.schedmd.com/quickstart.html).
