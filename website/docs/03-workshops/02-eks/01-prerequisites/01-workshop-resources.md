---
title: Workshop Resources
sidebar_position: 1
---

# Workshop Resources

:::tip Reference Documentation
For step-by-step instructions on standing up a HyperPod cluster orchestrated by EKS, see [Initial Cluster Setup](/docs/eks-orchestration/getting-started/initial-cluster-setup) and [Set up your shared file system](/docs/eks-orchestration/getting-started/Set%20up%20your%20shared%20file%20system).
:::

During this workshop, you'll be leveraging several different cloud resources:

- **SageMaker HyperPod cluster**: HyperPod provides built-in health checks and resiliency capabilities that facilitate automatic node recovery and training job auto-resume features, allowing you to run model development workloads for months without disruption.
- **Amazon EKS cluster**: This managed Kubernetes control plane will act as an orchestrator for the HyperPod compute nodes. Users will access the managed Kubernetes API server endpoint exposed by EKS to run ML workloads on HyperPod instance groups.
- **Accelerated compute nodes**: This workshop uses 2 x accelerated compute nodes. HyperPod also supports the EC2 instance types listed in [the tables below](#ec2-instance-types). These compute nodes are created as HyperPod instance groups then automatically added as nodes to the target EKS cluster for ML workload orchestration. [EFA-enabled instance types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types) can be used to get the best inter-node latency and maximize bandwidth between nodes.
- **FSx for Lustre file system**: This is a shared file system that all the HyperPod nodes can access, mounted at `/fsx`. This file system can be provisioned statically before launching your HyperPod cluster or dynamically using the [FSx for Lustre CSI driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver).
- **Amazon S3 bucket**: An S3 bucket is used to store the lifecycle script for instance group configuration, as well as to store training data that can be accessed in parallel through [FSx for Lustre data repository associations (DRAs)](https://docs.aws.amazon.com/fsx/latest/LustreGuide/create-dra-linked-data-repo.html). An [S3 Mountpoint](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mountpoint.html) can also be configured to enable high-throughput mounting of an S3 bucket as a local file system.
- **VPC and private subnet**: This /16 subnet is used to host the Elastic Network Interfaces (ENIs) that provide network access to the HyperPod cluster and the FSx for Lustre file system.
- **Security group**: This security group allows the EKS control plane to communicate with the HyperPod worker nodes while also allowing us to mount our FSx for Lustre file system. This security group is also configured for [Elastic Fabric Adapter (EFA)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html) network devices, allowing all inbound and outbound traffic to and from itself.
- **SageMaker Studio domain with a Code Editor space**: This gives us a standardized development environment to work from.

In addition to these **hardware resources**, we use the following software features from SageMaker HyperPod to orchestrate our ML training (and inference) workloads today:

- The [HyperPod training operator](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-eks-operator.html) — see also [HyperPod Training Operator overview](/docs/eks-orchestration/add-ons/hp-training-operator/overview)
- The HyperPod inference operator — see also [SageMaker JumpStart on the inference operator](/docs/eks-orchestration/inference/inference-operator/sagemaker-jumpstart)
- [HyperPod task governance](/docs/eks-orchestration/add-ons/Task%20Governance/Task%20Governance%20for%20Training)

## Our Workshop

Since you will be training this model from scratch, together with us, you may proceed to [the next sub-section](./02-code-editor-workspace.md) once the resources above are in place.

For this workshop you need all of the aforementioned resources: a HyperPod cluster with 2 x `ml.g5.2xlarge` instances, Amazon EKS as the orchestrator, an FSx for Lustre file system with the dataset downloaded, and a SageMaker Studio domain with a Code Editor instance for your access.

## Optional Reads

For more information on some topics mentioned above, feel free to refer to the resources below.

### EC2 Instance Types

See the tables below for the specifications of the various instances that can be deployed in the HyperPod cluster:

#### AWS Trainium Instances

| Instance Size | Trainium Accelerators | Accelerator Memory (GB) | vCPUs | Memory (GiB) | EFA Network Bandwidth (Gbps) | [On-Demand Price* (per hour)](https://aws.amazon.com/sagemaker/pricing/) |
|---|---|---|---|---|---|---|
| ml.trn1.32xlarge | 16 | 512 | 128 | 512 | 800 | $24.73 |

#### NVIDIA GPU Instances

| Instance Size | GPUs | GPU Memory (GB) | vCPUs | Memory | EFA Network Bandwidth (Gbps) | [On-Demand Price* (per hour)](https://aws.amazon.com/sagemaker/pricing/) |
|---|---|---|---|---|---|---|
| ml.g5.2xlarge | 1 NVIDIA A10G | 24 GDDR6 | 8 | 32 GiB | N/A | $1.515 |
| ml.g5.8xlarge | 1 NVIDIA A10G | 24 GDDR6 | 32 | 128 GiB | 25 | $3.06 |
| ml.g5.16xlarge | 1 NVIDIA A10G | 24 GDDR6 | 64 | 256 GiB | N/A | $5.12 |
| ml.g5.12xlarge | 4 NVIDIA A10Gs | 96 GDDR6 | 48 | 192 GiB | 40 | $7.09 |

Other commonly used NVIDIA GPU Accelerated EC2 Instances for distributed training:

| Instance Size | GPUs | GPU Memory (GB) | vCPUs | Memory | EFA Network Bandwidth (Gbps) | [On-Demand Price* (per hour)](https://aws.amazon.com/sagemaker/pricing/) |
|---|---|---|---|---|---|---|
| ml.p4d.24xlarge | 8 NVIDIA A100s | 320 HBM2 | 96 | 1152 GiB | 400 | $25.910 |
| ml.p5.48xlarge | 8 NVIDIA H100s | 640 HBM3 | 192 | 2 TiB | 3200 | $66.048 |
| ml.p5e.48xlarge | 8 NVIDIA H200s | 1128 HBM3e | 192 | 2 TiB | 3200 | $72.795 |
| ml.p5en.48xlarge | 8 NVIDIA H200s | 1128 HBM3e | 192 | 2 TiB | 3200 | $72.795 |
| ml.p6-b200.48xlarge | 8 NVIDIA B200s | 1432 HBM3e | 192 | 2048 GiB | 3200 | $131.023 |

This table does not include ultraservers (GB200, for example).

### Supported Kubernetes Versions

See the [HyperPod release notes](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-release-notes.html) for the most up-to-date information about supported Kubernetes versions.

When you create your SageMaker HyperPod cluster, SageMaker HyperPod selects an Amazon Machine Image (AMI) corresponding to the Kubernetes version of your Amazon EKS cluster.

:::note
The Kubernetes version of SageMaker HyperPod cluster nodes does not automatically update when you update your Amazon EKS cluster version. After updating the Kubernetes version for your Amazon EKS cluster, you must use the `UpdateClusterSoftware` API to update your SageMaker HyperPod cluster nodes to the same Kubernetes version. See the [Update HyperPod Platform Software](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-cli-command-update-cluster-software.html) documentation for more details.
:::

### Clean Up

Running these resources in your own account incurs cost, so remember to clean up when you are done. The [Cleanup](../06-cleanup.md) section at the end of this workshop walks through it, and the [delete-cluster CLI reference](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-cli-command-delete-cluster.html) documents the cluster deletion command.
