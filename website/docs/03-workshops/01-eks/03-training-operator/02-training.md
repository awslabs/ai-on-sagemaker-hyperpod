---
title: Training
sidebar_position: 2
---

# 🚀 Launch Training

> **Objective**: Submit a distributed training job to train ESM2 across 2 GPU nodes.

**What's happening**: You'll create a `HyperPodPyTorchJob` that:
- Distributes training across 2x ml.g5.2xlarge instances
- Uses FSDP (Fully Sharded Data Parallel) for efficient training
- Monitors for hangs and failures
- Saves checkpoints to FSx every 50 steps
- Automatically recovers from failures

**Time to complete**: ~15 minutes (but you can move on while it trains!)

## Data

The UniRef50 dataset is pre-downloaded into your FSx Lustre file system at the `TARGET_PATH` directory (`/fsx/esm`).

## 1. Create HyperPodPyTorchJob YAML

```bash
cat << 'EOF' > train.yaml
apiVersion: sagemaker.amazonaws.com/v1
kind: HyperPodPyTorchJob
metadata:
  name: hpto-job
spec:
  nprocPerNode: "$GPU_PER_NODE"
  runPolicy:
    jobMaxRetryCount: 10
    restartPolicy:
      numRestartBeforeFullJobRestart: 3
      evalPeriodSeconds: 21600
      maxFullJobRestarts: 1
    cleanPodPolicy: All
    logMonitoringConfiguration:
      - name: JobStart
        logPattern: ".*'loss':.*"
        expectedStartCutOffInSeconds: 240
      - name: JobHangingDetection
        logPattern: ".*'loss':.*"
        expectedRecurringFrequencyInSeconds: 600
EOF
```

## 2. Understanding the Configuration

The YAML implements robust error handling:
- **JobStart**: Fails if no loss appears in logs within first 4 minutes (240s)
- **JobHangingDetection**: Fails if gap between loss logs exceeds 10 minutes (600s)
- **runPolicy**: 3 process restarts before full job restart, max 10 total retries

## 3. Run Training Job

```bash
envsubst < train.yaml | kubectl apply -f -
```

Monitor pods:

```bash
watch kubectl get pods
```

View logs:

```bash
kubetail hpto
```

## ✅ Success!

You've successfully:
- ✅ Submitted a distributed training job
- ✅ Trained ESM2 across 2 GPU nodes
- ✅ Saved checkpoints to FSx
- ✅ Monitored training with kubectl and kubetail

:::tip
You do not have to wait for the job to finish — please move on to the next section!
:::
