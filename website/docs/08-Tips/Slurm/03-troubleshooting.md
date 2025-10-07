---
title : "Troubleshooting"
weight : 43
---

> So your cluster failed to create, what do you do now?

The first thing to look at is the status reason. This **only** shows up in the API/CLI and not the console so you'll need to run:

```bash
aws sagemaker describe-cluster --cluster-name
```

In that call you'll see a *FailureMessage* field such as:

```
"FailureMessage": "We currently do not have sufficient capacity for the requested instance type(s). Please try again.",
```
:::info
If you get the above error message it's usually because you're running the wrong *availability zone*. Try launching the same instance type in that Availability Zone in native EC2. Our stack defaults to `usw2-az4` which does not support `g5.12xlarge`. Please use `usw2-az3` or `usw2-az2` for that. To determine supported AZ's you can run the following command for your instance type:

```bash
aws ec2 describe-instance-type-offerings --location-type availability-zone  --filters Name=instance-type,Values=g5.12xlarge --region us-west-2 --output table
```
:::

Or 

```
"Lifecycle scripts did not run successfully. Ensure the scripts exist in provided S3 path, are accessible, and run without errors. Please see CloudWatch logs for lifecycle script execution details."
```

## DNS Error

If you see the following error when running a Slurm command such as `srun`, `sbatch` or `sinfo`:

```
$ srun ...
srun: error: resolve_ctls_from_dns_srv: res_nsearch error: Unknown host
srun: error: fetch_config: DNS SRV lookup failed
srun: error: _establish_config_source: failed to fetch config
srun: fatal: Could not establish a configuration source
```

This is likely caused by restarting the `slurmd` process on the Headnode. If you accidently ran `sudo systemctl restart slurmd` on the headnode it'll delete the `/opt/slurm/etc/slurm.conf` file. This is recoverable by running the following commands:

```bash
sudo systemctl stop slurmd && sleep 1
sudo systemctl stop slurmctld && sleep 1
sudo systemctl stop sagemaker-cluster-agent && sleep 1
sudo systemctl start sagemaker-cluster-agent && sleep 1
sudo systemctl start slurmctld && sleep 1
```

Additionally, you will need to restore slurm accounting on the controller node with the following steps:

```bash 
echo -e "\n# ACCOUNTING\nInclude accounting.conf" | sudo tee -a "/opt/slurm/etc/slurm.conf"
sudo scontrol reconfigure
sudo systemctl restart slurmctld
```

**Note** To restart the *slurm scheduler* on the head node run `sudo systemctl restart slurmctld`. This is the scheduler process and `slurmd` is the compute node process.

## Logs

If the Lifecycle scripts failed, you'll need to look at CloudFormation logs.

1. Go to [Cloudformation Logs](https://console.aws.amazon.com/cloudwatch/home?#logsV2:log-groups)

2. Search for `/aws/sagemaker/Clusters/<cluster-name>/<cluster-id>`

3. There's a log group per-instance launched. I suggest looking at the Head Node (`controller-group`) first:

    ![CloudWatch Logs](/img/03-advanced/logs.png)
