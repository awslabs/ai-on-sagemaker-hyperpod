---
title: Monitoring Overview
sidebar_position: 1
---

# SageMaker HyperPod Monitoring with OS Grafana

:::tip Reference Documentation
For production observability setup, see [Observability on Slurm](/docs/slurm-orchestration/add-ons/observability-slurm).
:::

For this workshop, we use an EC2 instance running an OS Grafana container along with Amazon Managed Service for Prometheus workspace. These resources were pre-provisioned using the [cluster-observability-os-grafana.yaml](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/4.prometheus-grafana/cluster-observability-os-grafana.yaml) CloudFormation template.

:::warning Self-Paced Users
If you're running outside Workshop Studio, you need to deploy the observability stack yourself before proceeding:

```bash
aws cloudformation create-stack \
  --stack-name os-observability \
  --template-url https://raw.githubusercontent.com/aws-samples/awsome-distributed-training/main/1.architectures/5.sagemaker-hyperpod/cfn-templates/cluster-observability-os-grafana.yaml \
  --capabilities CAPABILITY_IAM \
  --region us-west-2
```

Wait for the stack to reach `CREATE_COMPLETE` before continuing.
:::

:::note
In a production HyperPod Slurm deployment, customers typically leverage **Amazon Managed Grafana** instead of OS-Grafana. CloudFormation templates located in the [AWSome Distributed Training](https://github.com/aws-samples/awsome-distributed-training/tree/main/4.validation_and_observability/4.prometheus-grafana) repository will orchestrate the deployment of monitoring resources.
:::

## Resources Deployed

- [Amazon Managed Prometheus Workspace](https://aws.amazon.com/prometheus/)
- [Amazon Managed Grafana Workspace](https://aws.amazon.com/grafana/) (or OS Grafana for workshops)
- Associated IAM roles and permissions
