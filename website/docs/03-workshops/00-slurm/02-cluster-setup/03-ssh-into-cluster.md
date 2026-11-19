---
title: SSH into Cluster
sidebar_position: 3
---

# SSH into Cluster

:::tip Reference Documentation
For detailed SSH access methods and troubleshooting, see [SSH into HyperPod](/docs/slurm-orchestration/getting-started/ssh-into-hyperpod).
:::

## Login to Your Cluster

Once the cluster status changes to `InService` you can connect to the cluster via SSM. You'll need to grab the cluster id, node group name and the instance id:

| Key | Example Value | Where to get |
|---|---|---|
| Cluster id | q2vei6nzqldz | ARN in describe-cluster |
| Instance Id | i-08982ccd4b6b34eb1 | list-cluster-nodes |
| Node Group Name | controller-machine | list-cluster-nodes |

### 1. Install the SSM Session Manager Plugin

```bash
sudo curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "/tmp/session-manager-plugin.deb"
sudo dpkg -i /tmp/session-manager-plugin.deb
```

### 2. Connect Using easy-ssh.sh

Run the [easy-ssh.sh](https://github.com/awslabs/awsome-distributed-ai/blob/main/architectures/sagemaker-hyperpod-slurm/easy-ssh.sh) script:

```bash
awsome-distributed-ai/architectures/sagemaker-hyperpod-slurm/easy-ssh.sh -c controller-machine ml-cluster
```

If asked "Would you like to add ml-cluster to `~/.ssh/config`", please type in "yes".

:::warning Cluster not yet InService
If you see an error similar to the following, check the cluster status with `aws sagemaker describe-cluster --cluster-name ml-cluster`. It needs to be **InService** prior to accessing the cluster.

```
An error occurred (TargetNotConnected) when calling the StartSession operation:
sagemaker-cluster:ry1dxjpubisd_controller-machine-i-07042e35a07c61543 is not connected.
```
:::

:::warning RunAs user does not exist
In certain scenarios where the SSH workflow changes — for example, the cluster is re-created, or the client machine you're using to SSH into the cluster changes — you may see this error when trying to use the `easy-ssh` script:

```
----------ERROR-------
Unable to start command: failed to start pty since RunAs user <your username> does not exist
```

This usually happens when you've set up multi-user access and have enabled [Run-as-user through SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-preferences-run-as.html). To fix this, revert the Run-as-user SSM session preference and try again.
:::

You should see output similar to:

```
=================================================
==== 🚀 HyperPod Cluster Easy SSH Script! 🚀 ====
=================================================
Cluster id: dfzt1l941fbe
Instance id: i-01577219f576e5835
Node Group: controller-machine
aws ssm start-session --target sagemaker-cluster:dfzt1l941fbe_controller-machine-i-01577219f576e5835
Would you like to add ml-cluster to ~/.ssh/config (yes/no)?
> yes
✅ adding ml-cluster to ~/.ssh/config:
Next add your ssh public key to ~/.ssh/authorized_keys on the cluster and then you can do:

  $ ssh ml-cluster

Starting session with SessionId: ...
#
```

### 3. Switch to the ubuntu user

```bash
sudo su - ubuntu
pwd  # Should print out /fsx/ubuntu
```
