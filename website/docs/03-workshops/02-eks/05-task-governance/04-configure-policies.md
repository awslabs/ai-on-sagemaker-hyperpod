---
title: "Setup for running the examples: Configure Policies"
sidebar_position: 4
---

# Setup for running the examples: Configure Policies

## 🏗️ Setting Up Multi-Team Governance

**What we're doing**: Configuring cluster policies and compute allocations for Team A and Team B.

**The setup**:

- **Cluster**: 2x `ml.g5.2xlarge` instances
- **Team A**: 1 guaranteed instance, can borrow up to 100%
- **Team B**: 1 guaranteed instance, can borrow up to 100%
- **Priority classes**: inference (90) > experimentation (80) > training (70) > fine-tuning (50)

## Step 1: Set Environment Variables

Get your HyperPod cluster ARN:

```bash
export HYPERPOD_CLUSTER_ARN=$(aws sagemaker list-clusters | jq -r '.ClusterSummaries[0].ClusterArn')
echo "Cluster ARN: $HYPERPOD_CLUSTER_ARN"
```

## Step 2: Create Cluster Policy

```bash
aws sagemaker \
  create-cluster-scheduler-config \
  --name "example-cluster-scheduler-config" \
  --cluster-arn $HYPERPOD_CLUSTER_ARN \
  --scheduler-config "PriorityClasses=[{Name=inference,Weight=90},{Name=experimentation,Weight=80},{Name=fine-tuning,Weight=50},{Name=training,Weight=70}],FairShare=Enabled"
```

Example output:

```json
{
    "ClusterSchedulerConfigArn": "arn:aws:sagemaker:us-west-2:<your-account-id>:cluster-scheduler-config/gdmwg4v0xn4x",
    "ClusterSchedulerConfigId": "gdmwg4v0xn4x"
}
```

You can verify the creation with:

```bash
aws sagemaker list-cluster-scheduler-configs
```

This should show something like:

```json
{
    "ClusterSchedulerConfigSummaries": [
        {
            "ClusterSchedulerConfigArn": "arn:aws:sagemaker:us-west-2:<your-account-id>:cluster-scheduler-config/gdmwg4v0xn4x",
            "ClusterSchedulerConfigId": "gdmwg4v0xn4x",
            "ClusterSchedulerConfigVersion": 1,
            "Name": "example-cluster-scheduler-config",
            "CreationTime": "2025-11-26T19:28:00.300000+00:00",
            "LastModifiedTime": "2025-11-26T19:28:00.300000+00:00",
            "Status": "Created",
            "ClusterArn": "arn:aws:sagemaker:us-west-2:<your-account-id>:cluster/3yxullmjrpgb"
        }
    ]
}
```

Notice `"Status": "Created"`.

:::warning Status is `CreateFailed`?
The most common causes are the task governance add-on not being `Active` yet, or a pre-existing Kueue installation on the cluster. Confirm the add-on status in the SageMaker AI console, then recreate the scheduler config.
:::

**What you just created**: a cluster policy with four priority classes and fair-share idle compute allocation. You can check this on your SageMaker console under "Policies" on your cluster.

A higher weight indicates a higher priority. In this example, the `inference` priority class has the highest priority.

## Step 3: Create Compute Allocation for Team A

Team A's allocation:

- **Guaranteed**: 1x `ml.g5.2xlarge`
- **Fair-share weight**: 0 (equal priority with Team B)
- **Borrowing limit**: 100% (can use entire cluster if idle)
- **Preemption**: Lower priority tasks only

```bash
aws sagemaker \
  create-compute-quota \
  --name "Team-A-Quota-Allocation" \
  --cluster-arn $HYPERPOD_CLUSTER_ARN \
  --compute-quota-config "ComputeQuotaResources=[{InstanceType=ml.g5.2xlarge,Count=1}],ResourceSharingConfig={Strategy=LendAndBorrow,BorrowLimit=100},PreemptTeamTasks=LowerPriority" \
  --activation-state "Enabled" \
  --compute-quota-target "TeamName=team-a,FairShareWeight=0"
```

## Step 4: Create Compute Allocation for Team B

Team B's allocation:

- **Guaranteed**: 1x `ml.g5.2xlarge`
- **Fair-share weight**: 0 (equal priority with Team A)
- **Borrowing limit**: 100% (can use entire cluster if idle)
- **Preemption**: Lower priority tasks only

```bash
aws sagemaker \
  create-compute-quota \
  --name "Team-B-Quota-Allocation" \
  --cluster-arn $HYPERPOD_CLUSTER_ARN \
  --compute-quota-config "ComputeQuotaResources=[{InstanceType=ml.g5.2xlarge,Count=1}],ResourceSharingConfig={Strategy=LendAndBorrow,BorrowLimit=100},PreemptTeamTasks=LowerPriority" \
  --activation-state "Enabled" \
  --compute-quota-target "TeamName=team-b,FairShareWeight=0"
```

## Step 5: Clone example to see Task Governance in action

Get the example directory cloned to your workspace:

```bash
cd ~
mkdir -p task-governance-examples && cd task-governance-examples
git clone https://github.com/awslabs/awsome-distributed-ai/
cd awsome-distributed-ai/architectures/sagemaker-hyperpod-eks/task-governance
```

## ✅ Configuration Complete!

You've successfully:

- ✅ Created cluster policy with 4 priority classes
- ✅ Enabled fair-share resource allocation
- ✅ Configured Team A's compute quota (1 guaranteed, 100% borrowing)
- ✅ Configured Team B's compute quota (1 guaranteed, 100% borrowing)
- ✅ Cloned example training jobs

Next: [Demonstrate Resource Borrowing](./05-borrow-idle-compute.md) →
