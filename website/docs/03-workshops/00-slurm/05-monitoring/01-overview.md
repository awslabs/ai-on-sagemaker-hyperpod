---
title: Monitoring Overview
sidebar_position: 1
---

# SageMaker HyperPod Monitoring with OS Grafana

:::tip Reference Documentation
For production observability setup, see [Observability on Slurm](/docs/slurm-orchestration/add-ons/observability-slurm).
:::

For this workshop, we use an EC2 instance running an OS Grafana container along with Amazon Managed Service for Prometheus workspace. These resources are deployed using the [cluster-observability-os-grafana.yaml](https://github.com/awslabs/awsome-distributed-ai/blob/main/4.validation_and_observability/4.prometheus-grafana/cluster-observability-os-grafana.yaml) CloudFormation template.

## Deploy the Observability Stack

Download and deploy the CloudFormation template:

```bash
curl -O https://raw.githubusercontent.com/awslabs/awsome-distributed-ai/main/4.validation_and_observability/4.prometheus-grafana/cluster-observability-os-grafana.yaml

aws cloudformation create-stack \
  --stack-name os-observability \
  --template-body file://cluster-observability-os-grafana.yaml \
  --capabilities CAPABILITY_IAM \
  --region us-west-2
```

Wait for the stack to reach `CREATE_COMPLETE` before continuing:

```bash
aws cloudformation wait stack-create-complete --stack-name os-observability --region us-west-2
```

:::note
In a production HyperPod Slurm deployment, customers typically leverage **Amazon Managed Grafana** instead of OS-Grafana. CloudFormation templates located in the [AWSome Distributed AI](https://github.com/awslabs/awsome-distributed-ai/tree/main/4.validation_and_observability/4.prometheus-grafana) repository will orchestrate the deployment of monitoring resources.
:::

## Resources Deployed

- [Amazon Managed Prometheus Workspace](https://aws.amazon.com/prometheus/)
- [Amazon Managed Grafana Workspace](https://aws.amazon.com/grafana/) (or OS Grafana for workshops)
- Associated IAM roles and permissions
