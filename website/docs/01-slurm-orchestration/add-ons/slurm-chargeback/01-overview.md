---
title: Overview & Architecture
sidebar_position: 1
---

# GPU Chargeback & Cost Allocation for HyperPod Slurm

This guide implements GPU chargeback tracking for SageMaker HyperPod Slurm clusters — enabling you to track GPU consumption per user, team, and project, and convert usage into dollar costs using your actual AWS billing data.

## The Problem

When multiple teams share a single HyperPod Slurm cluster, you need answers to:

- **Which team** is consuming how much GPU capacity?
- **Which project or model version** is driving costs?
- **How much does each team owe** based on actual AWS billing rates?

Without chargeback, GPU clusters become a shared cost center with no accountability.

## The Solution

This guide combines three mechanisms:

1. **Slurm Accounting** (`slurmdbd`) — tracks GPU-hours per user and team via account hierarchy
2. **Job Tagging** (`--comment` with `project-id`) — tracks GPU usage by model/project version
3. **CUR-Based Cost Allocation** — derives actual GPU hourly rates from your AWS Cost and Usage Report

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SageMaker HyperPod Slurm Cluster                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐      │
│  │  Controller     │    │  Compute Node 1 │    │  Compute Node N │      │
│  │  Node           │    │  (GPUs)         │    │  (GPUs)         │      │
│  │                 │    │                 │    │                 │      │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │      │
│  │  │ slurmctld │  │    │  │  slurmd   │  │    │  │  slurmd   │  │      │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │      │
│  │  ┌───────────┐  │    └─────────────────┘    └─────────────────┘      │
│  │  │ slurmdbd  │  │                                                    │
│  │  └───────────┘  │    MERGED PARTITION: gpu                           │
│  │        │        │    (All teams share GPUs)                          │
│  │        ▼        │                                                    │
│  │  ┌───────────┐  │                                                    │
│  │  │ MariaDB   │  │                                                    │
│  │  └───────────┘  │                                                    │
│  └─────────────────┘                                                    │
└─────────────────────────────────────────────────────────────────────────┘
              │
              │  CSV Reports (weekly/monthly/yearly)
              ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   S3 Bucket     │───▶│     Athena      │───▶│   QuickSight    │
│   (CSV Reports) │    │   (SQL Query)   │    │   or Grafana    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Data Flow

```
Slurm Accounting (GPU Hours)              CUR (Instance Cost)
         │                                        │
   sreport / sacct                          Athena Query
         │                                        │
    CSV Reports                          $/hr per instance type
         │                                        │
      S3 Upload                           ÷ GPUs per instance
         │                                        │
    Athena Tables ──────────────┬──────── GPU Hourly Rate
                                │
                    GPU Hours × Rate = $ Cost
                                │
                 ┌──────────────┼──────────────┐
                 ▼              ▼              ▼
            Per User       Per Team      Per Project
                 │              │              │
                 └──────────────┴──────────────┘
                                │
                          QuickSight
                        GPU Chargeback
                          Dashboard
```

## What This Guide Covers

| Page                                                          | What You'll Set Up                                    |
|---------------------------------------------------------------|-------------------------------------------------------|
| [Account Hierarchy](./02-account-hierarchy.md)                | Slurm accounts mirroring your org structure           |
| [QoS, Priority & Preemption](./03-qos-priority-preemption.md) | Service tiers, scheduling, resource limits (Optional) |
| [LDAP Integration](./04-ldap-integration.md)                  | sync users from LDAP (Optional)                       |
| [Job Tagging](./05-job-tagging.md)                            | Project-ID tracking via `--comment`                   |
| [Data Extraction](./06-data-extraction.md)                    | GPU usage reports via `sreport` and `sacct`           |
| [S3 Upload Automation](./07-s3-upload-automation.md)          | Automated report upload to S3                         |
| [Cost Attribution from CUR](./08-cost-allocation-from-cur.md) | Convert GPU-hours to dollar costs                     |
| [QuickSight Dashboard](./09-quicksight-dashboard.md)          | Visual dashboards for chargeback (Optional)           |

## Prerequisites

- A running SageMaker HyperPod Slurm cluster
- `slurmdbd` enabled and connected (Slurm accounting database)
- AWS CLI configured with S3 and Athena access
- CUR (Cost and Usage Report) configured with Athena integration

:::tip Verify Slurm Accounting
```bash
sacctmgr show configuration
sacctmgr list cluster
sacctmgr show tres
```
If these commands return results, your cluster is ready for chargeback setup.
:::
