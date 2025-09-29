---
title: Installing the required tools
sidebar_position: 1
---

# Installing the required tools

To create and operate your Amazon Sagemaker Hyperpod cluster, you will need to have a few tools installed. The list below includes the minimum required tools you need installed either on your computer or on a Sagemkaer Studio Code Editor instance.

::::expand{header="Install the AWS CLI" defaultExpanded=false}

:::alert{header="Note:"}
The AWS CLI comes pre-installed on AWS CloudShell.
:::

Install the latest version of the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), you'll need version `2.17.47` as a minimum to run the SageMaker HyperPod commands:

::::tabs{variant="container" activeTabId="Linux_x86_64"}

:::tab{id="Linux_x86_64" label="Linux (x86_64)"}
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
```
:::

:::tab{id="Linux_arm64" label="Linux (arm64)"}
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```
:::

:::tab{id="macOS" label="macOS (x86_64 and arm64)"}
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```
:::
::::

::::expand{header="Install kubectl" defaultExpanded=false}
:::alert{header="Note:"}
kubectl comes pre-installed on AWS CloudShell.
:::
You will use kubectl throughout the workshop to interact with the EKS cluster Kubernetes API server. The following commands correspond with Linux installations. See the [Kubernetes documentation](https://kubernetes.io/docs/tasks/tools/) for steps on how to install kubectl on [macOS](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/) or [Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/). 

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.4/2024-09-11/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
```

::::

::::expand{header="Install eksctl" defaultExpanded=false}
You will use eksctl to [create an IAM OIDC provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) for your EKS cluster and install the [Amazon FSx for Lustre CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/fsx-csi.html) in a later step. The following commands correspond with Unix installations. See the [eksctl documentation](https://eksctl.io/installation/) for alternative instilation options. 

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
::::

::::expand{header="Install Helm" defaultExpanded=false}
[Helm](https://helm.sh/) is a package manager for Kubernetes that will be used to istall various dependancies using [Charts](https://helm.sh/docs/topics/charts/), which bundle together all the resources needed to deploy an application to a Kubernetes cluster. 

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```
::::

::::expand{header="Install Terraform" defaultExpanded=false}
If you plan to [use Terraform](/00-setup/workshop-infra-tf/) to deploy the workshop infrastructure, see the [Terraform documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) for instillation instructions. 
::::