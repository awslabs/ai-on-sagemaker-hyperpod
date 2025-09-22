---
title: "a. Setup Environment Variables"
weight: 1
--- 
:::::alert{header="Note:"}
The `create_config.sh` script checks for existing values of the following environment variable variables before using the default values.
| Environment Variable | Type | Default Value | Description | 
|:---|:---|:---|:---|
|AWS_REGION| string | The default region configured for the AWS CLI |The region where you will deploy your HyperPod cluster|
|ACCEL_INSTANCE_TYPE | string | ml.g5.12xlarge | The accelerated compute instance type you want to use|
|ACCEL_COUNT |integer| 1 |The number of accelerated compute nodes you want to deploy|
|ACCEL_VOLUME_SIZE| integer | 500 (GB) | The size of the EBS volume attached to the accelerated compute nodes| 
|GEN_INSTANCE_TYPE | string | ml.m5.2xlarge |  The general purpose compute instance type you want to use|
|GEN_COUNT |integer| 1 |The number of general purpose compute nodes you want to deploy|
|GEN_VOLUME_SIZE| integer | 500 (GB) | The size of the EBS volume attached to the general purpose compute nodes| 
|NODE_RECOVERY| string | Automatic | Enable node auto-recovery. Set to "None" to disable. |

If you don't want to use the default values, set the environment variables in your bash shell session before running the `create_config.sh` script.

For example, if you want to use another accelerated compute instance type besides `ml.g5.12xlarge`, run one of the following commands: 

::::tabs{variant="container" activeTabId="ml.m5.2xlarge"}

:::tab{id="ml.m5.2xlarge" label="ml.m5.2xlarge (Workshop Studio)"}

```bash 
export ACCEL_INSTANCE_TYPE=ml.m5.2xlarge
```
:::

:::tab{id="ml.trn1.32xlarge" label="ml.trn1.32xlarge"}

```bash 
export ACCEL_INSTANCE_TYPE=ml.trn1.32xlarge
```
:::

:::tab{id="ml.p4d.24xlarge" label="ml.p4d.24xlarge"}

```bash 
export ACCEL_INSTANCE_TYPE=ml.p4d.24xlarge
```
:::

:::tab{id="ml.p5.48xlarge" label="ml.p5.48xlarge"}

```bash 
export ACCEL_INSTANCE_TYPE=ml.p5.48xlarge
```
:::

:::tab{id="ml.g5.8xlarge" label="ml.g5.8xlarge"}

```bash 
export ACCEL_INSTANCE_TYPE=ml.g5.8xlarge
```
:::

::::

If you did not deploy the CloudFormation stack in Full Deployment Mode, ensure that you set the following environment variables prior to running the `create_config.sh` script: 

:::expand{header="Integrative Deployment Mode Environment Variables" defaultExpanded=false}
```bash
export EKS_CLUSTER_ARN=<YOUR_EKS_CLUSTER_ARN_HERE>
export EKS_CLUSTER_NAME=<YOUR_EKS_CLUSTER_NAME_HERE>
```
:::

:::expand{header="Minimal Deployment Mode Environment Variables" defaultExpanded=false}
```bash
export EKS_CLUSTER_ARN=<YOUR_EKS_CLUSTER_ARN_HERE>
export EKS_CLUSTER_NAME=<YOUR_EKS_CLUSTER_NAME_HERE>
export VPC_ID=<YOUR_VPC_ID_HERE>
export SUBNET_ID=<YOUR_SUBNET_ID_HERE>
export SECURITY_GROUP=<YOUR_SECURITY_GROUP_ID_HERE>
```
:::

:::::

1. First source in all the environment variables you need leveraging the output from the previously deployed CloudFormation stack:

```bash
curl ':assetUrl{path="/scripts/create_config.sh" source=repo}' --output create_config.sh
export STACK_ID=hyperpod-eks-full-stack
bash create_config.sh
source env_vars
```

2. Confirm all the environment variables were correctly set:

```bash
cat env_vars
```

```
export AWS_REGION=us-west-2
export EKS_CLUSTER_ARN=arn:aws:eks:us-west-2:xxxxxxxxxxxx:cluster/hyperpod-eks-cluster
export EKS_CLUSTER_NAME=hyperpod-eks-cluster
export BUCKET_NAME=hyperpod-eks-bucket-xxxxxxxxxxxx-us-west-2
export EXECUTION_ROLE=arn:aws:iam::xxxxxxxxxxxx:role/hyperpod-eks-ExecutionRole-us-west-2
export VPC_ID=vpc-0540e3cb2868504a8
export SUBNET_ID=subnet-04a1f33d5a614cc2d
export SECURITY_GROUP=sg-027f21f3e936f71bb
export ACCEL_INTANCE_TYPE=ml.g5.12xlarge
export ACCEL_COUNT=1
export ACCEL_VOLUME_SIZE=500
export GEN_INTANCE_TYPE=ml.m5.2xlarge
export GEN_COUNT=1
export GEN_VOLUME_SIZE=500
export NODE_RECOVERY=Automatic
```

3. Download the default lifecycle script `on_create.sh` from GitHub, and upload it to your S3 bucket: 
```bash 
curl https://raw.githubusercontent.com/aws-samples/awsome-distributed-training/main/1.architectures/7.sagemaker-hyperpod-eks/LifecycleScripts/base-config/on_create.sh --output on_create.sh

aws s3 cp on_create.sh s3://$BUCKET_NAME
```
This lifecycle script doesn't perform any actions yet, it's simply used as a placeholder for now. 
