---
title: Preempt Low Priority Task
sidebar_position: 4
---

# Preempt Low Priority Task

## 🎬 The Scenario

> **Prof. Natarajan (Team B)**: "Emergency! We just got live data from the lab. We need to run a high-priority analysis RIGHT NOW."
>
> **You**: "You only have 1 guaranteed instance and it's running your lower-priority job. But watch this — task governance can preempt your own lower-priority tasks to make room for high-priority ones."

## 🎯 What's Happening

| | Current | New Request |
|---|---|---|
| Priority Class | training (weight: 70) | inference (weight: 90) |
| Instances needed | 1 | 2 |

Task governance will:
1. Detect the new job has higher priority (inference 90 > training 70)
2. Suspend Team B's lower-priority job
3. Allocate instances to the high-priority job
4. Start immediately

## Step 1: Prepare the High-Priority Job

```bash
sed -i \
  -e 's/name: etcd-gpu$/name: etcd-gpu-high-priority/' \
  -e 's/name: imagenet-gpu-team-b-2$/name: imagenet-gpu-team-b-2-high-priority/' \
  -e 's/rdzvHost: etcd-gpu$/rdzvHost: etcd-gpu-high-priority/' \
  3-imagenet-gpu-team-b-higher-prio.yaml

sed -i "s/ml.g5.8xlarge/${INSTANCE_TYPE}/g" 3-imagenet-gpu-team-b-higher-prio.yaml
```

## Step 2: Monitor and Submit

**Terminal 1** — Watch Team B's pods:
```bash
watch kubectl get pods -n hyperpod-ns-team-b
```

**Terminal 2** — Submit high-priority job:
```bash
kubectl apply -f 3-imagenet-gpu-team-b-higher-prio.yaml --namespace hyperpod-ns-team-b
```

## Step 3: Watch the Preemption ⚡

Within seconds, the lower-priority job disappears and the high-priority job starts.

✅ High-priority job is now running!

## Inspect Workloads

```bash
kubectl get workloads -n hyperpod-ns-team-b
```

## Clean Up

```bash
kubectl delete pytorchjob imagenet-gpu-team-b-2-high-priority -n hyperpod-ns-team-b
kubectl delete pytorchjob imagenet-gpu-team-b-1 -n hyperpod-ns-team-b
kubectl delete pytorchjob imagenet-gpu-team-a-1 -n hyperpod-ns-team-a
```
