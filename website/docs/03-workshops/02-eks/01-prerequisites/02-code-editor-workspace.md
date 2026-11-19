---
title: Set up Code Editor Workspace
sidebar_position: 2
---

# Set up Code Editor Workspace

:::warning SageMaker Domain Required
Code Editor runs inside **Amazon SageMaker Studio**, which requires a [SageMaker AI domain](https://docs.aws.amazon.com/sagemaker/latest/dg/gs-studio-onboard.html) and a user profile. If you don't have a domain set up in your account, you must create one before using Code Editor. See [SageMaker Studio integration](/docs/eks-orchestration/getting-started/sagemaker-studio-integration) for how to wire a Studio space up to a HyperPod EKS cluster.
:::

## Open the AWS Console

Sign in to the AWS console and make sure you are in the region where your HyperPod cluster is deployed (this workshop uses `us-west-2`). You can change the region via the dropdown located at the top right of the home page in the console.

## SageMaker Code Editor

In this workshop we will use the SageMaker Code Editor as our work environment where we look at sources, execute scripts, and interact with our cluster.

SageMaker Code Editor is a fully integrated development environment (IDE) based on Visual Studio Code. It provides a rich set of features for data scientists and developers to build, train, and deploy machine learning models.

### Key Features

- **Familiar Layout**: Familiar VS Code layout with support for multiple tabs and panels.
- **Terminal Access**: Access to a terminal for running shell commands directly within the editor.
- **Extensions**: Support for VS Code extensions to enhance functionality.
- **Collaboration**: Share notebooks and code with team members easily.

:::tip Don't have SageMaker Studio set up?
You can complete this workshop from your local machine or any terminal with the AWS CLI and `kubectl` configured against your EKS cluster. See [Verifying cluster connection to EKS](/docs/eks-orchestration/getting-started/Verifying%20cluster%20connection%20to%20EKS) for how to configure `kubectl` access.
:::

## Getting Started

You need a user profile in your SageMaker domain with the right permissions to access your Code Editor instance (and your cluster).

1. **Launch a Code Editor space**: Navigate to your [SageMaker Studio](https://console.aws.amazon.com/sagemaker/home?#/studio-landing) console, click **Open Studio**, then create (or open) a Code Editor space. Click on the running space to enter the editor.
2. **Choose your favorite theme.**
3. **Note your home directory**: `/home/sagemaker-user/`
4. **Open the terminal** at the bottom of the screen.

The command window can be maximized, resized, and split as needed to accommodate your layout preferences as you work on the hands-on lab.

Press the "Maximize Panel Size" button to expand the terminal window.

In your "Explorer" section, you should see directories and files similar to the following (file system IDs will differ in your account):

```
.
├── custom-file-systems
│   └── fsx_lustre
│       └── fs-0bb86b796c3e947e2 -> /mnt/custom-file-systems/fsx_lustre/fs-0bb86b796c3e947e2
├── fsx-shared -> /home/sagemaker-user/custom-file-systems/fsx_lustre/fs-0bb86b796c3e947e2
├── studio-lifecycle-config.log
└── user-default-efs -> /mnt/custom-file-systems/efs/fs-041306ce17511193b_fsap-0d3da2b119db0ff5b
```

A few useful files that are present:

1. **`custom-file-systems/fsx_lustre/<fs-id>`**: This is where your FSx for Lustre file system is mounted. To demonstrate user partitioning, only one sub-directory from the FSx file system is mounted onto your Code Editor space.
2. **`fsx-shared`**: A symbolic link to the mounted FSx for Lustre sub-directory. This is where the `env_vars` file lives — a set of environment variables you source for your training.
3. **`fsx-shared/env_vars`**: The environment variables used throughout this workshop (see the [Verify Cluster Connection](../02-cluster-setup/03-verify-cluster-connection.md) page for the full list and how to source them).
4. **`studio-lifecycle-config.log`**: Log file of the bootstrapping of this Code Editor (VS Code) instance.

:::note Setting up the environment variables yourself
In an AWS-hosted event these variables are pre-created and sourced for you by a Studio lifecycle configuration. Running the workshop in your own account, you create `fsx-shared/env_vars` yourself and `source` it in each new terminal. The next section lists every variable and its value.
:::

If you're optionally looking to learn more about SageMaker, refer to the [AWS SageMaker Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/whatis.html).

## Congratulations!

With your Code Editor and terminal set up, you are ready to proceed to the [Cluster Configuration](../02-cluster-setup/01-overview.md) section.
