---
title: "Basic Slurm Commands"
sidebar_position: 5
weight: 4
---

Now that you've created and set up the cluster, you will go through some of the commands you'll use to run Llama7b on the cluster.

## SLURM

<p align="center">
  <img src="/img/01-cluster/slurm.png" alt="Cloud Shell" width="128" />
</p>

[SLURM](https://slurm.schedmd.com) from SchedMD is one of the batch schedulers that you can use in SageMaker HyperPod. For an overview of the SLURM commands, see the [SLURM Quick Start User Guide](https://slurm.schedmd.com/quickstart.html).

- **List existing partitions and nodes per partition**. Running `sinfo` shows the partition we created. Initially you will see the node in state `idle`, this means no jobs are running. When you submit a job, the instance will go into state `alloc` meaning it's currently completely allocated, or `mix` meaning some but not all cores are allocated.

| **State**   | **Description** |
| ----------- | ----------- |
| `idle`     | Instance is not running any jobs but is available.                       | 
| `mix`       | Instance is partially allocated.       |
| `alloc`     | Instance is completely allocated.        |

```bash
sinfo
```
- **List jobs in the queues or running**. Obviously, there won't be any since you did not submit anything...yet!

```bash
squeue
```

## Shared Filesystems

- **List mounted NFS volumes**. A few volumes are shared by the head-node and will be mounted on compute instances when they boot up.

You can see *network mount filesystems*, such as the */fsx* FSx Lustre filesystem that was mounted on the cluster by running `df -h`:

```bash
df -h
```

```
Filesystem                 Size  Used Avail Use% Mounted on
/dev/root                  146G   59G   87G  41% /
devtmpfs                   3.8G     0  3.8G   0% /dev
tmpfs                      3.8G     0  3.8G   0% /dev/shm
tmpfs                      765M  1.2M  763M   1% /run
tmpfs                      5.0M     0  5.0M   0% /run/lock
tmpfs                      3.8G     0  3.8G   0% /sys/fs/cgroup
/dev/loop0                  56M   56M     0 100% /snap/core18/2066
/dev/loop1                  56M   56M     0 100% /snap/core18/2796
/dev/loop4                  68M   68M     0 100% /snap/lxd/20326
/dev/loop5                  92M   92M     0 100% /snap/lxd/24061
/dev/loop3                  64M   64M     0 100% /snap/core20/2015
/dev/loop2                  41M   41M     0 100% /snap/snapd/20290
tmpfs                      765M   24K  765M   1% /run/user/128
/dev/nvme1n1               500G  711M  500G   1% /opt/sagemaker
10.1.71.197@tcp:/oyuutbev  1.2T  5.5G  1.2T   1% /fsx
tmpfs                      765M  4.0K  765M   1% /run/user/1000
```

## SSH to compute nodes

Now let's SSH to the compute nodes, this allows you to test code on GPU instances quickly without submitting a bash job.

1. First make sure you're logged into the cluster as `ubuntu`:

```bash
ssh ml-cluster
```

2. Now we can ssh into one of the compute nodes!

```bash
salloc -N 1
ssh $(srun hostname)
```

This allocates an interactive node with `salloc`, then uses `srun` to grab the hostname and ssh in.

Now that we're familiar with the cluster, we're ready to submit our first job. Before proceeding, make sure you exit to the Head Node:

```bash
exit
```

Run `exit` one more time to cancel the `srun` job:

```bash
exit
```

:::info Pro-tip
**Note: This is an optional step. If you're confused about which node you're on, this is a great way to check**
If you have a huge cluster it can be confusing to figure out which node you're on. To make it easier, you can update your bash prompt to reflect if you're on a CONTROLLER or WORKER node.

You can execute the following commands to set the type of the instance `CONTROLLER` or `WORKER` in the bash prompt:

```bash
echo -e "\n# Show (CONTROLLER) or (WORKER) on the CLI prompt" >> ~/.bashrc
echo 'head_node_ip=$(sudo cat /opt/ml/config/resource_config.json | jq '"'"'.InstanceGroups[] | select(.Name == "controller-machine") | .Instances[0].CustomerIpAddress'"'"' | tr -d '"'"'"'"'"')' >> ~/.bashrc
echo 'if [ $(hostname -I | awk '"'"'{print $1}'"'"') = $head_node_ip ]; then PS1="(CONTROLLER) ${PS1}"; else PS1="(WORKER) ${PS1}"; fi' >> ~/.bashrc
```

Next source ~/.bashrc:

```bash
source ~/.bashrc
```

Voila, you should now see `(CONTROLLER)` or `(WORKER)` on the cli prompt.
:::
