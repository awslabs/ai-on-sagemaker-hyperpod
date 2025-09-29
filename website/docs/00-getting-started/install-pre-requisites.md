---
title: Installing the required tools
sidebar_position: 1
---

# Installing the required tools

Before getting started with SageMaker HyperPod, we will configure our environment with the required tools. 

:::tip{header="Install AWS CLI"}
For a cloud based IDE that comes pre-installed with the AWS CLI and Kubectl, you can use [AWS Cloud Shell](https://console.aws.amazon.com/cloudshell/home) or SageMaker Studio Code Editor
:::


### Configure your local terminal

<details>
<summary>Install the AWS CLI</summary>

1. Install the latest version of the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), it is recommended to use the latest version of the AWS CLI to get the latest command line expierence for SageMaker HyperPod - as of OCT 2025, we recommend using version `2.31.3` or later.

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

<Tabs>
  <TabItem value="linux-x86" label="Linux (x86_64)">
    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install --update
    ```
  </TabItem>
  <TabItem value="linux-arm" label="Linux (arm64)">
    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    ```
  </TabItem>
  <TabItem value="macos" label="macOS (x86_64 and arm64)">
    ```bash
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
    ```
  </TabItem>
</Tabs>

2. Confirm your AWS CLI Version. It should show `2.31.3` or later

```bash
aws --version
```

3. Now you should be able to run :

```bash
aws sagemaker help | grep cluster
```

You'll see the following commands available

```
       o attach-cluster-node-volume
       o batch-add-cluster-nodes
       o batch-delete-cluster-nodes
       o create-cluster
       o create-cluster-scheduler-config
       o delete-cluster
       o delete-cluster-scheduler-config
       o describe-cluster
       o describe-cluster-event
       o describe-cluster-node
       o describe-cluster-scheduler-config
       o detach-cluster-node-volume
       o list-cluster-events
       o list-cluster-nodes
       o list-cluster-scheduler-configs
       o list-clusters
       o update-cluster
       o update-cluster-scheduler-config
       o update-cluster-software
```
</details>

<details>
<summary>Configuring AWS Credentials</summary>

Please refer to [this documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html) to understand the different ways to acquire AWS Credentials to use AWS CLI.

For simplicity and to demonstrate the process of configuring AWS credentials for the CLI, we are going to use long-term access keys for designated IAM Users.

:::caution Important
To maintain a proper security posture we recommend either using short-term credentials or setting up AWS IAM Identity Center (formerly AWS SSO) for short-term credentials.
:::

**1. Acquire AWS access long-term credentials**

Please visit [this documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html#cli-authentication-user-get) to learn how to acquire these credentials from the AWS console.

**2. Configure AWS CLI**

Using the credentials you fetched above, use `aws configure` to add the credentials to your terminal. See [configure aws credentials]https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html#cli-authentication-user-configure.title) for more details.

```bash
aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

3. Next you can over-ride the environment variable set above for `AWS_REGION` to ensure it point's to the region where you intend to stand up your infrastructure. AWS CLI provides command line arguments as [documented here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-options.html) to override certain variables.

```bash
export AWS_REGION=us-west-2
```

For more information on the aws configure cli command please refer to this [CLI reference documentation](https://docs.aws.amazon.com/cli/latest/reference/configure/) 

</details>


<details>
<summary>Install Kubectl (for EKS only)</summary>

You will use kubectl throughout the workshop to interact with the EKS cluster Kubernetes API server. The following commands correspond with **Linux installations**. See the [Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/) for official steps on how to install kubectl. 


<Tabs>
  <TabItem value="linux-x86" label="Linux (x86_64)">
    ```bash
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    # If valid, output is kubectl: OK
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    ```
    > Note: If you do not have root access on the target system, you can still install kubectl to the `~/.local/bin` directory: 

    ```bash
    chmod +x kubectl
    mkdir -p ~/.local/bin
    mv ./kubectl ~/.local/bin/kubectl
    # and then append (or prepend) ~/.local/bin to $PATH
    ```

    Test to ensure the version you installed is up-to-date:

    ```bash
    kubectl version --client
    ```
  </TabItem>
  <TabItem value="linux-arm" label="Linux (arm64)">
    ```bash
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    # If valid, output is kubectl: OK
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    ```
     > Note: If you do not have root access on the target system, you can still install kubectl to the `~/.local/bin` directory: 

    ```bash
    chmod +x kubectl
    mkdir -p ~/.local/bin
    mv ./kubectl ~/.local/bin/kubectl
    # and then append (or prepend) ~/.local/bin to $PATH
    ```

    Test to ensure the version you installed is up-to-date:

    ```bash
    kubectl version --client
    ```
  </TabItem>
  <TabItem value="macos" label="macOS (arm64)">
    
    ```bash
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | shasum -a 256 --check
    # If valid, output is kubectl: OK
    
    # make the kubectl binary executable:
    chmod +x ./kubectl
    # move the kubectl binary to a file location on your system PATH
    sudo mv ./kubectl /usr/local/bin/kubectl
    sudo chown root: /usr/local/bin/kubectl
    ```
    Test to ensure the version you installed is up-to-date:

    ```bash
    kubectl version --client
    ```
    After installing and validating kubectl, delete the checksum file:
    ```bash
    rm kubectl.sha256
    ```
  </TabItem>
</Tabs>

</details>

<details>
<summary>Install Helm (for EKS only)</summary>
[Helm](https://helm.sh/) is a package manager for Kubernetes that will be used to install various dependancies using [Charts](https://helm.sh/docs/topics/charts/) , which bundle together all the resources needed to deploy an application to a Kubernetes cluster.

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

</details>

<details>
<summary>Install eksctl (for EKS only)</summary>

You can use eksctl to [create an IAM OIDC provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) and install CSI drivers. The following commands correspond with Unix installations. See the [eksctl documentation](https://docs.aws.amazon.com/eks/latest/eksctl/installation.html) for alternative instillation options.

```bash
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin
```

</details>

<details>
<summary>Install Terraform</summary>

If you plan to use Terraform to deploy the workshop infrastructure, see the [Terraform documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

</details>

# DEPRECATED - move into IaC alternatives
::::expand{header="Install Terraform" defaultExpanded=false}
If you plan to [use Terraform](/docs/infrastructure-as-a-code/terraform/) to deploy the workshop infrastructure, see the [Terraform documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) for instillation instructions. 
::::