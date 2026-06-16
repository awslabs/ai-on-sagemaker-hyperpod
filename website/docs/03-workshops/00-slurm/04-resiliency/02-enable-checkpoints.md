---
title: Enable Checkpoints for Picotron
sidebar_position: 2
---

# Enable Checkpoints for Picotron

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

The checkpoints will be saved in numbered subdirectories under the `save_dir` path.

## Setup Checkpointing

Make sure you SSH into the head node of the cluster, then:

1. Navigate to the picotron directory and create a checkpoints directory:

```bash
cd ~/awsome-distributed-training/3.test_cases/pytorch/picotron/SmolLM-1.7B/slurm
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

:::note
We initially leave the `load_path` empty. On a fresh run, you want the model to initialize fresh weights. After the first checkpoint is saved, you can update `load_path` to point to the checkpoint directory for auto-resume functionality.
:::
