---
title: Enable Checkpoints for Picotron
sidebar_position: 2
---

# Enable Checkpoints for Picotron

Picotron uses the [create_config.py](https://github.com/huggingface/picotron/blob/main/create_config.py) script to generate a configuration file for distributed training of language models. It takes various command-line arguments to specify parallelization strategies (tensor, pipeline, data, and context parallelism), model parameters (like number of attention heads, hidden layers), and training settings (batch sizes, sequence length, etc.). The script reads from a base configuration template ([base_config.json](https://github.com/huggingface/picotron/blob/main/template/base_config.json)), modifies it according to the provided arguments, and saves a new `config.json` file in a specified output directory.

Checkpointing in Picotron is configured through the `checkpoint` section in the `config.json` file:

```json
{
  "checkpoint": {
    "save_dir": "<your_run_path>",
    "save_frequency": 10,
    "load_path": ""
  }
}
```

| Field | Description |
|---|---|
| `save_dir` | Where checkpoints will be saved |
| `save_frequency` | How often to save checkpoints |
| `load_path` | Path to load checkpoint from (empty for fresh start) |

The checkpoints will be saved in numbered subdirectories under the `save_dir` path (e.g., `1`, `2`, etc.). For auto-resume functionality with SLURM, you'll want to update the `load_path` to point to the latest checkpoint after it's created.

## Setup Checkpointing

Make sure you SSH into the head node of the cluster by following the steps in [SSH into Cluster](../02-cluster-setup/03-ssh-into-cluster.md), then:

1. Navigate to the picotron directory and create a checkpoints directory:

```bash
cd ~/awsome-distributed-ai/examples/training/picotron/SmolLM-1.7B/slurm
mkdir -p checkpoints
```

2. Modify the ownership of the config directory:

```bash
sudo chown -R ubuntu:ubuntu conf/llama-1B-tp2/
```

3. Using `jq`, modify the checkpoint configuration:

```bash
jq --arg pwd "${PWD}" \
  '.checkpoint.save_dir = $pwd + "/checkpoints" | .checkpoint.load_path = "" | .checkpoint.save_frequency = 100' \
  conf/llama-1B-tp2/config.json > tmp.json && mv tmp.json conf/llama-1B-tp2/config.json
```

4. Verify the updates:

```bash
cat conf/llama-1B-tp2/config.json
```

:::note Why `load_path` starts empty
Notice that we initially leave the `load_path` empty. This is by design based on how the initialization and checkpoint loading logic works in [train.py](https://github.com/huggingface/picotron/blob/main/train.py). On a fresh run, you want the model to initialize fresh weights using `model._init_weights`. If `load_path` is not empty, it will try to load a checkpoint from that path, which doesn't exist yet on a fresh run.

After the first checkpoint is saved, you can update `load_path` to point to the checkpoint directory for auto-resume functionality.
:::
