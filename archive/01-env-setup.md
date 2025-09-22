---
title : "a. Set Up Your Development Environment"
weight : 1
---

**Option 1: Deploy SageMaker Studio Code Editor**

If you need a linux based development environment to use for interacting with the HyperPod cluster, click the button below to deploy a CloudFormation stack that will provision a [SageMaker Studio Code Editor](https://docs.aws.amazon.com/sagemaker/latest/dg/code-editor.html) environment for you: 

:button[Deploy SageMaker Studio Code Editor Stack]{variant="primary" href="https://console.aws.amazon.com/cloudformation/home?#/stacks/quickcreate?templateURL=https://ws-assets-prod-iad-r-pdx-f3b3f9f1a7d6a3d0.s3.us-west-2.amazonaws.com/2433d39e-ccfe-4c00-9d3d-9917b729258e/sagemaker-studio-stack.yaml&stackName=sagemaker-studio-stack" external="true"}


SageMaker Code Editor is a fully integrated development environment (IDE) based on Visual Studio Code. It provides a rich set of features for data scientists and developers to build, train, and deploy machine learning models.

See the [At an AWS Event](/00-setup/01-aws-event.md) section for details on how to get started once the stack is successfully deployed. 

---
**Option 2: Use Your Own Environment**

If you wish to use your own linux based development environment, please ensure that you have the following tools installed: 

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

::::expand{header="Review Your IAM Permissions" defaultExpanded=false}
The following procedure shows you how to attach an IAM policy with the required permissions to manage HyperPod on EKS to an IAM principal. Follow the steps to add HyperPod and EKS cluster management permissions to the IAM identity (IAM role or IAM user) of your Linux terminal session.

Get the ARN of the Execution role that was created in the above CloudFormation stack. You'll need to pass this IAM role to the HyperPod service in a later step: 
```bash 
STACK_ID=hyperpod-eks-full-stack

EXECUTION_ROLE=`aws cloudformation describe-stacks \
    --stack-name $STACK_ID \
    --query 'Stacks[0].Outputs[?OutputKey==\`AmazonSagemakerClusterExecutionRoleArn\`].OutputValue' \
    --region $AWS_REGION \
    --output text`
```
Create the IAM policy:
```json
cat > hyperpod-eks-policy.json << EOL
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "${EXECUTION_ROLE}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sagemaker:CreateCluster",
                "sagemaker:DeleteCluster",
                "sagemaker:DescribeCluster",
                "sagemaker:DescribeCluterNode",
                "sagemaker:ListClusterNodes",
                "sagemaker:ListClusters",
                "sagemaker:UpdateCluster",
                "sagemaker:UpdateClusterSoftware",
                "sagemaker:DeleteClusterNodes",
                "eks:DescribeCluster",
                "eks:CreateAccessEntry",
                "eks:DescribeAccessEntry",
                "eks:DeleteAccessEntry",
                "eks:AssociateAccessPolicy",
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*"
        }
    ]
}
EOL
```

```bash 
aws iam create-policy \
    --policy-name hyperpod-eks-policy \
    --policy-document file://hyperpod-eks-policy.json \
    --region $AWS_REGION
```

Attach the policy to the IAM identity (IAM role or IAM user) that you plan to use for this workshop. You can find your IAM identity by running the following command:

```bash 
aws sts get-caller-identity
```

To extract the IAM role name or IAM user name from the IAM ARN that you obtained, see the [IAM ARNs](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html#identifiers-arns) section in the IAM document.


If your IAM identity is an IAM role, run the following command:

```bash 
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/hyperpod-eks-policy \
    --role-name <YOUR-ROLE-HERE> \
    --region $AWS_REGION
```

If your IAM identity is an IAM user, run the following command:

```bash 
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws iam attach-user-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/hyperpod-eks-policy \
    --user-name <YOUR-USER-HERE> \
    --region $AWS_REGION
```
::::
