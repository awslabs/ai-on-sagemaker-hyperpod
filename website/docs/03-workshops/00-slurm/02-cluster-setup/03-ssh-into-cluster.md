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

Run the [easy-ssh.sh](https://github.com/awslabs/awsome-distributed-ai/blob/main/1.architectures/5.sagemaker-hyperpod/easy-ssh.sh) script:

```bash
awsome-distributed-training/1.architectures/5.sagemaker-hyperpod/easy-ssh.sh -c controller-machine ml-cluster
```

If asked "Would you like to add ml-cluster to `~/.ssh/config`", please type in "yes".

### 3. Switch to the ubuntu user

```bash
sudo su - ubuntu
pwd  # Should print out /fsx/ubuntu
```

:::warning
If you see an error like `TargetNotConnected`, check the cluster status with `aws sagemaker describe-cluster --cluster-name ml-cluster`. It needs to be **InService** prior to accessing the cluster.
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
Starting session with SessionId: ...
#
```
