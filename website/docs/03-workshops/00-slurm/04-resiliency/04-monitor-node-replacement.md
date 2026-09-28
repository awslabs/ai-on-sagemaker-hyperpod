---
title: Monitor Node Replacement
sidebar_position: 4
---

# Monitor Node Replacement

To see the node replacement in action, tail the `slurmctld.log` file:

```bash
tail -f /var/log/slurm/slurmctld.log
```

You'll see entries like:

```
[2025-04-08T21:44:43.476] _slurm_rpc_submit_batch_job: JobId=25 InitPrio=1 usec=1294
[2025-04-08T21:44:44.001] sched: Allocate JobId=25 NodeList=ip-10-1-39-175,ip-10-1-82-13 #CPUs=32 Partition=dev
[2025-04-08T21:49:34.679] update_node: node ip-10-1-82-13 reason set to: Action:Replace
[2025-04-08T21:49:34.679] update_node: node ip-10-1-82-13 state set to FAILING
[2025-04-08T21:49:34.689] sched: _update_job: setting nodes to ip-10-1-39-175 for JobId=25
```

You can also navigate to the [SageMaker HyperPod Console](https://console.aws.amazon.com/sagemaker/home?/cluster-management#cluster-management) to check the status of the new node being added to your cluster.

Once the new node is added and becomes available, you can resubmit the training job which will automatically resume from the last checkpoint:

```bash
sbatch train.sbatch
```
