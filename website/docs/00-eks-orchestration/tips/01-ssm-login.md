---
title : "SSM Login"
weight : 41
---

## Log into cluster instances using AWS Systems Manager

You can log into cluster nodes with AWS Systems Manager (SSM). This is useful for troubleshooting issues at the host environment level rather than the container level, such as investigating disk-full situations or getting low-level GPU error reports.

To use SSM, you'll need to grab the cluster id, instance group name and the instance id:

| Key         | Example Value       | Where to get                |
|-------------|---------------------|-----------------------------|
| Cluster id  | q2vei6nzqldz        | `arn` in `describe-cluster` |
| Instance Group Name | group1      | `list-cluster-nodes`        |
| Instance Id | i-08982ccd4b6b34eb1 | `list-cluster-nodes`        |


Then, construct a SSM target name in the following format:

```
sagemaker-cluster:[cluster-id]_[instance-group-name]-[instance-id]
```

And run the `aws ssm start-session` command on your terminal using the SSM target name:

``` bash
aws ssm start-session \
    --target sagemaker-cluster:aa11bbbbb222_group1-i-111222333444555aa \
    --region us-west-2
```

Note that this initially connects you as the root user. You can switch to the ec2-user by running the following command.

```
sh-4.2# sudo su - ec2-user
[ec2-user@ip-11-22-33-44 ~]$
```


## Log into cluster instances using SSH through SSM Proxy

You can also use SSH to log into cluster nodes using SSM as a proxy. This is useful if you want to use your favorite SSH client, or modern text editor's (e.g., VS Code) remote development capability.

First, start an SSM session, and add your SSH public key to `~/.ssh/authorized_keys`:

```
sh-4.2# sudo su - ec2-user
[ec2-user@ip-11-22-33-44 ~]$ echo {your_ssh_public_key} >> ~/.ssh/authorized_keys
```

Then, add the following SSH host entry in your local development machine's SSH configuration file (`~/.ssh/config`):

```
Host my-cluster-group1-0
    HostName sagemaker-cluster:aa11bbbbb222_group1-i-111222333444555aa
    User ec2-user
    IdentityFile ~/path/to/ssh-key.pem
    ProxyCommand aws --profile default --region us-west-2 ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p
```

You can now start an SSH session using the host entry you added in the configuration file:

``` bash
ssh my-cluster-group1-0
```
