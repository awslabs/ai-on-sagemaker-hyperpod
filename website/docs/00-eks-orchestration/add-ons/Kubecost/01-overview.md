---
title: Overview & Architecture
sidebar_position: 1
---

# Overview & Architecture

## What We're Building

This guide deploys **Kubecost v2.8.4** on a SageMaker HyperPod EKS cluster with:

- **Accurate per-node pricing** derived from your actual CUR billing data (not public on-demand rates)
- **Per-pod cost allocation** by `project`, `team`, and custom labels
- **Total cluster cost visibility** — compute, storage (EBS, FSx), EKS fee, data transfer
- **Enforced tagging** so every workload is attributed to a team and project

## How It Works (Architecture)

```
CUR (AmazonSageMaker billing) ──► Athena ──► Effective Hourly Rates
                                                      │
                                               CSV Pricing File
                                                      │
                                               ConfigMap (K8s)
                                                      │
              ┌──── Kubecost v2.8.4 on HyperPod EKS ──┤
              │                                         │
              │  Prometheus ──► Cost Model ◄──── CSV Pricing
              │  (k8s metrics)  (usage × price)
              │       │
              │       ▼
              │  ETL pipeline
              │       │
              │       ▼
              │  Allocations (pod/team/project costs)
              │  Assets (node/disk costs)
              │  Cloud Cost (FSx, S3, EKS fee from CUR)
              │  Collections, Anomaly Detection
              └────────────────────────────────────────
```

## Why CSV Pricing Is Required for HyperPod

:::warning
SageMaker HyperPod compute is billed in CUR under `AmazonSageMaker` with usage types like `Cluster:ml.g5.12xlarge` — **NOT** under `AmazonEC2` with `i-*` instance IDs. Kubecost's built-in CUR reconciliation matches nodes by EC2 instance ID, which doesn't exist for HyperPod.

**Result:** Kubecost's automatic CUR node reconciliation does not work for HyperPod. CSV custom pricing is the **primary** mechanism for accurate node-level costs.

**Solution:** We derive effective hourly rates from CUR via Athena and load them into Kubecost as CSV pricing. CUR still provides the Cloud Cost page (total SageMaker/FSx/S3 costs).
:::

## HyperPod-Specific Considerations

| Aspect | HyperPod Difference | Impact |
|---|---|---|
| **Billing service** | `AmazonSageMaker` (not `AmazonEC2`) | CSV pricing required for node costs |
| **Node naming** | `hyperpod-i-xxxxxxxx` | Kubecost maps via `providerID` |
| **EBS volumes** | Requires `sagemaker:AttachClusterNodeVolume` | Extra IAM permissions |
| **Dashboard access** | ClusterIP + port-forward | No public LB needed; use `kubectl port-forward` |

## Prerequisites & Tools

### Required CLI Tools

```bash
aws --version        # v2.x required
kubectl version --client  # v1.25+ (v2.x requires K8s 1.25+)
helm version         # v3.12+
eksctl version       # v0.150+
jq --version         # v1.6+
docker --version     # For ECR login
```

:::note
Kubecost v2.x requires Kubernetes 1.25 or later. Verify your HyperPod EKS cluster version:
```bash
kubectl version --client --output=yaml | grep gitVersion
```
:::

### AWS Permissions

Your IAM user/role needs: IAM (create policies/roles), EKS (describe/addons), S3 (CUR + Athena buckets), Athena (queries), Glue (catalog), Cost Explorer (billing), EC2 (describe), SageMaker (AttachClusterNodeVolume), CloudFormation (describe stacks).

### CUR Requirements

You need at least one CUR configured:

| Setting | Required Value |
|---------|---------------|
| Format | Parquet |
| Athena integration | Enabled |
| Resource IDs | Enabled |
| Granularity | Hourly (preferred) or Daily |
