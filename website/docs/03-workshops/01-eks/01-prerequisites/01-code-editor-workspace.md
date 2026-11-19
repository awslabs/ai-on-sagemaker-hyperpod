---
title: Set up Code Editor Workspace
sidebar_position: 1
---

# Set up Code Editor Workspace

## Open AWS Account

Click **"Open AWS console"** located at the bottom left corner of the screen. Ensure you are in the region provided by your workshop guides.

## SageMaker Code Editor

In this workshop we use SageMaker Code Editor as our work environment — a fully integrated development environment (IDE) based on Visual Studio Code.

### Key Features

- **Familiar Layout**: VS Code layout with support for multiple tabs and panels
- **Terminal Access**: Run shell commands directly within the editor
- **Extensions**: Support for VS Code extensions
- **Collaboration**: Share notebooks and code with team members

## Getting Started

A `DefaultUser` has been pre-configured with the right permissions to access your CodeEditor instance and your cluster.

1. Navigate to **"Code Editor"** and click **Launch**
2. Choose your favorite theme
3. Your home directory is: `/home/sagemaker-user/`
4. Open the terminal at the bottom of the screen

:::tip
Press the **"Maximize Panel Size"** button to expand the terminal window.
:::

### Workspace Structure

In your "Explorer" section, you should see:

```
.
├── custom-file-systems
│   └── fsx_lustre
│       └── fs-0bb86b796c3e947e2 -> /mnt/custom-file-systems/fsx_lustre/fs-0bb86b796c3e947e2
├── fsx-shared -> /home/sagemaker-user/custom-file-systems/fsx_lustre/fs-0bb86b796c3e947e2
├── studio-lifecycle-config.log
└── user-default-efs -> /mnt/custom-file-systems/efs/...
```

Key files:
- **`fsx-shared`**: Your FSx Lustre file system mount
- **`fsx-shared/env_vars`**: Pre-configured environment variables for training
- **`studio-lifecycle-config.log`**: Log file of the CodeEditor bootstrapping

## Congratulations! 🎉

With your Code Editor and terminal set up, you are ready to proceed to the Cluster Configuration section.
