---
title: Workshop Overview
sidebar_position: 1
---

:::info Running on Your Own Account?
If you're not at an AWS-hosted event, see the [self-deployment guide](https://github.com/awslabs/ai-on-sagemaker-hyperpod/tree/main/workshops/eks) in the repository for instructions on provisioning all required infrastructure in your own AWS account.
:::

# 🧬 Welcome to Project Helix

> **Mission Briefing**: The world is facing an antimicrobial resistance crisis. 1.27 million people die annually from antibiotic-resistant infections.
>
> **Your mission**: Prove that AI can accelerate the discovery of new antimicrobial peptides.

## 🎮 Your Role: ML Engineer at DNAAI

**You are**: A newly hired ML Engineer at DNAAI, a biotech startup focused on AI-powered drug discovery.

**Your tools**:
- Pre-configured Amazon SageMaker HyperPod cluster (2x ml.g5.2xlarge with NVIDIA A10G GPUs)
- FSx for Lustre with preprocessed UniRef50 dataset
- SageMaker Studio workspace with kubectl access
- Your ML engineering skills (and this workshop guide!)

**Your team**:
- **Infrastructure Engineers**: "We built the cluster. Now make it sing! 🎸"
- **Data Scientists**: "Dataset is ready. We tokenized everything last night. Good luck!"
- **CEO**: "Show me the ROI or show me the door." (She's kidding. Mostly.)

## 🗺️ Mission Roadmap

| Level | Mission | Duration |
|-------|---------|----------|
| 1 | **Cluster Verification** ⚙️ — Verify your HyperPod cluster is operational | 5 min |
| 2 | **Training** 🚀 — Submit distributed training job for ESM2 | 15 min |
| 3 | **Resiliency Test** 💪 — Simulate node failure, watch surgical recovery | 20 min |
| 4 | **Observability** 📊 — Monitor cluster performance with CloudWatch | 10 min |
| 5 | **Multi-Team Collaboration** 🤝 — Set up Task Governance for multiple teams | 20 min |
| 6 | **Production Deployment** 🎯 — Deploy inference endpoint with auto-scaling | 20 min |

## 🎯 What You'll Learn

By the end of this workshop, you'll know how to:

- ✅ Deploy and manage SageMaker HyperPod clusters with EKS
- ✅ Run distributed training jobs using the HyperPod Training Operator
- ✅ Implement automatic fault recovery and resilience
- ✅ Monitor ML workloads with CloudWatch Container Insights
- ✅ Manage multi-team resource allocation with Task Governance
- ✅ Deploy production inference endpoints with auto-scaling

## 🧪 The Science: Why Antimicrobial Discovery?

**The Problem**: Antibiotic resistance is one of the biggest threats to global health. Traditional drug discovery takes 10-15 years and costs $2.6 billion per drug.

**DNAAI's Solution**: AI-powered protein language models like ESM2 can:
- Analyze millions of protein sequences in hours (not years)
- Predict antimicrobial properties from sequence alone
- Generate novel peptide candidates for testing
- Reduce discovery costs by 90%+

**The Model**: [ESM2](https://github.com/facebookresearch/esm) (Evolutionary Scale Modeling) is a state-of-the-art protein language model from Meta AI. It understands protein sequences like GPT understands text.

## Workshop Resources

During this workshop, you'll be leveraging several pre-provisioned cloud resources:

- **Amazon SageMaker HyperPod**: Built-in health checks and resiliency with automatic node recovery and training job auto-resume
- **Amazon EKS**: Managed Kubernetes control plane acting as orchestrator for HyperPod compute nodes
- **GPU Compute Nodes**: ml.g5.2xlarge instances created as HyperPod instance groups and added as EKS nodes
- **FSx for Lustre**: Shared file system mounted at `/fsx` accessible by all HyperPod nodes
- **Amazon S3**: Stores lifecycle scripts and training data via FSx data repository associations
- **SageMaker Studio Code Editor**: Standardized development environment

## EC2 Instance Types

### NVIDIA GPU Instances

| Instance Size | GPUs | GPU Memory (GB) | vCPUs | Memory | EFA Bandwidth (Gbps) | On-Demand Price/hr |
|---|---|---|---|---|---|---|
| ml.g5.2xlarge | 1 NVIDIA A10G | 24 GDDR6 | 8 | 32 GiB | N/A | $1.515 |
| ml.g5.8xlarge | 1 NVIDIA A10G | 24 GDDR6 | 32 | 128 GiB | 25 | $3.06 |
| ml.g5.12xlarge | 4 NVIDIA A10Gs | 96 GDDR6 | 48 | 192 GiB | 40 | $7.09 |
| ml.p4d.24xlarge | 8 NVIDIA A100s | 320 HBM2 | 96 | 1152 GiB | 400 | $25.910 |
| ml.p5.48xlarge | 8 NVIDIA H100s | 640 HBM3 | 192 | 2 TiB | 3200 | $66.048 |
| ml.p5e.48xlarge | 8 NVIDIA H200s | 1128 HBM3e | 192 | 2 TiB | 3200 | $72.795 |

## Recommended Background Knowledge

- [AWS VPC Networking](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Docker](https://www.docker.com/)
- [PyTorch DistributedDataParallel](https://pytorch.org/docs/stable/generated/torch.nn.parallel.DistributedDataParallel.html)
- [FSDP](https://pytorch.org/docs/stable/fsdp.html)

:::note
Don't worry if you're new to some of these! We'll guide you through everything step-by-step.
:::
