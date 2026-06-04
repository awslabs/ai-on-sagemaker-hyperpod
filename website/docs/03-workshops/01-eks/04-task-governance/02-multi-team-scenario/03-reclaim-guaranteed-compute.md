---
title: Reclaim Guaranteed Compute
sidebar_position: 3
---

# Reclaim Guaranteed Compute

## 🎯 What's Happening

**Current state**: Team A is using 2 instances (1 guaranteed + 1 borrowed from Team B)

**Team B's request**: 1 instance (their guaranteed allocation)

Task governance will:
1. Detect Team B needs their guaranteed instance
2. Identify that Team A is borrowing it
3. Gracefully suspend Team A's job on the borrowed instance
4. Allocate Team B's guaranteed instance to Team B

## Step 1: Create Team B's Training Job

```bash
cp 1-imagenet-gpu-team-a.yaml 2-imagenet-gpu-team-b.yaml

sed -i \
  -e 's/team-a/team-b/g' \
  -e '/pytorchReplicaSpecs:/,/replicas:/{s/replicas: 2/replicas: 1/}' \
  -e 's/--nnodes=2/--nnodes=1/' \
  2-imagenet-gpu-team-b.yaml

sed -i "s/ml.g5.8xlarge/${INSTANCE_TYPE}/g" 2-imagenet-gpu-team-b.yaml
```

## Step 2: Open Two Terminals 🎮

**Terminal 1** — Monitor Team A's pods:
```bash
watch kubectl get pods -n hyperpod-ns-team-a
```

**Terminal 2** — Submit Team B's job:
```bash
kubectl apply -f 2-imagenet-gpu-team-b.yaml
```

## Step 3: Watch the Reclamation ⚡

Team A's job is suspended because it was using Team B's guaranteed instance.

✅ Team B is now running on their guaranteed instance!

## Console Verification

- **Team A**: Suspended (waiting for resources)
- **Team B**: Running (using their guaranteed instance)

> **Investor**: "So teams can borrow idle resources automatically, resources are reclaimed when needed, jobs are suspended gracefully, and everything resumes automatically?"
>
> **You**: "Exactly. Zero manual intervention. Zero lost work."
