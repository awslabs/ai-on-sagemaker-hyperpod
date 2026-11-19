---
title: Cluster Setup Overview
sidebar_position: 0
---

# Cluster Setup

:::tip Reference Documentation
For production cluster architecture guidance, see the [Slurm Orchestration](/docs/slurm-orchestration/getting-started/) reference documentation.
:::

In the following section we'll set up a cluster with the following components:

- **Login node**: A dedicated instance with 500 GB of EBS space available. The login node allows users to set up their training and interact with the cluster without accessing the head node.
- **Head node (controller machine)**: Runs the Slurm scheduler process (`slurmctld`) and contains the cluster configuration file.
- **Compute nodes**: These are your accelerated (GPU) instances, such as the `ml.g5.8xlarge`.
- **Shared filesystems**: The cluster has an FSx for Lustre filesystem mounted at `/fsx` on both the head and compute nodes for datasets and checkpoints. An FSx for OpenZFS filesystem is also mounted as the default user home directories.
- **Placement group**: A placement group will spin up instances close together inside one physical data center in a single Availability Zone to maximize bandwidth and reduce latency between instances.
- **Local storage**: Each node will have a local NVMe volume attached for local storage, with the size depending on the instance type.
- **Scheduler**: Slurm will be used as the job scheduler.
- **Accounting**: As part of cluster configuration, a local MariaDB is deployed. This keeps track of job runtime information.
