---
title: Configure Policies
sidebar_position: 1
---

# 🏗️ Setting Up Multi-Team Governance

## The Scenario

Your startup now has two research teams:

| | Team A | Team B |
|---|---|---|
| **Lead** | Dr. Matthew Nightingale | Prof. Natarajan |
| **Mission** | Discover new antibiotics (core business!) | Engineer enzymes for industrial applications |
| **Needs** | 2x ml.g5.2xlarge for training | 1x ml.g5.2xlarge for protein folding |
| **Guaranteed** | 1 instance | 1 instance |

**Your cluster**: 2x ml.g5.2xlarge instances (total)

## Step 1: Set Environment Variables

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

## Step 3: Create Compute Allocation for Team A

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

```bash
aws sagemaker \
  create-compute-quota \
  --name "Team-B-Quota-Allocation" \
  --cluster-arn $HYPERPOD_CLUSTER_ARN \
  --compute-quota-config "ComputeQuotaResources=[{InstanceType=ml.g5.2xlarge,Count=1}],ResourceSharingConfig={Strategy=LendAndBorrow,BorrowLimit=100},PreemptTeamTasks=LowerPriority" \
  --activation-state "Enabled" \
  --compute-quota-target "TeamName=team-b,FairShareWeight=0"
```

## Step 5: Clone Examples

```bash
cd ~
mkdir -p task-governance-examples && cd task-governance-examples
git clone https://github.com/aws-samples/awsome-distributed-training/
cd awsome-distributed-training/1.architectures/7.sagemaker-hyperpod-eks/task-governance
```

## ✅ Configuration Complete!

- ✅ Created cluster policy with 4 priority classes
- ✅ Enabled fair-share resource allocation
- ✅ Configured Team A's compute quota (1 guaranteed, 100% borrowing)
- ✅ Configured Team B's compute quota (1 guaranteed, 100% borrowing)
