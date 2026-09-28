---
title: "Troubleshoot IAM Permissions"
weight: 60
---

## Resolving `AWS Configure` Permissions Issues on HyperPod Nodes

### Overview

:::danger
Users should avoid running `aws configure` on any nodes in the HyperPod cluster! Running `aws configure` on hyperpod nodes will over-write the permissions of the SageMaker HyperPod EC2 Instance profile, which inherits permissions from the `AmazonSageMakerExecutionRole`. Overwritting this profile can lead to unintended permissions issues including nodes becoming inaccessible! 

If you need to update permissions of a HyperPod node to access AWS Resources, instead ask your adminstrator to add a policy to the SageMakerClusterExecutionRole in IAM.
:::

Accidents happen, and users can accidentally execute `aws configure` on a head node or compute node. 

### Validate the IAM Caller Identity on the EC2 Instance
The aws sts get-caller-identity command returns details about the IAM identity currently being used to make the AWS request. On HyperPod, the caller identity of all the cluster nodes is set by HyperPod and inherits permissions of the SageMaker Cluster Execution Role which was created in IAM.

The correct output of aws sts get-caller-identity on a hyperpod node should look similar to the following:

```
{
    "UserId": "XXXXXXXXXX:SageMaker",git s
    "Account": "XXXXXXXXXXX",
    "Arn": "arn:aws:sts::ACCOUNT_ID:assumed-role/sagemaker-hyperpod-AmazonSagemakerClusterExecutionR-XXXXXXX/SageMaker"
}

```

If the output on your hyperpod node looks different, its likely a user inadvertendly overwrote the default instance profile. The below steps can help recover the HyperPod Instance Profile.

### Recovery Steps if `aws configure` Has Been Run

The first step to restore restore access is deleting the configuration files created by `aws configure` on the node. 

1. **Identify the Affected Node**  
If `aws configure` was executed on a single node, such as the head node, follow these instructions to regain access.

2. **Connect to the affected Node**  
If your node is accessible, we assume you have connected to the node via SSM or SSH, and you can advance to step 3: *Remove AWS User Credentials*. If the affected node is inaccessible, review the following troubleshooting steps:

:::info

It is possible that your node may be inaccessible via ssm if the new instance profile on the node (inherited from `aws configure` credentials). In this case, you can ask your adminstrator to add the [SSM Managed Instance Core Policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html) to the AWS User in IAM whose credentials now exist on the node > this should permit access to the node via SSM. 
   


Run this command to connect to an arbitrary compute node via SSM:
   
```bash
   aws ssm start-session \
       --target sagemaker-cluster:aa11bbbbb222_worker-group-1-i-111222333444555aa \
       --region us-west-2
```
Once logged in, ssh into the affected node.

```bash 
ssh <affected_node_IP>
```

:::info
If you need to connect to the controller or login node, you can find the ip address in the resource_config.json file on each hyperpod node. Here is a sample command to get the head node IP:

```bash
echo 'head_node_ip=$(sudo cat /opt/ml/config/resource_config.json | jq '"'"'.InstanceGroups[] | select(.Name == "controller-machine") | .Instances[0].CustomerIpAddress'"'"' | tr -d '"'"'"'"'"')' >> ~/.bashrc
```

then connect via ssh

```bash
ssh $head_node_ip
```
:::

3. **Remove AWS User Credentials:**

On the affected node, remove the user set permission by running:

```bash
sudo rm -rf ~/.aws/
```

Reboot the node to restore the SageMaker HyperPod Instance Profile:

```bash
sudo reboot
```

When the node is rebooted and accessible, you can verify the Instance Profile is correct by running

```bash
aws sts get-caller-identiy
```

It should look similar to:

```
{
    "UserId": "XXXXXXXXXXXXXXXXXXXXXX:SageMaker",
    "Account": "XXXXXXXXXXX",
    "Arn": "arn:aws:sts::ACCOUNT_ID:assumed-role/sagemaker-hyperpod-AmazonSagemakerClusterExecutionR-XXXXXXX/SageMaker"
}
```

### Cleaning Up
Congratulations, you have recovered the EC2 Instance Profile of your HyperPod node. Remind your users not to run `aws configure` on the HyperPod cluster nodes! If additional IAM permissions are needed for the HyperPod Cluster, modify the cluster execution role in IAM instead! (Cluster execution role can be found in the HyperPod console).



