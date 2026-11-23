---
title: Set up Code Editor Workspace
sidebar_position: 2
---

# Set up Code Editor workspace

## Open AWS account

Click **Open AWS console** located at the bottom left corner of the Workshop Studio screen.

When you get to the console, please ensure you are in the Region provided to you by your workshop guides. You can change the Region via the dropdown located at the top right of the home page in the console.

## SageMaker Code Editor

In this workshop we will use the SageMaker Code Editor as our work environment, where we look at sources, execute scripts, and interact with our cluster.

SageMaker Code Editor is a fully integrated development environment (IDE) based on Visual Studio Code. It provides a rich set of features for data scientists and developers to build, train, and deploy machine learning models.

### Key features

- **Familiar interface** — VS Code layout with support for multiple tabs and panels.
- **Integrated terminal** — access to a terminal for running shell commands directly within the editor.
- **Extensions** — support for VS Code extensions to enhance functionality.
- **Collaboration** — share notebooks and code with team members easily.

:::note
The crawled source dropped the labels for these four key features; the labels above are reconstructed from their descriptions. See the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/00-setup/01-aws-event) for the exact wording.
:::

## Getting started

For this workshop, we have already configured a `DefaultUser` for you, with the right permissions to access your Code Editor instance (and your cluster).

1. **Launch the space** — your default Code Editor space has already been launched for you. Click on the running space to enter the editor.
2. **Pick a theme** — choose your favorite theme.
3. **Working directory** — `/home/sagemaker-user/`
4. **Open the terminal** — open the terminal at the bottom of the screen.

The command window can be maximized, resized, and split as needed to accommodate your layout preferences as you work on the hands-on lab. Press the **Maximize Panel Size** button to expand the terminal window.

In your **Explorer** section, you should see the following directories and files:

```text
.
├── custom-file-systems
│   └── fsx_lustre
│       └── fs-0bb86b796c3e947e2 -> /mnt/custom-file-systems/fsx_lustre/fs-0bb86b796c3e947e2
├── fsx-shared -> /home/sagemaker-user/custom-file-systems/fsx_lustre/fs-0bb86b796c3e947e2
├── studio-lifecycle-config.log
└── user-default-efs -> /mnt/custom-file-systems/efs/fs-041306ce17511193b_fsap-0d3da2b119db0ff5b
```

A few useful files that are present:

1. `custom-file-systems/fsx_lustre/<fs-id>` — this is where your FSx for Lustre file system is mounted. To demonstrate user partitioning, we have only mounted one sub-directory from the FSx file system onto your Code Editor space.
2. `fsx-shared` — as part of the setup process for this workshop, we have already set a number of environment variables for you to source for your training. This exists under the shared directory (a symbolic link to the long path where the file actually exists on FSx).
3. `fsx-shared/env_vars` — the environment variables that are already configured and sourced for you.
4. `studio-lifecycle-config.log` — log file of the bootstrapping of this Code Editor (VS Code) instance.

:::note
The crawled source dropped the file and directory names this numbered list refers to, along with the mounted sub-directory name. The names above are inferred from the directory tree shown on the page; see the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/00-setup/01-aws-event) to confirm.
:::

If you're optionally looking to learn more about SageMaker, refer to the [AWS SageMaker documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/whatis.html).

## Congratulations!

With your Code Editor and terminal set up, you are ready to proceed to the [cluster configuration](../02-cluster/01-overview.md) section.
