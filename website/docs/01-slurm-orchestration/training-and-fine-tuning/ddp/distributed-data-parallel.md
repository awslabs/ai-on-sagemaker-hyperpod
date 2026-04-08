---
tile: PyTorch DDP on CPU
sidebar_position: 1
sidebar_title : PyTorch DDP on CPU
---

# PyTorch DDP on CPU

This example showcases CPU [PyTorch DDP](https://pytorch.org/tutorials/beginner/ddp_series_theory.html) environment setup utilizing two different approaches for managing the software environment, Anaconda and Docker:

* [Anaconda](https://www.anaconda.com/) leverages conda environments to create distinct spaces for projects, allowing different Python versions and libraries to coexist without conflicts by isolating updates to their respective environments. 
* [Docker](https://www.docker.com/), a containerization platform, packages applications and their dependencies into containers, ensuring they run seamlessly across any Linux server by providing OS-level virtualization and encapsulating the entire runtime environment.

## Preparation

This guide assumes that you have the following:

* A HyperPod Slurm cluster
* An FSx for Lustre filesystem mounted on `/fsx`.
* (optional) `enroot` if you want to run the container example.

If you don't already have a Slurm cluster, please follow the instructions in [**Cluster Setup**](/docs/slurm-orchestration/getting-started/initial-cluster-setup) to create one, then do the following:

1. First clone the repo in a shared directory such as the home directory:

```bash
git clone https://github.com/aws-samples/awsome-distributed-training.git
```

2. Change into the correct directory:

```bash
cd awsome-distributed-training/3.test_cases/pytorch/cpu-ddp/slurm
```

## Conda Environment

### Submit training job using conda environment

1. In this step, you will create PyTorch virtual environment using conda, this will prepare `miniconda3` and `pt_cpu` directory which includes `torchrun`:

```bash
bash 0.create-conda-env.sh
```

2. Submit DDP training job with:

```bash
sbatch 1.conda-train.sbatch
```

Output of the training job can be found in `logs` directory:

```bash
tail -f logs/cpu-ddp-conda_xxx.out
```

You'll see:

```
Node IP: 10.1.96.108
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] master_addr is only used for static rdzv_backend and when rdzv_endpoint is not specified.
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] 
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] *****************************************
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] Setting OMP_NUM_THREADS environment variable for each process to be 1 in default, to avoid your system being overloaded, please further tune the variable for optimal performance in your application as needed. 
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] *****************************************
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO] Starting elastic_operator with launch configs:
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   entrypoint       : ddp.py
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   min_nodes        : 2
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   max_nodes        : 2
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   nproc_per_node   : 4
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   run_id           : 5982
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   rdzv_backend     : c10d
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   rdzv_endpoint    : 10.1.96.108:29500
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   rdzv_configs     : {'timeout': 900}
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   max_restarts     : 0
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   monitor_interval : 5
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   log_dir          : None
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   metrics_cfg      : {}
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO] 
[2024-03-12 08:22:45,552] torch.distributed.elastic.agent.server.local_elastic_agent: [INFO] log directory set to: /tmp/torchelastic_9g50nxjq/5982_tflt1tcd
[2024-03-12 08:22:45,552] torch.distributed.elastic.agent.server.api: [INFO] [default] starting workers for entrypoint: python
...
[RANK 3] Epoch 49 | Batchsize: 32 | Steps: 8
[RANK 5] Epoch 49 | Batchsize: 32 | Steps: 8
[RANK 4] Epoch 49 | Batchsize: 32 | Steps: 8
[2024-03-12 08:22:56,574] torch.distributed.elastic.agent.server.api: [INFO] [default] worker group successfully finished. Waiting 300 seconds for other agents to finish.
[2024-03-12 08:22:56,574] torch.distributed.elastic.agent.server.api: [INFO] Local worker group finished (WorkerState.SUCCEEDED). Waiting 300 seconds for other agents to finish
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] [default] worker group successfully finished. Waiting 300 seconds for other agents to finish.
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] Local worker group finished (WorkerState.SUCCEEDED). Waiting 300 seconds for other agents to finish
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] Done waiting for other agents. Elapsed: 0.0010929107666015625 seconds
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] Done waiting for other agents. Elapsed: 0.0005395412445068359 seconds
```

## Docker
### Submit training job using docker container

In this example, you'll learn how to use the official PyTorch Docker image and execute the container within the Slurm scheduler using Enroot. 

[Enroot](https://github.com/NVIDIA/enroot) uses the same underlying technologies as containers but removes much of the isolation they inherently provide while preserving filesystem separation. This approach is generally preferred in high-performance environments or virtualized environments where portability and reproducibility is important, but extra isolation is not warranted.

1. Create Enroot container images:

```bash
bash 2.create-enroot-image.sh
```

This will pull `pytorch/pytorch` container, then create [squashfs](https://www.kernel.org/doc/Documentation/filesystems/squashfs.txt) image named `pytorch.sqsh`.

2. Submit DDP training job using the image with:

```bash
sbatch 3.container-train.sbatch
```

3. Output of the training job can be found in `logs` directory:

```bash
tail -f logs/cpu-ddp-container_*.out
```

You'll see:

```
Node IP: 10.1.96.108
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] master_addr is only used for static rdzv_backend and when rdzv_endpoint is not specified.
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] 
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] *****************************************
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] Setting OMP_NUM_THREADS environment variable for each process to be 1 in default, to avoid your system being overloaded, please further tune the variable for optimal performance in your application as needed. 
[2024-03-12 08:22:45,549] torch.distributed.run: [WARNING] *****************************************
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO] Starting elastic_operator with launch configs:
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   entrypoint       : ddp.py
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   min_nodes        : 2
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   max_nodes        : 2
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   nproc_per_node   : 4
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   run_id           : 5982
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   rdzv_backend     : c10d
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   rdzv_endpoint    : 10.1.96.108:29500
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   rdzv_configs     : {'timeout': 900}
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   max_restarts     : 0
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   monitor_interval : 5
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   log_dir          : None
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO]   metrics_cfg      : {}
[2024-03-12 08:22:45,549] torch.distributed.launcher.api: [INFO] 
[2024-03-12 08:22:45,552] torch.distributed.elastic.agent.server.local_elastic_agent: [INFO] log directory set to: /tmp/torchelastic_9g50nxjq/5982_tflt1tcd
[2024-03-12 08:22:45,552] torch.distributed.elastic.agent.server.api: [INFO] [default] starting workers for entrypoint: python
...
[RANK 3] Epoch 49 | Batchsize: 32 | Steps: 8
[RANK 5] Epoch 49 | Batchsize: 32 | Steps: 8
[RANK 4] Epoch 49 | Batchsize: 32 | Steps: 8
[2024-03-12 08:22:56,574] torch.distributed.elastic.agent.server.api: [INFO] [default] worker group successfully finished. Waiting 300 seconds for other agents to finish.
[2024-03-12 08:22:56,574] torch.distributed.elastic.agent.server.api: [INFO] Local worker group finished (WorkerState.SUCCEEDED). Waiting 300 seconds for other agents to finish
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] [default] worker group successfully finished. Waiting 300 seconds for other agents to finish.
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] Local worker group finished (WorkerState.SUCCEEDED). Waiting 300 seconds for other agents to finish
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] Done waiting for other agents. Elapsed: 0.0010929107666015625 seconds
[2024-03-12 08:22:56,575] torch.distributed.elastic.agent.server.api: [INFO] Done waiting for other agents. Elapsed: 0.0005395412445068359 seconds
```

## Monitor
Now that the job is running, we can monitor it in two ways, we can tail the log file to see how the training is progressing:

```bash
# Control-C to stop tailing
tail -f slurm-2.log
```

We can also ensure it's utilizing the CPU's appropriately by SSH-ing into the compute node. 

Grab the hostname by running `sinfo` and seeing which node it's running on:

```bash
sinfo
```

```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
dev*         up   infinite      1  alloc ip-10-1-90-87
```

Then ssh into that instance using the hostname from `sinfo`:

```bash
ssh ip-10-1-90-87
```

Once there we can monitor the cpu usage by running `htop`:

```bash
sudo apt-get install -y htop && htop
```
