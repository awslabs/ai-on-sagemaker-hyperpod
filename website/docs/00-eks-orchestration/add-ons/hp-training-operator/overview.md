---
title: "HyperPod Training Operator Overview"
sidebar_position: 1
---

# HyperPod Training Operator Overview

The Amazon SageMaker HyperPod training operator helps you accelerate generative AI model development by efficiently managing distributed training across large GPU clusters. It introduces intelligent fault recovery, hang job detection, and process-level management capabilities that minimize training disruptions and reduce costs.

For more information on our docs, please see [Using the HyperPod training operator](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-eks-operator.html)

## Key Features

### Intelligent Fault Recovery
Unlike traditional training infrastructure that requires complete job restarts when failures occur, this operator implements surgical process recovery to keep your training jobs running smoothly. The operator can restart individual processes or containers without affecting the entire distributed training job.

### Hang Job Detection
The operator provides automated monitoring of critical metrics like loss spikes and throughput degradation through configurable log monitoring rules. You can define recovery policies through simple YAML configurations without code changes, allowing you to quickly respond to and recover from unrecoverable training states.

### Process-Level Management
The HyperPod training operator works at the process level, providing fine-grained control over distributed training workloads. This enables more efficient resource utilization and faster recovery from failures.

### Integration with HyperPod Ecosystem
The operator integrates seamlessly with HyperPod's health monitoring and observability functions, providing real-time visibility into training execution. These monitoring and recovery capabilities work together to maintain optimal training performance while minimizing operational overhead.

## Architecture Components

### HyperPod Elastic Agent
The HyperPod elastic agent is an extension of PyTorch's ElasticAgent that orchestrates lifecycles of training workers on each container and communicates with the HyperPod training operator. It must be installed in your training image before submitting jobs.

### Training Operator Controller
The controller manages the lifecycle of distributed training jobs, handles fault detection and recovery, and coordinates with Kubernetes to manage pod resources.

### Log Monitoring System
Advanced log monitoring capabilities that can detect various training issues:
- Job hanging detection
- Training loss spikes
- Low throughput detection
- Checkpoint upload failures

## Supported Versions

The HyperPod training operator works only with specific versions of components:

- **Kubernetes versions**: 1.28, 1.29, 1.30, 1.31, or 1.32
- **Suggested Kueue versions**: v0.12.2 and v0.12.3
- **HyperPod AMI**: Latest release (use UpdateClusterSoftware API to upgrade)
- **PyTorch**: 2.4.0 – 2.7.1

## Optional Integrations

### Kueue Integration
While Kueue is not required for the training operator, your cluster administrator can install and configure it for enhanced job scheduling capabilities. The operator supports external framework integration with Kueue for resource allocation and job queuing.

### Task Governance Integration
The training operator is integrated with HyperPod task governance, a robust management system designed to streamline resource allocation and ensure efficient utilization of compute resources across teams and projects. Task governance requires version v1.3.0-eksbuild.1 or higher.

## Monitoring and Observability

The operator provides comprehensive metrics that can be scraped by Amazon Managed Service for Prometheus:

- `hyperpod_training_operator_jobs_created_total`: Total number of jobs created
- `hyperpod_training_operator_jobs_restart_latency`: Current job restart latency
- `hyperpod_training_operator_jobs_fault_detection_latency`: Fault detection latency
- `hyperpod_training_operator_jobs_deleted_total`: Total number of deleted jobs
- `hyperpod_training_operator_jobs_successful_total`: Total number of completed jobs
- `hyperpod_training_operator_jobs_failed_total`: Total number of failed jobs
- `hyperpod_training_operator_jobs_restarted_total`: Total number of auto-restarted jobs

## Prerequisites

Before using the HyperPod training operator, ensure you have:

1. **HyperPod Cluster**: Created a HyperPod cluster with Amazon EKS orchestration
2. **Latest AMI**: Installed the latest AMI on your HyperPod cluster
3. **Cert-Manager**: Installed cert-manager in your cluster
4. **EKS Pod Identity Agent**: Set up using the console or AWS CLI

## Next Steps

To get started with the HyperPod training operator:

1. Review the [Installation and Usage Guide](./installation-and-usage.md)
2. Install the operator through the SageMaker AI console, Amazon EKS console, or AWS CLI
3. Configure your training images with the HyperPod elastic agent
4. Submit your first distributed training job

The HyperPod training operator represents a significant advancement in managing distributed training workloads, providing the reliability and efficiency needed for large-scale generative AI model development.