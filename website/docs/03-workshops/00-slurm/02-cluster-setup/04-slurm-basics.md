---
title: Get to Know Your Cluster
sidebar_position: 4
---

# Get to Know Your Cluster

:::tip Reference Documentation
For comprehensive Slurm command reference and cluster management, see [Slurm Basics](/docs/slurm-orchestration/getting-started/slurm-basics).
:::

Now that you've created and set up the cluster, let's go through some of the commands you'll use.

## SLURM

[SLURM](https://slurm.schedmd.com) from SchedMD is one of the batch schedulers that you can use in SageMaker HyperPod. For an overview of the SLURM commands, see the [SLURM Quick Start User Guide](https://slurm.schedmd.com/quickstart.html).

### Check Cluster Status

Running `sinfo` shows the partition we created:

```bash
sinfo
```

| State | Description |
|---|---|
| idle | Instance is not running any jobs but is available |
| mix | Instance is partially allocated |
| alloc | Instance is completely allocated |

### Check Job Queue

```bash
squeue
```

## Shared Filesystems

A few volumes are shared by the head-node and will be mounted on compute instances when they boot up. You can see network mount filesystems such as the `/fsx` FSx Lustre filesystem:

```bash
df -h
```

## SSH to Compute Nodes

Let's SSH to the compute nodes for interactive testing:

1. Make sure you're logged in as `ubuntu`:

```bash
whoami  # should show ubuntu
```

2. Allocate an interactive node and SSH in:

```bash
salloc -N 1
ssh $(srun hostname)
```

When done, exit back to the Head Node:

```bash
exit  # exit the SSH session
exit  # cancel the srun job
```

:::tip Pro-tip
Update your bash prompt to show if you're on a CONTROLLER or WORKER node:

```bash
echo -e "\n# Show (CONTROLLER) or (WORKER) on the CLI prompt" >> ~/.bashrc
echo 'head_node_ip=$(sudo cat /opt/ml/config/resource_config.json | jq '"'"'.InstanceGroups[] | select(.Name == "controller-machine") | .Instances[0].CustomerIpAddress'"'"' | tr -d '"'"'"'"'"'"')' >> ~/.bashrc
echo 'if [ $(hostname -I | awk '"'"'{print $1}'"'"') = $head_node_ip ]; then PS1="(CONTROLLER) ${PS1}"; else PS1="(WORKER) ${PS1}"; fi' >> ~/.bashrc
source ~/.bashrc
```
:::
