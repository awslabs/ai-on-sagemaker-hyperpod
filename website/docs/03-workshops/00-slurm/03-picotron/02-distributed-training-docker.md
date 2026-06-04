---
title: Distributed Training with Docker
sidebar_position: 2
---

# Distributed Training with Docker

## 1. Clone the Repository

First, clone the repository into a shared directory on your cluster:

```bash
git clone https://github.com/aws-samples/awsome-distributed-training.git
```

## 2. Navigate to the Picotron Test Case Directory

```bash
cd awsome-distributed-training/3.test_cases/pytorch/picotron
```

## 3. Build the Docker Image 🐳

The provided `picotron.Dockerfile` contains all the necessary setup for the environment. Build the Docker image:

```bash
docker build -t picotron -f picotron.Dockerfile .
```

:::info
This step will take approximately **9 minutes**. ☕
:::

## 4. Change to the Picotron Slurm Directory

```bash
cd SmolLM-1.7B/slurm
```

## 5. Convert the Docker Image to a Squash File

We will use [Nvidia Enroot](https://github.com/NVIDIA/enroot) to convert the Docker image into a squash (.sqsh) file that allows Slurm to reference the Dockerfile across all cluster nodes:

```bash
enroot import -o picotron.sqsh dockerd://picotron:latest
```

:::info
This process takes approximately **2 minutes**. 🍪
:::

## 6. Create Configuration File

Create a configuration for TensorParallelism on 2 GPUs:

```bash
enroot create --name picotron picotron.sqsh
enroot start --mount ${PWD}:${PWD} \
  --env NVIDIA_VISIBLE_DEVICES=void picotron \
  python3 /picotron/create_config.py \
  --out_dir ${PWD}/conf --exp_name llama-1B-tp2 --dp 1 --tp 2 --pp 1 \
  --pp_engine 1f1b --model_name HuggingFaceTB/SmolLM-1.7B --num_hidden_layers 5 \
  --total_train_steps 5000 \
  --grad_acc_steps 2 --mbs 4 --seq_len 128 --hf_token ${HF_TOKEN}
enroot remove -f picotron
```

## 7. Submit the Training Job

```bash
sbatch train.sbatch
```

:::warning
If you get an error like `srun: unrecognized option '--container-image'`, run:

```bash
NUM_NODES=<number_of_compute_nodes>
srun -N $NUM_NODES sudo scontrol reconfigure
```
:::

## 8. Monitor Training Progress

Check the log directory for files of the form `picotron_[job-number].out`:

```bash
tail -f logs/picotron<job_id>.out
```

You should see training progress like:

```
0: [rank 0] Step: 1 | Loss: 10.9688 | Global batch size: 1.02K | Tokens/s: 217.87
0: [rank 0] Step: 2 | Loss: 9.0312 | Global batch size: 1.02K | Tokens/s: 6.73K
0: [rank 0] Step: 3 | Loss: 7.8594 | Global batch size: 1.02K | Tokens/s: 6.61K
```
