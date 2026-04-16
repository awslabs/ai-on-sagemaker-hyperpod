---
title: Fair-share, QoS, Priority & Preemption (Optional)
sidebar_position: 3
---

# Fair-share, QoS, Priority & Preemption

:::info Optional
This page is optional. Follow this page to setup Fair-share, QoS, Priority and Preemption on your cluster.
:::

With accounts hierarchy and organisation structure created, resource governance shifts from physical boundaries to policy-based controls: Fair-share, Quality of Service (QoS), multi-factor priority, account-based limits, and preemption.
We will now setup these policies.

## Configure Fair-Share

Fair-share controls scheduling priority between teams when the cluster is contended. Set weights to reflect each team's allocation:

```bash
# Major GPU consumers get higher shares
sacctmgr -i modify account team-a set FairShare=40
sacctmgr -i modify account team-b set FairShare=40

# Smaller consumers
sacctmgr -i modify account team-c set FairShare=10
sacctmgr -i modify account platform set FairShare=10

# Verify
sacctmgr show assoc format=Account,FairShare tree
```

:::tip Fair-Share Behavior
Higher share values don't guarantee more resources — they influence scheduling priority when the cluster is contended. A team that's used less than its fair share gets boosted; one that's overused gets deprioritized.
:::

## QoS (Quality of Service)

QoS defines service tiers controlling priority, resource limits, and preemption rights.

### QoS Levels

| QoS | Priority | Max GPUs | Max Time | Can Preempt | Use Case |
|-----|----------|----------|----------|-------------|----------|
| `urgent` | 100 | 64 | 14 days | high, normal, low, debug | Critical deadlines |
| `high` | 75 | 48 | 7 days | normal, low, debug | Large model training |
| `normal` | 50 | 32 | 3 days | low, debug | Regular training |
| `low` | 25 | 16 | 1 day | debug | Experiments |
| `debug` | 10 | 4 | 4 hours | none | Quick testing |

### Create QoS Levels

Create `/fsx/ubuntu/slurmAccounting/scripts/setup_qos.sh`:

```bash
#!/bin/bash
set -e

sacctmgr -i add qos urgent Priority=100 MaxTRES=gres/gpu=64 \
    MaxTRESPerUser=gres/gpu=64 MaxWall=14-00:00:00 Preempt=high,normal,low,debug

sacctmgr -i add qos high Priority=75 MaxTRES=gres/gpu=48 \
    MaxTRESPerUser=gres/gpu=48 MaxWall=7-00:00:00 Preempt=normal,low,debug

sacctmgr -i add qos normal Priority=50 MaxTRES=gres/gpu=32 \
    MaxTRESPerUser=gres/gpu=32 MaxWall=3-00:00:00 Preempt=low,debug Flags=DenyOnLimit

sacctmgr -i add qos low Priority=25 MaxTRES=gres/gpu=16 \
    MaxTRESPerUser=gres/gpu=16 MaxWall=1-00:00:00 Preempt=debug

sacctmgr -i add qos debug Priority=10 MaxTRES=gres/gpu=4 \
    MaxTRESPerUser=gres/gpu=4 MaxWall=4:00:00 Preempt=

sacctmgr show qos format=Name,Priority,MaxTRES,MaxWall,Preempt
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/setup_qos.sh
/fsx/ubuntu/slurmAccounting/scripts/setup_qos.sh
```

### Modify QoS

```bash
sacctmgr -i modify qos normal set Priority=60
sacctmgr -i modify qos high set MaxTRES=gres/gpu=64
sacctmgr -i modify qos normal set MaxWall=5-00:00:00
sacctmgr -i delete qos debug
```

:::tip Enforce QoS (If you only plan to use QoS without limits)
To enforce users to specify `--qos` when submitting jobs, add/update this to `/opt/slurm/etc/slurm.conf`:
```ini
AccountingStorageEnforce=associations,qos
```
Then run `scontrol reconfigure`
:::

---

## Multi-Factor Priority

Priority determines job scheduling order. Slurm combines multiple factors:

| Factor | Weight | Effect |
|--------|--------|--------|
| Fair-share | 5000 | Teams using less than their share get boosted |
| QoS | 2500 | Higher QoS = higher priority |
| Age | 1000 | Longer-waiting jobs get gradual boost |
| Partition | 1000 | Different priorities per partition |
| Job Size | 500 | Can favor small or large jobs |

### Check Existing Configuration

Before making changes, verify what's already configured. HyperPod Slurm config may already include `priority/multifactor` as the default:

```bash
scontrol show config | grep PriorityType
```

:::tip
If the output shows `PriorityType = priority/multifactor`, the priority type is already set. You only need to add the **weight and decay** tuning parameters below. If it shows `priority/basic`, add the full configuration including `PriorityType`.
:::

### Configuration

Add to `/opt/slurm/etc/slurm.conf`:

```ini
PriorityType=priority/multifactor
PriorityDecayHalfLife=7-0
PriorityCalcPeriod=5
PriorityMaxAge=7-0
PriorityUsageResetPeriod=MONTHLY
PriorityWeightAge=1000
PriorityWeightFairshare=5000
PriorityWeightJobSize=500
PriorityWeightPartition=1000
PriorityWeightQOS=2500
PriorityFavorSmall=NO
```

```bash
sudo scontrol reconfigure
scontrol show config | grep -i priority
```

### View Priorities

```bash
sprio -l                          # All pending jobs with priority breakdown
sprio -j <jobid> -l              # Specific job
squeue --sort=-p -t pending      # Pending jobs sorted by priority
```

---

## Account-Based Resource Limits

Limits cap simultaneous resource usage per team.

### Configure Limits

Create `/fsx/ubuntu/slurmAccounting/scripts/setup_account_limits.sh`:

```bash
#!/bin/bash
set -e

# Team A: 48 GPUs, all QoS
sacctmgr -i modify account team-a set \
    GrpTRES=gres/gpu=48 QOS=urgent,high,normal,low,debug DefaultQOS=normal
sacctmgr -i modify account team-a-research set GrpTRES=gres/gpu=24
sacctmgr -i modify account team-a-training set GrpTRES=gres/gpu=24
sacctmgr -i modify account team-a-evaluation set GrpTRES=gres/gpu=16

# Team B: 48 GPUs, all QoS
sacctmgr -i modify account team-b set \
    GrpTRES=gres/gpu=48 QOS=urgent,high,normal,low,debug DefaultQOS=normal
sacctmgr -i modify account team-b-pretraining set GrpTRES=gres/gpu=32
sacctmgr -i modify account team-b-posttraining set GrpTRES=gres/gpu=24

# Team C: 24 GPUs, no urgent
sacctmgr -i modify account team-c set \
    GrpTRES=gres/gpu=24 QOS=high,normal,low,debug DefaultQOS=normal

# Platform: 16 GPUs, limited QoS
sacctmgr -i modify account platform set \
    GrpTRES=gres/gpu=16 QOS=normal,low,debug DefaultQOS=normal

sacctmgr show assoc format=Account,GrpTRES,QOS,DefaultQOS tree
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/setup_account_limits.sh
/fsx/ubuntu/slurmAccounting/scripts/setup_account_limits.sh
```

### Modify Limits

```bash
sacctmgr -i modify account team-a set GrpTRES=gres/gpu=64
sacctmgr -i modify account team-c set QOS+=urgent
sacctmgr -i modify account team-a set MaxJobs=10
sacctmgr -i modify account team-a set GrpTRES= MaxJobs=   # Remove limits
```

:::tip Enforce Resource Limits along with QoS
To enforce resource limits when submitting jobs, add/update this to `/opt/slurm/etc/slurm.conf`:
```ini
AccountingStorageEnforce=associations,qos,limits
```
Then run `scontrol reconfigure`
:::

---

## Preemption

Preemption allows high-priority jobs to interrupt lower-priority ones to obtain resources.

### Configuration

Add to `/opt/slurm/etc/slurm.conf`:

```ini
PreemptType=preempt/qos
PreemptMode=REQUEUE
PreemptExemptTime=00:30:00
```

```bash
sudo scontrol reconfigure
```

### Preemption Modes

| Mode | Behavior |
|------|----------|
| `REQUEUE` | Jobs return to queue (recommended for checkpointed training) |
| `CANCEL` | Jobs are terminated |
| `SUSPEND` | Jobs are paused (not recommended for GPUs) |

### Modify Preemption

```bash
# Disable preemption
sudo sed -i 's/PreemptType=.*/PreemptType=preempt\/none/' /opt/slurm/etc/slurm.conf
sudo scontrol reconfigure

# Increase protection time
sudo sed -i 's/PreemptExemptTime=.*/PreemptExemptTime=02:00:00/' /opt/slurm/etc/slurm.conf
sudo scontrol reconfigure

# Check if a job was preempted
sacct -j <jobid> --format=JobID,State,ExitCode
```

---

## Job Submission with QoS

```bash
# Default QoS (normal)
sbatch --account=team-b-pretraining --comment="project-id:llm-v2.1" --gres=gpu:8 train.sh

# High priority
sbatch --account=team-b-pretraining --qos=high --comment="project-id:llm-v2.1" --gres=gpu:16 train.sh

# Urgent (for critical deadlines)
sbatch --account=team-a-research --qos=urgent --comment="project-id:speech-prod" --gres=gpu:32 train.sh

# Debug (quick test)
sbatch --account=team-a-evaluation --qos=debug --gres=gpu:2 --time=1:00:00 test.sh
```

:::info Using the Wrapper
The [submission wrapper](./05-job-tagging.md) supports QoS via the `-q` flag:
```bash
submit_job -a team-b-pretraining -p llm-v2.1 -q high --gres=gpu:8 train.sh
```
:::
