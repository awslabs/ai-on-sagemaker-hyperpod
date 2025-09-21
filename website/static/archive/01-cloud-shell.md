---
title : "1. AWS Event"
weight : 1
---

![AWS CloudShell](/static/images/00-setup/cloud_shell.png)

[AWS CloudShell](https://aws.amazon.com/cloudshell/) is a browser-based shell provided that allows you to interact with AWS services from within a terminal. It provides you with a pre-configured environment that includes command-line tools and scripts needed to manage your AWS resources.

- **Pre-Installed Tools:** AWS CloudShell comes with a variety of pre-installed tools, including the AWS Command Line Interface (CLI), Git, Python, Node.js, and more, making it easy to manage your AWS resources directly from the shell.
- **Persistent Storage:** CloudShell provides 1 GB of persistent storage in your home directory, so you can store scripts and configuration files that persist across sessions.
- **No Setup Required:** Since CloudShell is integrated into the AWS Management Console, you don’t need to set up or configure anything. It’s ready to use immediately, which is particularly useful for quick tasks or when working in different environments.
- **Access to AWS Resources:** CloudShell automatically uses the credentials associated with your AWS Management Console session, so you can interact with your resources without needing to manually configure credentials.
- **Security:** AWS CloudShell operates within your AWS account, inheriting your security settings and IAM permissions, ensuring that all actions performed in the shell are secure and compliant with your organization's policies.

#### Connect to AWS CloudShell

1. Access your AWS Account using the following button:

    :button[AWS Account]{variant="primary" href="https://catalog.us-east-1.prod.workshops.aws/event/account-login" external="true"}

2. In the AWS Management Console, open [**CloudShell**](https://console.aws.amazon.com/cloudshell/home)

    ![CloudShell](/static/images/00-setup/cloud_shell_find.png)

3. In your CloudShell terminal, verify you are using the correct region where you plan to deploy your cluster. If you do not know your region, reach out to an AWS team member to confirm. Verify permissions by running the following command in your CloudShell terminal.

```bash
aws sts get-caller-identity
```
You should see the inherited permissions from your IAM role. 

![CloudShell](/static/images/00-setup/cloud_shell_terminal.png)


4. Verify your user has permissions to use sagemaker by executing the following:

```bash
aws sagemaker list-clusters
```
![CloudShell](/static/images/00-setup/cloud_shell_list_clusters.png)

---
### Setup Your Environment

Ensure that you have the following tools installed: 

:::alert{header="Note:"}
The AWS CLI and kubectl come pre-installed on [AWS CloudShell](/00-setup/01-cloudshell.md). 
:::

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

---

### Review Your IAM Permissions

The following procedure shows you how to attach an IAM policy with the required permissions to pass the required execution role to SageMaker HyperPod to perform actions on your behalf. 

Get the ARN of the execution role that was created in workshop CloudFormation stack. 
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

Attach the policy to the IAM principal you will to use for this workshop (`WSParticipantRole`): 

```bash 
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/hyperpod-eks-policy \
    --role-name  WSParticipantRole \
    --region $AWS_REGION
```