# EKS Workshop - Self-Deployment Guide

This directory contains all infrastructure assets needed to deploy the SageMaker HyperPod EKS workshop ("Project Helix") in your own AWS account.

## Prerequisites

- AWS CLI v2+ configured with appropriate permissions
- An AWS account with service quotas for ml.g5.2xlarge instances (minimum 2)
- Sufficient IAM permissions to create VPCs, EKS clusters, SageMaker resources, and Lambda functions

## Directory Structure

```
workshops/eks/
├── README.md                    ← This file
├── cloudformation/              ← CloudFormation templates for full stack deployment
├── scripts/                     ← Bootstrap and training scripts
├── docker/                      ← Dockerfiles for training containers
├── lambda/                      ← Lambda function packages (custom resources)
├── config/                      ← IAM trust policies and Python requirements
└── data/
    └── README.md                ← Instructions to download large dataset files (~2 GB)
```

## Deployment Steps

### 1. Upload Assets to S3

Upload the Lambda packages and data files to an S3 bucket in your target region:

```bash
BUCKET=your-workshop-bucket
REGION=us-west-2

aws s3 cp lambda/function.zip s3://$BUCKET/workshop-assets/
aws s3 cp lambda/lambda-layer.zip s3://$BUCKET/workshop-assets/
```

### 2. Upload Training Data

See `data/README.md` for instructions on obtaining and uploading the training datasets.

### 3. Deploy the Infrastructure Stack

The `main-stack.yaml` orchestrates all nested stacks. Deploy it via CloudFormation:

```bash
aws cloudformation create-stack \
  --stack-name sagemaker-hyperpod-eks-workshop \
  --template-body file://cloudformation/main-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameters \
    ParameterKey=S3BucketName,ParameterValue=$BUCKET \
    ParameterKey=Region,ParameterValue=$REGION \
  --region $REGION
```

Alternatively, use the full-stack template for a single-stack deployment:

```bash
aws cloudformation create-stack \
  --stack-name sagemaker-hyperpod-eks-workshop \
  --template-body file://cloudformation/hyperpod-eks-full-stack-v2.yaml \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --region $REGION
```

### 4. Run the Workshop

Once the stack is complete (~20 minutes), follow the workshop guide at:
`website/docs/03-workshops/01-eks/`

## CloudFormation Templates

| Template | Purpose |
|----------|---------|
| `main-stack.yaml` | Parent stack that orchestrates nested stacks |
| `vpc-stack.yaml` | VPC with public/private subnets |
| `private-subnet-stack.yaml` | Additional private subnets |
| `security-group-stack.yaml` | Security groups for cluster communication |
| `eks-cluster-stack.yaml` | Amazon EKS cluster |
| `hyperpod-cluster-stack.yaml` | SageMaker HyperPod cluster |
| `fsx-lustre-stack.yaml` | FSx for Lustre file system |
| `sagemaker-studio-stack.yaml` | SageMaker Studio domain and user |
| `sm-studio-domain-hyperpod.yaml` | Studio domain with HyperPod integration |
| `studio-fsx-mount.yaml` | FSx mount in Studio Code Editor |
| `sagemaker-iam-role-stack.yaml` | IAM roles for SageMaker |
| `s3-bucket-stack.yaml` | S3 bucket for lifecycle scripts |
| `s3-endpoint-stack.yaml` | S3 VPC endpoint |
| `helm-chart-stack.yaml` | Helm chart installation via Lambda |
| `lifecycle-script-stack.yaml` | HyperPod lifecycle scripts |
| `management-instance-stack.yaml` | EC2 management instance |
| `hyperpod-observability.yaml` | CloudWatch observability setup |
| `hyperpod-eks-full-stack-v2.yaml` | Single-stack alternative deployment |
| `cleanup-stack.yaml` | Resource cleanup |

## Cleanup

To tear down all resources:

```bash
aws cloudformation delete-stack \
  --stack-name sagemaker-hyperpod-eks-workshop \
  --region $REGION
```

Or deploy the cleanup stack if you need to remove resources that were created outside of CloudFormation:

```bash
aws cloudformation create-stack \
  --stack-name workshop-cleanup \
  --template-body file://cloudformation/cleanup-stack.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION
```
