---
title: Borrow Idle Compute
sidebar_position: 5
---

# Borrow idle compute

## 🎯 What's happening

**Team A's request:** 2 x `ml.g7.2xlarge` instances.
**Team A's guarantee:** 1 instance.
**Team B's status:** idle (not using their 1 guaranteed instance).

Task governance will:

1. Allocate Team A's 1 guaranteed instance
2. Detect that Team B's instance is idle
3. Automatically lend Team B's instance to Team A
4. Start Team A's job on 2 instances

All automatic. No manual intervention needed!

:::note
The crawl captured this page's "🎬 The scenario" heading with no body text. See the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/05-task-governance/02-example/02-borrow-compute) for the scenario narrative and the console screenshots.
:::

## Step 1: Prepare Team A's training job

The example PyTorch job that we cloned uses 3 instances and hardcoded instance types by default. Let's adjust it for our cluster:

```bash
# Adjust replica count from 3 to 2
sed -i \
  -e '/pytorchReplicaSpecs:/,/replicas:/{s/replicas: 3/replicas: 2/}' \
  -e 's/--nnodes=3/--nnodes=2/' \
  1-imagenet-gpu-team-a.yaml

# Replace hardcoded instance type with environment variable
sed -i "s/ml.g5.8xlarge/${INSTANCE_TYPE}/g" 1-imagenet-gpu-team-a.yaml
```

What this does:

- Changes the job to request 2 instances instead of 3
- Replaces the hardcoded `ml.g5.8xlarge` with your actual instance type (`ml.g7.2xlarge`)

## Step 2: Submit Team A's job

Launch the training:

```bash
kubectl apply -f 1-imagenet-gpu-team-a.yaml --namespace hyperpod-ns-team-a
```

Verify the job is running (pulling the container image takes ~4 minutes):

```bash
kubectl get pods -n hyperpod-ns-team-a
```

```text
NAME                             READY   STATUS              RESTARTS   AGE
etcd-gpu-588cb7fd6c-7vjbt        1/1     Running             0          30s
imagenet-gpu-team-a-1-worker-0   0/1     ContainerCreating   0          4s
imagenet-gpu-team-a-1-worker-1   0/1     ContainerCreating   0          4s
```

:::note
The `imagenet-gpu-team-a-1-worker` pods may take a few extra seconds (~25s) to come up.
:::

After ~5 minutes, all your pods should transition to `Running`:

```text
NAME                             READY   STATUS    RESTARTS   AGE
etcd-gpu-588cb7fd6c-7vjbt        1/1     Running   0          4m29s
imagenet-gpu-team-a-1-worker-0   1/1     Running   0          4m3s
imagenet-gpu-team-a-1-worker-1   1/1     Running   0          4m3s
```

## Step 3: Verify in the console

Navigate to the SageMaker HyperPod console and check the **Tasks** tab. You should see:

- Job: `imagenet-gpu-team-a-1`
- Team: `team-a`
- Instances: 2 (1 guaranteed + 1 borrowed from Team B)
- Status: Running

## Step 4: Check the training logs

Once the pods are running, you can check their logs:

```bash
kubetail imagenet -n hyperpod-ns-team-a
```

:::important
Ensure the pods are running before moving on to the next step.
:::

## ✅ Success: borrowing works

What just happened:

- ✅ Team A requested 2 instances (only has 1 guaranteed)
- ✅ Task governance detected Team B's idle instance
- ✅ It automatically lent Team B's instance to Team A
- ✅ Team A's job started on 2 instances
- ✅ Zero manual intervention required

Next: [Reclaim guaranteed compute](./06-reclaim-guaranteed-compute.md) →
