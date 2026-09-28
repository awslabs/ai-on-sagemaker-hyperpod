---
title: Configure AWS CLI Credentials
sidebar_position: 2
---

# Configure AWS CLI Credentials

:::caution
If you're using SageMaker Studio Code Editor, the AWS CLI and federated credentials are already set up for you — you can skip this page.
:::

## Install AWS CLI

1. Install the latest version of the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). You'll need version 2.x or later to run the SageMaker HyperPod commands:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
```

2. Check the version is >= 2.x:

```bash
aws --version
```

## Configure Credentials

Choose one of the following options:

### Option A — IAM Identity Center (recommended)

```bash
aws configure sso
```

Follow the prompts to set up SSO access to your account.

### Option B — IAM user credentials

```bash
aws configure
```

Enter your Access Key ID, Secret Access Key, and set the default region to `us-west-2`.

## Required IAM Permissions

Your credentials must have permissions for SageMaker (full access), EC2, S3, CloudFormation, and IAM PassRole. The [`AmazonSageMakerFullAccess`](https://docs.aws.amazon.com/sagemaker/latest/dg/security-iam-awsmanpol.html) managed policy covers most requirements.

## Verify Access

```bash
aws sts get-caller-identity
```

If you see your account ID and ARN, you're ready to proceed.
