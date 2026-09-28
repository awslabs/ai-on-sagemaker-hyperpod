---
title: Observability
sidebar_position: 2
---

# Observability 

![HyperPod Observability](/img/06-observability/hyperpod-observability-fcd.png)

Observability is a foundational element of a well-architected EKS/Slurm environment. AWS provides native (CloudWatch) and open source managed (Amazon Managed Service for Prometheus (AMP), Amazon Managed Grafana (AMG) and AWS Distro for OpenTelemetry) solutions for monitoring, logging and alarming of EKS environments.

Amazon SageMaker HyperPod can optionally be integrated with [Amazon Managed Prometheus](https://docs.aws.amazon.com/prometheus/latest/userguide/what-is-Amazon-Managed-Service-Prometheus.html) and [Amazon Managed Grafana](https://docs.aws.amazon.com/grafana/latest/userguide/what-is-Amazon-Managed-Service-Grafana.html) to export metrics about your cluster and cluster-nodes to an Amazon Managed Grafana dashboard. 


In this section, we will specifically cover:

1. [Container Insights in Amazon CloudWatch (EKS only)](/docs/eks-orchestration/add-ons/Observability/Container%20Insights)
2. [AWS managed One-Click Observability with AMP and AMG (EKS only)](/docs/eks-orchestration/add-ons/Observability/one-click-observability-eks)
3. [SageMaker Managed MLFlow](/docs/eks-orchestration/add-ons/MLFlow)
4. [Observability with AMP and AMG (Slurm only)](/docs/slurm-orchestration/add-ons/observability-slurm)
