---
title: Configure Policies
sidebar_position: 4
---

# Setup for running the examples: configure policies

## 🏗️ Setting up multi-team governance

**What we're doing:** configuring cluster policies and compute allocations for Team A and Team B.

**The setup:**

- **Cluster:** 2 x `ml.g7.2xlarge` instances
- **Team A:** 1 guaranteed instance, can borrow up to 100%
- **Team B:** 1 guaranteed instance, can borrow up to 100%
- **Priority classes:** inference (90) > experimentation (80) > training (70) > fine-tuning (50)

## Step 1: Set environment variables

Get your HyperPod cluster ARN:

```bash
export HYPERPOD_CLUSTER_ARN=$(aws sagemaker list-clusters | jq -r '.ClusterSummaries[0].ClusterArn')
echo "Cluster ARN: $HYPERPOD_CLUSTER_ARN"
```

## Step 2: Create the cluster policy

:::important Wait before continuing
If you just installed the task governance add-on in the previous section, give it ~60 seconds to finish wiring up its Kubernetes webhooks before creating the scheduler config. Otherwise the create call can land in `CreateFailed`.
:::

```bash
sleep 60
```

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
    "ClusterSchedulerConfigArn": "arn:aws:sagemaker:us-west-2:891377046717:cluster-scheduler-config/gdmwg4v0xn4x",
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
            "ClusterSchedulerConfigArn": "arn:aws:sagemaker:us-west-2:891377046717:cluster-scheduler-config/gdmwg4v0xn4x",
            "ClusterSchedulerConfigId": "gdmwg4v0xn4x",
            "ClusterSchedulerConfigVersion": 1,
            "Name": "example-cluster-scheduler-config",
            "CreationTime": "2025-11-26T19:28:00.300000+00:00",
            "LastModifiedTime": "2025-11-26T19:28:00.300000+00:00",
            "Status": "Created",
            "ClusterArn": "arn:aws:sagemaker:us-west-2:891377046717:cluster/3yxullmjrpgb"
        }
    ]
}
```

Notice `"Status": "Created"`.

:::note
The live workshop has an expandable "Status is CreateFailed?" troubleshooting block here, plus a "What you just created" summary, neither of which was captured in the crawl. See the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/05-task-governance/02-example/01-example-setup) if the status is not `Created`.
:::

You can check this on your SageMaker console under **Policies** on your cluster. A higher weight indicates a higher priority — in this example, the `inference` priority class has the highest priority.

## Step 3: Create the compute allocation for Team A

Team A's allocation:

- Guaranteed: 1 x `ml.g7.2xlarge`
- Fair-share weight: 0 (equal priority with Team B)
- Borrowing limit: 100% (can use the entire cluster if idle)
- Preemption: lower priority tasks only

```bash
aws sagemaker \
  create-compute-quota \
  --name "Team-A-Quota-Allocation" \
  --cluster-arn $HYPERPOD_CLUSTER_ARN \
  --compute-quota-config "ComputeQuotaResources=[{InstanceType=ml.g7.2xlarge,Count=1}],ResourceSharingConfig={Strategy=LendAndBorrow,BorrowLimit=100},PreemptTeamTasks=LowerPriority" \
  --activation-state "Enabled" \
  --compute-quota-target "TeamName=team-a,FairShareWeight=0"
```

## Step 4: Create the compute allocation for Team B

Team B's allocation:

- Guaranteed: 1 x `ml.g7.2xlarge`
- Fair-share weight: 0 (equal priority with Team A)
- Borrowing limit: 100% (can use the entire cluster if idle)
- Preemption: lower priority tasks only

```bash
aws sagemaker \
  create-compute-quota \
  --name "Team-B-Quota-Allocation" \
  --cluster-arn $HYPERPOD_CLUSTER_ARN \
  --compute-quota-config "ComputeQuotaResources=[{InstanceType=ml.g7.2xlarge,Count=1}],ResourceSharingConfig={Strategy=LendAndBorrow,BorrowLimit=100},PreemptTeamTasks=LowerPriority" \
  --activation-state "Enabled" \
  --compute-quota-target "TeamName=team-b,FairShareWeight=0"
```

## Step 5: Clone the example to see task governance in action

Get the example directory cloned to your workspace:

```bash
cd ~
mkdir -p task-governance-examples && cd task-governance-examples
git clone https://github.com/awslabs/awsome-distributed-ai/
cd awsome-distributed-ai/architectures/sagemaker-hyperpod-eks/task-governance
```

## ✅ Configuration complete

You've successfully:

- ✅ Created a cluster policy with 4 priority classes
- ✅ Enabled fair-share resource allocation
- ✅ Configured Team A's compute quota (1 guaranteed, 100% borrowing)
- ✅ Configured Team B's compute quota (1 guaranteed, 100% borrowing)
- ✅ Cloned the example training jobs

Next: [Borrow idle compute](./05-borrow-idle-compute.md) →
