---
title: Fully Sharded Data Parallel (FSDP2)
sidebar_position: 1
sidebar_title: Fully Sharded Data Parallel
---

# Get Started Training Llama 3.1 with PyTorch FSDP2 in 5 Minutes

This example showcases an easy way to get started with multi node [FSDP2](https://pytorch.org/tutorials/intermediate/FSDP_tutorial.html) training on Amazon SageMaker HyperPod with Slurm. FSDP2 is the next generation of PyTorch's Fully Sharded Data Parallel, offering improved memory management, DTensor integration, and a cleaner API.

## What's New in FSDP2

FSDP2 introduces several improvements over FSDP1:
- **DTensor representation**: Parameters are represented as DTensor with Shard(0) placement for easier manipulation
- **Better memory management**: Lower and deterministic GPU memory without `recordStream` and no CPU synchronization
- **Simplified API**: `fully_shard` function instead of `FullyShardedDataParallel` class wrapper
- **Improved checkpointing**: Communication-free sharded state dicts using DTensor APIs
- **Meta device initialization**: Cleaner initialization flow with explicit device placement 


## Prerequisites

Before running this training, you'll need to create a HyperPod cluster with an FSx for Lustre file system. Instructions can be found in [1. Cluster Setup](/docs/getting-started/orchestrated-by-slurm/initial-cluster-setup). Please follow them if you haven't done so already.

### Verified Instance Types

This example has been verified with:
- **ml.p5en.48xlarge x 2** - High-performance training setup
- **ml.p5.48xlarge x 4** - Large-scale training

You can adjust the model size to accommodate other instance types.

### Model Size Configurations

The following table shows the parameters for different Llama model sizes based on the [Llama 2](https://arxiv.org/abs/2307.09288) and [Llama 3](https://arxiv.org/abs/2407.21783) papers:

| Parameter | Llama 2 7B | Llama 2 13B | Llama 2 70B | Llama 3.1 8B | Llama 3.1 70B | Llama 3.2 1B | Llama 3.2 3B |
|-----------|------------|-------------|-------------|--------------|---------------|--------------|--------------|
| **intermediate_size** | 11008 | 13824 | 28672 | 14336 | 28672 | 8192 | 11008 |
| **num_key_value_heads** | 32 | 40 | 8 | 8 | 8 | 8 | 8 |
| **hidden_width** | 4096 | 5120 | 8192 | 4096 | 8192 | 2048 | 3072 |
| **num_layers** | 32 | 40 | 80 | 32 | 80 | 16 | 28 |
| **num_heads** | 32 | 40 | 64 | 32 | 64 | 32 | 24 |
| **max_context_length** | 4096 | 4096 | 4096 | 8192 | 8192 | 8192 | 8192 |

These configurations can be used to adjust the model parameters in your training scripts based on your compute requirements and available instance types.

## Setup

### Create Environment

On your cluster head node:

1. Navigate to your shared directory and clone the repository:

    ```bash
    cd /fsx  # or your shared filesystem mount point
    git clone https://github.com/aws-samples/awsome-distributed-training/
    cd awsome-distributed-training/3.test_cases/pytorch/FSDP/slurm
    ```

2. Run the `create_venv.sh` script:

    * This script will download and install [Miniconda](https://docs.conda.io/projects/miniconda/en/latest/), then create a Conda env called `pt_fsdp2`.
    * By creating this environment on the shared FSx for Lustre volume, all compute nodes in your cluster will have access to it.
    * The environment includes PyTorch 2.9.1+ which is required for FSDP2.

    ```bash
    . ./create_venv.sh
    ```

### Data

For this example, we'll be using the [allenai/c4](https://huggingface.co/datasets/allenai/c4) dataset. Instead of downloading the whole thing, the `create_streaming_dataloaders` function will stream the dataset from [HuggingFace](https://huggingface.co/datasets), so there's no data prep required for running this training.

If you'd like to instead use your own dataset, you can do so by [formatting it as a HuggingFace dataset](https://huggingface.co/docs/datasets/create_dataset), and passing its location to the `--dataset_path` argument.

### HuggingFace Token

**For this dataset, we will need a Hugging Face access token**. First, create a [Hugging Face account](https://huggingface.co/welcome). Then [generate your access token with read permissions](https://huggingface.co/docs/hub/en/security-tokens). Set your HuggingFace Token as an environment variable:

```bash
export HF_TOKEN=<YOUR HF ACCESS TOKEN>
```

## Training

### Launch Training

The script to launch a Slurm batch training job can be found in `llama3_1_8b-training.sbatch`. You can adjust the number of training nodes by modifying `#SBATCH --nodes=4`. You can also adjust the training parameters in `TRAINING_ARGS`. Additional parameters can be found in `model_utils/arguments.py`. 

Note that we use the same directory for both `--checkpoint_dir` and `--resume_from_checkpoint`. If there are multiple checkpoints, `--resume_from_checkpoint` will automatically select the most recent one. This way if our training is interrupted for any reason, it will automatically pick up the most recent checkpoint.

To launch your training, run:

```bash
sbatch llama3_1_8b-training.sbatch
```

### Monitor Training

You'll find a new file in the `logs` directory of the form `logs/llama3_1_8b-FSDP2_[JOB ID].out`. This will be continuously updated with your training logs. Don't be worried if you see a long stream of NCCL logs (we prefer to use `NCCL_DEBUG=INFO` for verbose logging). After about a minute, you should see your model training, with an output similar to below for Llama 3.1 8B:

```text
+ TORCHRUN_ARGS=('--nproc_per_node=8' '--nnodes=4' '--rdzv_id=2513' '--rdzv_backend=c10d' '--rdzv_endpoint=p5-dy-gpu-1')
+ TORCHRUN=torchrun
+ export TRAIN_SCRIPT=./train_fsdp2.py
+ TRAIN_SCRIPT=./train_fsdp2.py
+ TRAINING_ARGS=('--max_context_width=8192' '--num_key_value_heads=8' '--intermediate_size=14336' '--hidden_width=4096' '--num_layers=32' '--num_heads=32' '--model_type=llama_v3' '--tokenizer=hf-internal-testing/llama-tokenizer' '--checkpoint_freq=50' '--validation_freq=25' '--max_steps=50' '--checkpoint_dir=/fsx/checkpoints' '--dataset=allenai/c4' '--dataset_config_name=en' '--resume_from_checkpoint=/fsx/checkpoints' '--train_batch_size=1' '--val_batch_size=1' '--sharding_strategy=full' '--offload_activations=1')
...
0: 2025-02-07 19:22:36 I [train_fsdp2.py:102] Creating Model with FSDP2
0: 2025-02-07 19:22:38 I [train_fsdp2.py:102] Created model with total parameters: 8030261248 (8.03 B)
0: 2025-02-07 19:22:40 I [train_fsdp2.py:102] Wrapped model with FSDP2
0: 2025-02-07 19:22:42 I [train_fsdp2.py:102] Created optimizer
...
1: p5-dy-gpu-2:62571:62571 [1] NCCL INFO NCCL version 2.26.2+cuda12.2
1: p5-dy-gpu-2:62574:62574 [4] NCCL INFO cudaDriverVersion 12040
2: p5-dy-gpu-3:60823:61204 [2] NCCL INFO NET/OFI Initializing aws-ofi-nccl 1.14.0
2: p5-dy-gpu-3:60823:61204 [2] NCCL INFO NET/OFI Using Libfabric version 1.22
...
0: 2025-02-07 19:23:36 I [train_fsdp2.py:102] Batch 0 Loss: 11.63946, Speed: 9.27 samples/sec, lr: 0.000006
0: 2025-02-07 19:23:40 I [train_fsdp2.py:102] Batch 1 Loss: 11.66096, Speed: 9.39 samples/sec, lr: 0.000013
0: 2025-02-07 19:23:43 I [train_fsdp2.py:102] Batch 2 Loss: 11.56659, Speed: 9.40 samples/sec, lr: 0.000019
0: 2025-02-07 19:23:47 I [train_fsdp2.py:102] Batch 3 Loss: 11.14039, Speed: 9.40 samples/sec, lr: 0.000025
```


## Understanding FSDP2 Implementation

### Key Differences from FSDP1

The FSDP2 implementation uses several new patterns:

**1. Meta Device Initialization**
```python
# Initialize model on meta device (no memory allocation)
with torch.device("meta"):
    model = AutoModelForCausalLM.from_config(model_config)
```

**2. Layer-by-Layer Sharding**
```python
# Apply fully_shard to transformer layers first
for module in model.modules():
    if isinstance(module, transformer_layer):
        fully_shard(module, **fsdp_kwargs)

# Then apply to root model
fully_shard(model, **fsdp_kwargs)
```

**3. Explicit Device Placement**
```python
# Move from meta to CUDA and initialize parameters
model.to_empty(device=torch.device("cuda"))
model.reset_parameters()
```

**4. DTensor Parameters**
All model parameters are now DTensor with Shard(0) placement, enabling:
- Seamless optimizer integration
- Communication-free sharded checkpoints
- Easier parameter manipulation

### Performance Considerations

**Implicit Prefetching (Default)**
- Works out of the box
- CPU thread issues all-gather before each layer
- Good for non-CPU-bound workloads

**Explicit Prefetching (Advanced)**
For better performance, you can manually control prefetching:
```python
# Trigger first all-gather earlier
model.unshard()
x = torch.randint(0, vocab_size, (batch_size, seq_len), device=device)
loss = model(x).sum()
```

## Migration from FSDP1 to FSDP2

If you have existing FSDP1 training code, key changes include:
- Replace `FullyShardedDataParallel` with `fully_shard`
- Use meta device initialization
- Update to `MixedPrecisionPolicy` and `CPUOffloadPolicy`
- Migrate checkpointing to DTensor state dict APIs

For detailed migration instructions, refer to the [FSDP2 Migration Guide](https://github.com/aws-samples/awsome-distributed-training/blob/main/3.test_cases/pytorch/FSDP/slurm/FSDP2_MIGRATION_GUIDE.md).

## Additional Resources

- [PyTorch FSDP2 Tutorial](https://pytorch.org/tutorials/intermediate/FSDP_tutorial.html)
- [DTensor Documentation](https://pytorch.org/docs/stable/distributed.tensor.html)
- [AWS Distributed Training Examples](https://github.com/aws-samples/awsome-distributed-training)

If you need to cancel or modify your job, see the Slurm commands available in the [Slurm documentation](https://slurm.schedmd.com/quickstart.html).
