---
title: Borrow Idle Compute
sidebar_position: 2
---

# Borrow Idle Compute

## 🎯 What's Happening

| | Value |
|---|---|
| Team A's request | 2x ml.g5.2xlarge instances |
| Team A's guarantee | 1 instance |
| Team B's status | Idle (not using their 1 guaranteed instance) |

Task governance will automatically:
1. Allocate Team A's 1 guaranteed instance
2. Detect Team B's instance is idle
3. Lend Team B's instance to Team A
4. Start Team A's job on 2 instances

**All automatic. No manual intervention needed!**

## Step 1: Prepare Team A's Training Job

```bash
sed -i \
  -e '/pytorchReplicaSpecs:/,/replicas:/{s/replicas: 3/replicas: 2/}' \
  -e 's/--nnodes=3/--nnodes=2/' \
  1-imagenet-gpu-team-a.yaml

sed -i "s/ml.g5.8xlarge/${INSTANCE_TYPE}/g" 1-imagenet-gpu-team-a.yaml
```

## Step 2: Submit Team A's Job

```bash
kubectl apply -f 1-imagenet-gpu-team-a.yaml --namespace hyperpod-ns-team-a
```

Verify (container image pull takes ~4 minutes):

```bash
kubectl get pods -n hyperpod-ns-team-a
```

## Step 3: Verify in Console

You should see:
- **Job**: imagenet-gpu-team-a-1
- **Team**: team-a
- **Instances**: 2 (1 guaranteed + 1 borrowed from Team B)
- **Status**: Running

## ✅ Success: Borrowing Works!

- ✅ Team A requested 2 instances (only has 1 guaranteed)
- ✅ Task governance detected Team B's idle instance
- ✅ Automatically lent Team B's instance to Team A
- ✅ Zero manual intervention required
