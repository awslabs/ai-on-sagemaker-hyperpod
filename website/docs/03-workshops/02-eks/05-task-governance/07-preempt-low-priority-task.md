---
title: Preempt Low Priority Task
sidebar_position: 7
---

# Preempt low priority task

Let's try one more scenario to reinforce this concept.

## 🎬 The scenario

> **Prof. Natarajan (Team B):** "Emergency! We just got live data from the lab. We need to run a high-priority analysis RIGHT NOW. Can we get 2 instances?"
>
> **You:** "You only have 1 guaranteed instance, and it's currently running your lower-priority job. But watch this — task governance can preempt your own lower-priority tasks to make room for high-priority ones."

## 🎯 What's happening

**Current state:**

- Team B has 1 job running with the lower-priority `training` class (weight 70)
- Team B needs to run an urgent job with the higher-priority `experimentation` class (weight 80)
- Team B only has 1 guaranteed instance

**Team B's request:** 2 instances for the higher-priority experimentation job.

Task governance will:

1. Detect that the new job has higher priority (weight 80 > weight 70)
2. Suspend Team B's lower-priority job
3. Allocate both instances to the high-priority job
4. Start the high-priority job immediately

**The result:** critical workloads get resources immediately by preempting lower-priority tasks within the same team.

:::note
The crawl dropped the priority class names from this section, leaving only the weights. The names above (`training`, weight 70, and `experimentation`, weight 80) are taken from the cluster policy created in [Configure policies](./04-configure-policies.md); confirm in the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/05-task-governance/02-example/04-preempt-tasks).
:::

## Step 1: Prepare the high-priority job

The example file needs some updates to avoid naming conflicts and to match your cluster's instance type:

```bash
# Update all resource names with high-priority suffix
sed -i \
  -e 's/name: etcd-gpu$/name: etcd-gpu-high-priority/' \
  -e 's/name: imagenet-gpu-team-b-2$/name: imagenet-gpu-team-b-2-high-priority/' \
  -e 's/rdzvHost: etcd-gpu$/rdzvHost: etcd-gpu-high-priority/' \
  3-imagenet-gpu-team-b-higher-prio.yaml

# Update instance type to match your cluster
sed -i "s/ml.g5.8xlarge/${INSTANCE_TYPE}/g" 3-imagenet-gpu-team-b-higher-prio.yaml
```

What this does:

- Adds a `-high-priority` suffix to resource names so they don't clash with Team B's existing lower-priority job
- Replaces the hardcoded `ml.g5.8xlarge` with your actual instance type (`ml.g7.2xlarge`)

## Step 2: If you haven't already, open two terminals for real-time monitoring 🎮

Open TWO terminal windows to watch the preemption:

1. Monitor Team B's pods (watch the lower-priority job get preempted)
2. Submit the high-priority job and watch it take over

Mission control mode activated! 🚀

### Terminal 1: monitor Team B's pods

Watch Team B's current pods:

```bash
watch kubectl get pods -n hyperpod-ns-team-b
```

You should currently see the lower-priority job running:

```text
NAME                             READY   STATUS    RESTARTS   AGE
etcd-gpu-6fcb4f6f7d-sspgh        1/1     Running   0          8m47s
imagenet-gpu-team-b-1-worker-0   1/1     Running   0          8m47s
```

Keep this terminal open! You'll watch this job get preempted.

### Terminal 2: submit the high-priority job

In a second terminal, navigate to the task governance directory where the example YAML files live:

```bash
cd ~/task-governance-examples/awsome-distributed-ai/architectures/sagemaker-hyperpod-eks/task-governance
```

Then submit the high-priority job:

```bash
kubectl apply -f 3-imagenet-gpu-team-b-higher-prio.yaml --namespace hyperpod-ns-team-b
```

## Step 3: Watch the preemption happen ⚡

### Terminal 1 (Team B's pods)

Within seconds, you'll see the lower-priority job disappear and the high-priority job appear:

```text
NAME                                           READY   STATUS    RESTARTS   AGE
etcd-gpu-6fcb4f6f7d-sspgh                      1/1     Running   0          12m
etcd-gpu-high-priority-6dc6b57bfd-9xkzp        1/1     Running   0          2m16s
imagenet-gpu-team-b-2-high-priority-worker-0   1/1     Running   0          2m16s
imagenet-gpu-team-b-2-high-priority-worker-1   1/1     Running   0          2m16s
```

✅ The high-priority job is now running on 2 instances!

Since this job uses a priority class with a higher weight than the other jobs, the lower-priority Job 2 is preempted.

## Step 4: Verify in the console

Navigate to the SageMaker HyperPod console and check the **Tasks** tab. You should see:

- The high-priority job: Running (2 instances)
- The lower-priority job: Suspended (preempted)

## Inspecting workloads

Task governance uses "workloads" to manage job scheduling. Let's inspect them:

```bash
kubectl get workloads -n hyperpod-ns-team-b
```

This is an example output of the command after running all 3 scenarios:

```text
NAME                                                   QUEUE                           RESERVED IN                      ADMITTED   FINISHED   AGE
pod-etcd-gpu-6584d647d4-sp6xx-bb3f9                    hyperpod-ns-team-b-localqueue   hyperpod-ns-team-b-clusterqueue   True                  11s
pytorchjob-imagenet-gpu-team-b-1-abc12                 hyperpod-ns-team-b-localqueue                                     False                 45s
pytorchjob-imagenet-gpu-team-b-2-high-priority-ef5c0   hyperpod-ns-team-b-localqueue   hyperpod-ns-team-b-clusterqueue   True                  11s
```

We can see that the workload for Job 2 has been set to `ADMITTED: False` because the newly submitted workload took precedence.

When we describe the suspended workload, we can see the reason it was preempted:

```bash
kubectl describe workload \
  $(kubectl get workloads -n hyperpod-ns-team-b -o name | grep imagenet-gpu-team-b-1 | head -1 | cut -d/ -f2) \
  -n hyperpod-ns-team-b
```

```text
Status:
  Conditions:
    Last Transition Time:  2025-02-04T19:06:25Z
    Message:               couldn't assign flavors to pod set worker: borrowing limit for nvidia.com/gpu in flavor ml.g5.8xlarge exceeded
    Observed Generation:   1
    Reason:                Pending
    Status:                False
    Type:                  QuotaReserved
    Last Transition Time:  2025-02-04T19:06:25Z
    Message:               Preempted to accommodate a workload (UID: d34468c2-1ce5-47cd-a61d-689be78b6121) due to prioritization in the ClusterQueue
    Observed Generation:   1
    Reason:                Preempted
    Status:                True
    Type:                  Evicted
    Last Transition Time:  2025-02-04T19:06:25Z
    Message:               The workload has no reservation
    Observed Generation:   1
    Reason:                NoReservation
    Status:                False
    Type:                  Admitted
    Last Transition Time:  2025-02-04T19:06:25Z
    Message:               Preempted to accommodate a workload (UID: d34468c2-1ce5-47cd-a61d-689be78b6121) due to prioritization in the ClusterQueue
    Reason:                InClusterQueue
    Status:                True
    Type:                  Preempted
    Last Transition Time:  2025-02-04T19:06:25Z
    Message:               Preempted to accommodate a workload (UID: d34468c2-1ce5-47cd-a61d-689be78b6121) due to prioritization in the ClusterQueue
    Observed Generation:   1
    Reason:                Preempted
    Status:                True
    Type:                  Requeued
```

## [Optional] Release resources from Team B's jobs to see if Team A's job continues

First, delete all of Team B's jobs:

```bash
kubectl delete -f 2-imagenet-gpu-team-b.yaml
kubectl delete -f 3-imagenet-gpu-team-b-higher-prio.yaml
```

Then, you'll notice immediately:

```text
NAME                             READY   STATUS    RESTARTS   AGE
etcd-gpu-588cb7fd6c-7vjbt        1/1     Running   0          42m
imagenet-gpu-team-a-1-worker-0   1/1     Running   0          10s
imagenet-gpu-team-a-1-worker-1   1/1     Running   0          10s
```

All 3 pods are running again! You may tail the logs again if you wish:

```bash
kubetail imagenet -n hyperpod-ns-team-a
```

And you'll see that it continued from the latest checkpoint, as expected:

```text
[imagenet-gpu-team-a-1-worker-0] Epoch: [0][ 420/1563] Time 0.078 ( 0.071) Data 0.058 ( 0.049) Loss 4.6034e+00 (5.2664e+00) Acc@1 3.12 ( 2.12) Acc@5 25.00 ( 8.51)
[imagenet-gpu-team-a-1-worker-0] Epoch: [0][ 430/1563] Time 0.065 ( 0.071) Data 0.045 ( 0.049) Loss 4.9248e+00 (5.2589e+00) Acc@1 0.00 ( 2.14) Acc@5 12.50 ( 8.61)
[imagenet-gpu-team-a-1-worker-0] Epoch: [0][ 440/1563] Time 0.064 ( 0.071) Data 0.045 ( 0.049) Loss 4.9248e+00 (5.2512e+00) Acc@1 0.00 ( 2.16) Acc@5 12.50 ( 8.73)
[imagenet-gpu-team-a-1-worker-0] Epoch: [0][ 450/1563] Time 0.060 ( 0.071) Data 0.042 ( 0.049) Loss 4.7035e+00 (5.2450e+00) Acc@1 6.25 ( 2.20)
```

Once again, on your SageMaker console, you'll only see 1 running task.

## Clean up

Delete each job together with its etcd Service and Deployment by applying `delete -f` on the manifests you created. Deleting only the PyTorchJob would leave the etcd resources behind in each team namespace.

```bash
kubectl delete -f 3-imagenet-gpu-team-b-higher-prio.yaml -n hyperpod-ns-team-b
```

```bash
kubectl delete -f 2-imagenet-gpu-team-b.yaml -n hyperpod-ns-team-b
```

```bash
kubectl delete -f 1-imagenet-gpu-team-a.yaml -n hyperpod-ns-team-a
```
