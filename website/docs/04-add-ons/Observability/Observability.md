---
sidebar_position: 1
---
# Observability/Profiling


## Overview

Observability is a foundational element of a well-architected EKS environment. AWS provides native (CloudWatch) and open source managed (Amazon Managed Service for Prometheus, Amazon Managed Grafana and AWS Distro for OpenTelemetry) solutions for monitoring, logging and alarming of EKS environments.


SageMaker HyperPod EKS can optionally be integrated with [Amazon Managed Prometheus](https://docs.aws.amazon.com/prometheus/latest/userguide/what-is-Amazon-Managed-Service-Prometheus.html) and [Amazon Managed Grafana](https://docs.aws.amazon.com/grafana/latest/userguide/what-is-Amazon-Managed-Service-Grafana.html) to export metrics about your cluster and cluster-nodes to an Amazon Managed Grafana dashboard. 


In this section, we'll cover how you can use AWS observability solutions integrated with EKS to provide visibility into:

1. Kubernetes Resources in the EKS console view
2. Control Plane and Pod Logs utilizing Fluentbit
3. Monitoring Metrics with CloudWatch Container Insights
4. Monitoring EKS Metrics with AMP and ADOT.


We will specifically cover 2 areas 

1. Container Insights in Amazon CloudWatch
2. AWS managed One-Click Observability using Grafana and Prometheus.
