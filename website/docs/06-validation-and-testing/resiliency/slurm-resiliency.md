---
title: "Testing Resiliency with HyperPod Slurm"
sidebar_position: 3
---

# Testing Resiliency with HyperPod Slurm

This guide demonstrates how to test and validate the resiliency features of SageMaker HyperPod when using Slurm as the orchestrator. You'll learn how to submit resilient training jobs, inject failures, monitor cluster recovery, and manually replace nodes.

## Test Case Overview

In this example, we'll:
1. Submit a training job using Megatron-LM with checkpointing enabled
2. Inject an XID Error to simulate hardware failure
3. Monitor the cluster's automatic recovery process
4. Observe job resumption from the last checkpoint

:::note Prerequisites
Before proceeding, ensure you've completed the [Megatron-LM](/docs/02-slurm-blueprints/training/megatron-lm/megatron-lm-readme.md) setup for your HyperPod Slurm cluster.
:::

## 1. Submit a Resilient Training Job

Megatron-LM supports checkpoint parameters that enable automatic job recovery:

| **Parameter** | **Value** | **Description** |
|---------------|-----------|-----------------|
| `--save` | /fsx/checkpoints | Output directory to save checkpoints |
| `--save-interval` | 1 | Number of iterations between checkpoint saves |
| `--load` | /fsx/checkpoints | Directory containing model checkpoint |

### Configure the Training Script

1. Let us go back to the megatron-lm example directory in the [awsome-distributed-training](https://github.com/aws-samples/awsome-distributed-training/tree/main/3.test_cases/megatron/megatron-lm/slurm/gpt3) repository to execute this. 

```bash
cd ~/awsome-distributed-training/3.test_cases/megatron/megatron-lm/slurm/gpt3
```

2. Modify your `2.distributed-training.sbatch` script to include auto-resume and checkpointing:

```bash
# Add auto-resume flag to srun
srun ${AUTO_RESUME} -l "${ARGS[@]}" bash -c '
export MASTER_ADDR=$SLURM_LAUNCH_NODE_IPADDR;
export MASTER_PORT=6000;
export WORLD_SIZE=$SLURM_NTASKS;
export RANK=$SLURM_PROCID;
export LOCAL_RANK=$SLURM_LOCALID;
$NSYS_PROFILING \
python3 -u /workspace/Megatron-LM/pretrain_gpt.py \
$NSYS_PROFILING_MEGATRON_ARGS \
--save /fsx/checkpoints \
--save-interval 1 \
--load /fsx/checkpoints \
--num-layers $NUM_LAYERS \
--hidden-size $HIDDEN_SIZE \
--num-attention-heads $NUM_ATTENTION_HEADS \
--seq-length $SEQ_LENGTH \
--max-position-embeddings $MAX_POSITION_EMBEDDINGS \
--micro-batch-size $MICRO_BATCH_SIZE \
--global-batch-size $GLOBAL_BATCH_SIZE \
--tensor-model-parallel-size $TENSOR_PARALLEL \
--pipeline-model-parallel-size $PIPELINE_PARALLEL \
--train-samples 146484375 \
--lr-decay-samples 126953125 \
--lr-warmup-samples 183105 \
--lr 6.0e-5 \
--min-lr 6.0e-6 \
--lr-decay-style cosine \
--log-interval 1 \
--eval-iters 40 \
--eval-interval 1000 \
--data-path ${DATA_PATH}/gpt2/my-gpt2_text_document \
--vocab-file ${DATA_PATH}/gpt2/gpt2-vocab.json \
--merge-file ${DATA_PATH}/gpt2/gpt2-merges.txt \
--split 98,2,0 \
--clip-grad 1.0 \
--weight-decay 0.1 \
--adam-beta1 0.9 \
--adam-beta2 0.95 \
--init-method-std 0.006 \
--fp16 \
--recompute-activations '
```

Key additions:
- `${AUTO_RESUME}` flag after srun enables automatic job resumption
- `--save /fsx/checkpoints` specifies checkpoint output directory
- `--save-interval 1` saves checkpoint after each iteration (use higher values for production)
- `--load /fsx/checkpoints` enables loading from last checkpoint

### Submit the Job

2. Submit the training job:

```bash
sbatch 2.distributed-training.sbatch
```

3. Monitor job progress by tailing the log file:

```bash
tail -f slurm-<job-id>.log
```

You should see output indicating successful checkpointing:

```
1: iteration        1/  508626 | consumed samples:          288 | elapsed time per iteration (ms): 440352.6 | learning rate: 0.000E+00 | global batch size:   288 | loss scale: 4294967296.0 | number of skipped iterations:   1 | number of nan iterations:   0 |
0: saving checkpoint at iteration       1 to /fsx/checkpoints
0:   successfully saved checkpoint at iteration       1 to /fsx/checkpoints
1: (min, max) time across ranks (ms):
1:     save-checkpoint ................................: (81611.24, 81611.82)
```

4. Verify checkpoint creation:

```bash
ls -lt /fsx/checkpoints/
```

Expected output:
```
total 74
-rw-rw-r--  1 ubuntu ubuntu     1 Dec  9 00:21 latest_checkpointed_iteration.txt
drwxrwxr-x 10 ubuntu ubuntu 33280 Dec  9 00:20 iter_0000002
drwxrwxr-x 10 ubuntu ubuntu 33280 Dec  9 00:11 iter_0000001
```

## 2. Inject Hardware Failure

Now we'll simulate a hardware failure to test the cluster's resiliency.

### Identify Target Node

1. Check which nodes your job is running on:

```bash
squeue
```

### Inject ECC Error

2. SSH into one of the worker nodes (not the first node):

```bash
ssh ip-10-1-0-16
```

3. Inject an [ECC Error](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/dcgm-error-injection.html#ecc-errors) using DCGM:

```bash
dcgmi test --inject --gpuid 0 -f 319 -v 4
```

### Simulate Process Failure

4. Kill the training process to simulate job failure:

```bash
# Find the Python training process
ps -aux | grep python

# Kill the process (replace <PID> with actual process ID)
kill -9 <PID>
```

## 3. Monitor Cluster Recovery

### Monitor Slurm Controller Logs

To observe the node replacement process, monitor the Slurm controller logs:

```bash
tail -f /var/log/slurm/slurmctld.log
```

You'll see entries indicating node failure and replacement:

```
[2024-03-06T16:26:50.915] SchedulerParameters=default_queue_depth=100,max_rpc_cnt=0,max_sched_time=2,partition_job_depth=0,sched_max_job_start=0,sched_min_interval=2
[2024-03-08T00:15:02.047] error: _find_node_record: lookup failure for node "ip-10-1-57-141"
[2024-03-08T00:15:02.047] error: update_node: node ip-10-1-57-141 does not exist
[2024-03-08T00:15:02.047] _slurm_rpc_update_node for ip-10-1-57-141: Invalid node name specified
[2024-03-08T00:15:18.986] update_node: node ip-10-1-73-87 reason set to: Action:Replace
[2024-03-08T00:15:18.986] update_node: node ip-10-1-73-87 state set to FAIL
```

### Check Node Status

Monitor node status changes:

```bash
sinfo
```

You'll see the node transition through different states:
- `failg` (failing while job is running)
- `fail` (failed after job termination)
- Eventually replaced with a new node

### Monitor Job Queue

Check job status:

```bash
squeue
```

The job should automatically resume once the replacement node is available and healthy.

## 4. Manual Node Replacement

You can also manually trigger node replacement when needed.

### Replace a Specific Node

To manually replace a node, use the `scontrol` command:

```bash
sudo scontrol update node=ip-10-1-57-141 state=down reason="Action:Replace"
```

:::note Note
Replace `ip-10-1-57-141` with the actual hostname of the node you want to replace.
:::

### Monitor Replacement Process

1. Check immediate node status change:

```bash
sinfo
```

The node will show as `failg` state:
```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
dev*         up   infinite      1  failg ip-10-1-57-141
dev*         up   infinite      1  alloc ip-10-1-69-138
```

2. While jobs are running, the node remains active:

```bash
squeue
```

```
JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
9       dev megatron   ubuntu  R      19:26      2 ip-10-1-57-141,ip-10-1-69-138
```

3. After job termination, the node enters `fail` state and gets terminated:

```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
dev*         up   infinite      1   fail ip-10-1-57-141
dev*         up   infinite      1   idle ip-10-1-69-138
```

### Monitor in SageMaker Console

You can monitor the replacement process in the [SageMaker Console](https://console.aws.amazon.com/sagemaker/home?/cluster-management) where you'll see the new node being provisioned.

### Post-Replacement Setup

When the replacement node is ready, you may need to remap the home directory:

```bash
# Remap home directory for the replaced node
srun -w ip-10-1-57-141 usermod -d /fsx/ubuntu ubuntu

# SSH into the new node
ssh ip-10-1-57-141
```

:::caution SSH Key Warning
You may encounter a host key verification error because the new node uses the same hostname. Remove the old key:

```bash
ssh-keygen -f "/fsx/ubuntu/.ssh/known_hosts" -R "ip-10-1-57-141"
```

Then SSH again to accept the new host key.
:::

## Best Practices

1. **Checkpoint Frequency**: Set appropriate `--save-interval` values based on your training duration and checkpoint overhead
2. **Shared Storage**: Ensure checkpoints are saved to shared storage (FSx) accessible by all nodes
3. **Job Monitoring**: Regularly monitor job logs and node status during long-running training jobs
4. **Resource Planning**: Account for temporary capacity reduction during node replacement
5. **Testing**: Regularly test resiliency features in non-production environments

<br/>

:::note Troubleshooting
<br/>

#### Job Not Resuming
- Verify checkpoint files exist in the specified directory
- Check Slurm logs for scheduling issues
- Ensure replacement nodes have proper access to shared storage

#### Node Replacement Delays
- Check AWS service limits and capacity availability
- Monitor CloudWatch logs for detailed error messages
- Verify IAM permissions for node replacement operations

#### Checkpoint Corruption
- Implement checkpoint validation in your training script
- Use multiple checkpoint directories for redundancy
- Monitor storage health and capacity
:::