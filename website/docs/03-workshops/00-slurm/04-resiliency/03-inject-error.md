---
title: Inject an Error
sidebar_position: 3
---

# Inject an Error

## Submit the Training Job

Start by submitting the training job on a fresh run:

```bash
sbatch train.sbatch
```

Tail the logs for the job:

```bash
tail -f logs/picotron_$(squeue -h -u $USER -o "%i" | head -1).out
```

Allow a few training steps to complete so that we have a corresponding checkpoint.

## Inject the Error

1. Run `squeue` to see which host your job is running on:

```bash
squeue
```

2. SSH into one of the hosts that's **not** the first node in the list:

```bash
ssh ip-10-1-0-16
```

3. Inject an [ECC Error](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/dcgm-error-injection.html#ecc-errors):

```bash
dcgmi test --inject --gpuid 0 -f 319 -v 4
```

4. Kill the training process to simulate a job failure:

```bash
kill -9 $(ps -aux | grep "python3 -u /picotron/train.py" | grep -v grep | awk '{print $2}')
```

## Resume from Checkpoint

Now that a node failure has been triggered, find the latest saved checkpoint and update the `load_path`:

```bash
previous_checkpoint=$(ls -1 checkpoints/ | sort -n | tail -n 2 | head -n 1)
jq --arg path "$previous_checkpoint" \
  '.checkpoint.load_path = .checkpoint.save_dir + "/" + $path' \
  conf/llama-1B-tp2/config.json > tmp.json && mv tmp.json conf/llama-1B-tp2/config.json
```

Verify the updates:

```bash
cat conf/llama-1B-tp2/config.json
```
