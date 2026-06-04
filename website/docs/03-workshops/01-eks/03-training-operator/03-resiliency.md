---
title: "Resiliency: Murphy's Law Strikes"
sidebar_position: 3
---

# Resiliency: Murphy's Law Strikes

> Or as our CTO Dr. Werner Vogels said: "Everything fails, all the time."

## 🎯 Mission: Demonstrate Fault Tolerance

> **Objective**: Intentionally fail a GPU node during training and watch HyperPod's surgical recovery in action.
>
> **Why this matters**: In production, hardware fails — a lot. HyperPod's resilience can save you days of training time and thousands of dollars.

The HyperPod Training Operator's **Process Level Restart** feature automatically restarts processes rather than the entire job.

## 🧪 The Experiment: Break Things on Purpose

:::tip Pro Tip
You'll want **TWO terminal windows** open for this demo:
- **Terminal 1**: Monitor training logs in real-time
- **Terminal 2**: Trigger the node failure and watch recovery
:::

### Terminal 1: Start Fresh Training

Delete old job and start new:

```bash
kubectl delete -f train.yaml
export OUTPUT_DIR=/fsx/esm/new-output
envsubst < train.yaml | kubectl apply -f -
kubetail hpto
```

Wait until it writes a checkpoint...

### Terminal 2: Inject Node Failure

Once you see a checkpoint, emulate an instance failure by marking a node unhealthy:

```bash
export NODE=$(kubectl get nodes -l node.kubernetes.io/instance-type=${INSTANCE_TYPE} | awk 'NR>1 {print $1}' | shuf -n 1)
kubectl label node $NODE \
  sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReboot \
  --overwrite=true
```

After about ~150 seconds, you'll see recovery:

```
Normal Running 3s hyperpod-pytorch-job-controller The fault of reason NodeFault was remediated in 148952 milliseconds.
```

## 📊 The Results

| Metric | Value |
|---|---|
| ⏱️ Detection time | ~5 seconds |
| 🔧 Recovery time | ~150 seconds |
| 📦 Checkpoint resume | Automatic (loaded from FSx) |
| 💰 Training time lost | ~3 minutes (vs. hours with full restart) |
| 🎯 Full job restarts | 0 (surgical recovery only) |

## runPolicy Reference

| Parameter | Description |
|---|---|
| `jobMaxRetryCount` | Maximum number of restarts at the process level |
| `numRestartBeforeFullJobRestart` | Process restarts before job-level restart |
| `evalPeriodSeconds` | Period of evaluating the restart limit (seconds) |
| `maxFullJobRestarts` | Maximum full job restarts before failure |
| `cleanPodPolicy` | Which pods the operator should clean |
| `logMonitoringConfiguration` | Rules for slow and hanging job detection |
