---
title: Configure AWS CLI Credentials
sidebar_position: 2
---

# Configure AWS CLI Credentials on Your Local Machine (Optional)

:::caution
You only need this section if you want to work on your own computer. If you're using SageMaker Studio Code Editor (recommended), you can skip this part.
:::

## Install AWS CLI

1. First install the latest version of the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), you'll need version 2.x or later to run the SageMaker HyperPod commands:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
```

2. Check the version is >= 2.x:

```bash
aws --version
```

## Acquire AWS Temporary Access Credentials from Workshop Studio

From the workshop event page select **"Get AWS CLI Credentials"**.

Copy and paste the keys from Workshop Studio into your local terminal. You should now have CLI access to the Workshop Studio account. You can verify by running:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=OS-Grafana" \
  --query 'Reservations[].Instances[].{ID: InstanceId, State: State.Name, Type: InstanceType, PrivateIP: PrivateIpAddress, PublicIP: PublicIpAddress, LaunchTime: LaunchTime}' \
  --output table
```

Once you see the output with your instance details, you are ready to proceed with the next steps.

## Self-Paced Users (Running Outside Workshop Studio)

:::tip Running outside Workshop Studio?
If you're running this workshop in your own AWS account (not via AWS Workshop Studio), you'll need to configure credentials manually:

1. **Option A — IAM Identity Center (recommended):**
   ```bash
   aws configure sso
   ```
   Follow the prompts to set up SSO access to your account.

2. **Option B — IAM user credentials:**
   ```bash
   aws configure
   ```
   Enter your Access Key ID, Secret Access Key, and set the default region to `us-west-2`.

**Required IAM permissions:** Your credentials must have permissions for SageMaker (full access), EC2, S3, CloudFormation, and IAM PassRole. The [`AmazonSageMakerFullAccess`](https://docs.aws.amazon.com/sagemaker/latest/dg/security-iam-awsmanpol.html) managed policy covers most requirements.

You can verify access by running:
```bash
aws sts get-caller-identity
```
:::
