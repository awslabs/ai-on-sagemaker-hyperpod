---
title: Workshop Overview
sidebar_position: 1
---

# Amazon SageMaker HyperPod - Slurm Workshop

:::note Comprehensive Reference Documentation
This workshop provides a guided, hands-on sandbox experience (think POC). For production deployment guidelines and best practices, see the [Slurm Orchestration](/docs/slurm-orchestration/getting-started/) reference documentation.
:::

:::caution Running outside AWS Workshop Studio?
This workshop was originally designed for AWS Workshop Studio, which pre-provisions certain infrastructure (VPC, observability stack). If you're running self-paced in your own account, see the [Prerequisites](./01-prerequisites/02-aws-cli.md) section for credential setup and note the additional deployment steps called out in each section.
:::

Amazon SageMaker HyperPod offers advanced training tools to help you accelerate scalable, reliable, and secure generative AI application development. In this workshop, you will experience how to train a large language model (LLM) on diverse, representative data and learn how to utilize the latest SageMaker model training tools to troubleshoot convergence issues and improve the model performance.

## What You Will Learn

In this workshop you will:

1. Deploy a SageMaker HyperPod Slurm cluster
2. Run a sample Picotron distributed training job on `ml.g5.8xlarge` A10 GPU based instances
3. Test cluster resiliency with error injection and auto-recovery
4. Set up monitoring with Prometheus and Grafana

## Target Audience

The intended audience for this workshop is:
- ML Researchers/Scientists
- ML Engineers
- ML Infrastructure Admins
- HPC Engineers

## Workshop Duration

This workshop takes approximately 2 hours to complete.

## Region

This workshop is intended to be run in the `us-west-2` region.
