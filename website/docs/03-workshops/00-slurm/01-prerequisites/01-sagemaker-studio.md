---
title: SageMaker Studio IDE
sidebar_position: 1
---

# SageMaker Studio IDE

:::warning SageMaker Domain Required
Code Editor runs inside **Amazon SageMaker Studio**, which requires a [SageMaker AI domain](https://docs.aws.amazon.com/sagemaker/latest/dg/gs-studio-onboard.html) and a user profile. If you don't have a domain set up in your account, you must create one before using Code Editor.
:::

For this workshop, we'll use [SageMaker Studio Code Editor](https://docs.aws.amazon.com/sagemaker/latest/dg/code-editor.html) for convenience. It's a fully integrated development environment (IDE) based on Visual Studio Code that provides a ready-to-use environment in the cloud with the AWS CLI and federated account credentials already set up for you.

:::tip Don't have SageMaker Studio set up?
You can complete this entire workshop from your local machine using the AWS CLI. Just follow the [Configure AWS CLI](./02-aws-cli.md) instructions and skip this page.
:::

## Prerequisites for Code Editor

Before using Code Editor, verify the following:

1. **SageMaker AI Domain** — You must have an active domain in your account. If not, follow the [Quick Setup](https://docs.aws.amazon.com/sagemaker/latest/dg/onboard-quick-start.html) guide to create one (takes ~5 minutes).
2. **User Profile** — Your IAM identity must have a [user profile](https://docs.aws.amazon.com/sagemaker/latest/dg/domain-user-profile.html) within the domain.
3. **Service Quotas** — Code Editor runs on a compute instance (default: `ml.t3.medium`). Ensure your account has available quota for the [instance type](https://docs.aws.amazon.com/general/latest/gr/sagemaker.html#limits_sagemaker) in your target region (`us-west-2`).

## Key Features

- **Familiar Layout**: VS Code layout with support for multiple tabs and panels.
- **Terminal Access**: Integrated terminal for running shell commands with pre-configured AWS credentials.
- **Extensions**: Support for VS Code extensions to enhance functionality.
- **AWS CLI Pre-installed**: No additional credential configuration required — federated credentials are automatically available.

## Getting Started

1. *(If needed)* [Create a SageMaker domain](https://docs.aws.amazon.com/sagemaker/latest/dg/onboard-quick-start.html) via Quick Setup.
2. Navigate to your [SageMaker Studio](https://console.aws.amazon.com/sagemaker/home?#/studio-landing) console.
3. Click **"Open Studio"**.
4. From the launcher, navigate to **"Code Editor"** and click **"Open"** (or create a new Code Editor space).
5. Choose your favorite theme.
6. Open the terminal at the bottom of the screen.

:::note
If the "Code Editor" option is not visible, ensure your user profile has the appropriate [execution role permissions](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-roles.html) and that your domain allows Code Editor spaces.
:::

For more detailed information, refer to the [Code Editor documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/code-editor.html).
