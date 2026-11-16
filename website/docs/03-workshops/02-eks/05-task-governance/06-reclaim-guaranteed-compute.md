---
title: Reclaim Guaranteed Compute
sidebar_position: 6
---

# Reclaim guaranteed compute

## 🎬 The Scenario

**Prof. Natarajan (Team B)**: "We need our instance back."

Your confident response: "Don't worry. Your job will be suspended gracefully and resume when resources become available again. Watch..."

## 🎯 What's Happening

**Current state**:

- Team A is using 2 instances (1 guaranteed + 1 borrowed from Team B)
- Team B is idle

**Team B's request**: 1 instance (their guaranteed allocation)

**Task governance will**:

1. Detect Team B needs their guaranteed instance
2. Identify that Team A is borrowing it
3. Gracefully suspend Team A's job on the borrowed instance
4. Allocate Team B's guaranteed instance to Team B
5. Start Team B's job

**The result**: Team B gets their resources, Team A's job is suspended (not killed), and will resume when resources are available.

## Step 1: Create Team B's Training Job

First copy the yaml used in the previous step, `1-imagenet-gpu-team-a.yaml`:

```bash
cp 1-imagenet-gpu-team-a.yaml 2-imagenet-gpu-team-b.yaml
```

Update the configuration for Team B (1 instance, correct instance type):

```bash
# Update for Team B
sed -i \
  -e 's/team-a/team-b/g' \
  -e '/pytorchReplicaSpecs:/,/replicas:/{s/replicas: 2/replicas: 1/}' \
  -e 's/--nnodes=2/--nnodes=1/' \
  2-imagenet-gpu-team-b.yaml

# Ensure instance type is correct
sed -i "s/ml.g5.8xlarge/${INSTANCE_TYPE}/g" 2-imagenet-gpu-team-b.yaml
```

What this does:

1. Changes all references from `team-a` to `team-b`
2. Reduces replica count from 2 to 1 (Team B only needs 1 instance)
3. Updates instance type to match your cluster

## Step 2: Open Two Terminals for Real-Time Monitoring 🎮

Open **TWO** terminal windows to watch the reclamation happen in real-time:

1. **Terminal 1**: Monitor Team A's pods (watch them get suspended)
2. **Terminal 2**: Submit Team B's job and monitor Team B's pods

This gives you the full "mission control" experience! 🚀

### Terminal 1: Monitor Team A

Watch Team A's pods:

```bash
watch kubectl get pods -n hyperpod-ns-team-a
```

You should currently see:

```
NAME                             READY   STATUS    RESTARTS   AGE
etcd-gpu-679b676b55-5xj5x        1/1     Running   0          10m
imagenet-gpu-team-a-1-worker-0   1/1     Running   0          10m
imagenet-gpu-team-a-1-worker-1   1/1     Running   0          10m
```

Keep this terminal open! You'll watch one of these pods get suspended.

### Terminal 2: Submit Team B's Job

This is a **new terminal**, so first navigate to the task governance directory where the example YAML files live:

```bash
cd ~/task-governance-examples/awsome-distributed-ai/architectures/sagemaker-hyperpod-eks/task-governance
```

Then submit Team B's job:

```bash
kubectl apply -f 2-imagenet-gpu-team-b.yaml
```

## Step 3: Watch the Reclamation Happen ⚡

### In Terminal 1 (Team A)

```
NAME                             READY   STATUS        RESTARTS   AGE
etcd-gpu-588cb7fd6c-7vjbt        1/1     Running       0          35m
imagenet-gpu-team-a-1-worker-1   1/1     Terminating   0          34m
```

One of the pods immediately dies, the other starts terminating.

**What happened**: Team A's job was suspended because it was using Team B's guaranteed instance.

### In Terminal 2 (Team B)

Watch Team B's pods start up:

```bash
watch kubectl get pods -n hyperpod-ns-team-b
```

You'll see:

```
NAME                             READY   STATUS    RESTARTS   AGE
etcd-gpu-6fcb4f6f7d-c2r6l        1/1     Running   0          61s
imagenet-gpu-team-b-1-worker-0   1/1     Running   0          61s
```

If you were following the `kubetail` logs for Team A's training instead of the pods, you will see this log:

```
[imagenet-gpu-team-a-1-worker-0] [2025-11-26 23:28:46,662] torch.distributed.elastic.agent.server.api: [WARNING] Received Signals.SIGTERM death signal, shutting down workers
[imagenet-gpu-team-a-1-worker-0] [2025-11-26 23:28:46,662] torch.distributed.elastic.multiprocessing.api: [WARNING] Sending process 105 closing signal SIGTERM
[imagenet-gpu-team-a-1-worker-1] terminate called after throwing an instance of 'std::runtime_error'
[imagenet-gpu-team-a-1-worker-1]   what(): Unconvertible NCCL type
[imagenet-gpu-team-a-1-worker-1] [2025-11-26 23:28:46,693] torch.distributed.elastic.agent.server.api: [WARNING] Received Signals.SIGTERM death signal, shutting down workers
[imagenet-gpu-team-a-1-worker-1] [2025-11-26 23:28:46,694] torch.distributed.elastic.multiprocessing.api: [WARNING] Sending process 105 closing signal SIGTERM
[imagenet-gpu-team-a-1-worker-0] Traceback (most recent call last):
[imagenet-gpu-team-a-1-worker-0]   File "/usr/local/bin/torchrun", line 8, in <module>
[imagenet-gpu-team-a-1-worker-0]     sys.exit(main())
[imagenet-gpu-team-a-1-worker-0]   File "/usr/local/lib/python3.10/dist-packages/torch/distributed/elastic/multiprocessing/errors/__init__.py", line 351, in wrapper
[imagenet-gpu-team-a-1-worker-0]     return f(*args, **kwargs)
[imagenet-gpu-team-a-1-worker-0]   File "/usr/local/lib/python3.10/dist-packages/torch/distributed/run.py", line 806, in main
[imagenet-gpu-team-a-1-worker-0]     run(args)
[imagenet-gpu-team-a-1-worker-0]   File "/usr/local/lib/python3.10/dist-packages/torch/distributed/run.py", line 797, in run
[imagenet-gpu-team-a-1-worker-0]     elastic_launch(
[imagenet-gpu-team-a-1-worker-0]   File "/usr/local/lib/python3.10/dist-packages/torch/distributed/launcher/api.py", line 134, in __call__
[imagenet-gpu-team-a-1-worker-0]     return launch_agent(self._config, self._entrypoint, list(args))
[imagenet-gpu-team-a-1-worker-0]   File "/usr/local/lib/python3.10/dist-packages/torch/distributed/launcher/api.py", line 255, in launch_agent
```

**What happened**: ✅ Team B is now running on their guaranteed instance!

## Step 4: Verify in Console

Navigate to the SageMaker HyperPod Console and check the **Tasks** tab. You should see:

- `imagenet-gpu-team-a-1`: Suspended (waiting for resources)
- `imagenet-gpu-team-b-1`: Running (using their guaranteed instance)

## Step 5: Check Team B's Training Logs

```bash
kubetail imagenet -n hyperpod-ns-team-b
```

Now, Professor Natarajan is happy that his team's simulation is running!

**Dr. Matthew Nightingale (Team A)**: "What about my training job? Is it lost?"

**You**: "Nope! It's suspended. As soon as Team B finishes or you get more resources, your job will automatically resume from where it left off."

**Investor**: "So you're telling me:

- Teams can borrow idle resources automatically
- Resources are reclaimed automatically when needed
- Jobs are suspended gracefully, not killed
- Everything resumes automatically when resources are available?"

**You**: "Exactly. Zero manual intervention. Zero lost work."

:::important
Ensure Team B's pods are running before moving on to the next step. If you followed along with the section marked optional, follow steps 2-4 again and ensure that Team B is running on their guaranteed instance. Continue with the two terminal setup!
:::
