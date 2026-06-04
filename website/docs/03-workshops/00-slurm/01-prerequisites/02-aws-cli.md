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
