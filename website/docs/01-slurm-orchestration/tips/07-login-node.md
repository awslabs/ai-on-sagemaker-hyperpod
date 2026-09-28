---
title : "Login Node"
weight : 47
---

Login nodes allow users to login to the cluster, submit jobs, and view and manipulate data without running on the critical `slurmctld` scheduler node. This also allows you to run monitoring servers like [aim](https://github.com/aimhubio/aim), [Tensorboard](https://www.tensorflow.org/tensorboard), or [Grafana/Prometheus](https://prometheus.io/docs/visualization/grafana/).

In this guide we'll assume you have a cluster setup already with a FSx Filesystem.

## Setup

1. First modify your `cluster_config.json` file and add a section:

```json
{
    "InstanceGroupName": "login-group",
    "InstanceType": "ml.m5.4xlarge",
    "InstanceCount": 1,
    "LifeCycleConfig": {
        "SourceS3Uri": "s3://${BUCKET}/src",
        "OnCreate": "on_create.sh"
    },
    "ExecutionRole": "${ROLE}",
    "ThreadsPerCore": 2
},
```

You'll also need to remove the `VpcConfig` section from the `cluster_config.json` file.

2. Next update your `provisioning_parameters.json` file to include the line:

```json
  "login_group": "login-group",
```

3. Upload that to S3:

```bash
# copy to the S3 Bucket
aws s3 cp provisioning_parameters.json s3://${BUCKET}/src/
```

4. Verify the `provisioning_parameters.json` were correctly updated. You should see the new parameter `login_group`:

```bash
aws s3 cp s3://${BUCKET}/src/provisioning_parameters.json -
```

5. Finally update your cluster:

```bash
aws sagemaker update-cluster  --cli-input-json file://cluster-config.json --region $AWS_REGION
```

## Login

1. Using the `easy-ssh.sh` script we'll login to the login node:

```bash
./easy-ssh.sh -c login-group ml-cluster
```

2. Change the home directory to `/fsx/ubuntu`:

```bash
usermod -m -d /fsx/ubuntu ubuntu
```