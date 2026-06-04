---
title: Monitoring Overview
sidebar_position: 1
---

# SageMaker HyperPod Monitoring with OS Grafana

For this workshop, we use an EC2 instance running an OS Grafana container along with Amazon Managed Service for Prometheus workspace. These resources were pre-provisioned using the [cluster-observability-os-grafana.yaml](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/4.prometheus-grafana/cluster-observability-os-grafana.yaml) CloudFormation template.

:::note
In a production HyperPod Slurm deployment, customers typically leverage **Amazon Managed Grafana** instead of OS-Grafana. CloudFormation templates located in the [AWSome Distributed Training](https://github.com/aws-samples/awsome-distributed-training/tree/main/4.validation_and_observability/4.prometheus-grafana) repository will orchestrate the deployment of monitoring resources.
:::

## Resources Deployed

- [Amazon Managed Prometheus Workspace](https://aws.amazon.com/prometheus/)
- [Amazon Managed Grafana Workspace](https://aws.amazon.com/grafana/) (or OS Grafana for workshops)
- Associated IAM roles and permissions
