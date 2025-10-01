---
title: "View the AWS Console"
sidebar_position: 2
weight: 14
---

<p align="center">
  <img src="/img/01-cluster/sagemaker_logo.png" alt="SageMaker Logo" width="128" />
</p>

Now that we've created a cluster, we can monitor the status in the [SageMaker console](https://console.aws.amazon.com/sagemaker/home), this will show us cluster status, running instances, node groups, and allow us to easy modify the cluster.

1. Go to [SageMaker HyperPod](https://console.aws.amazon.com/sagemaker/home?/cluster-management) console.

2. You'll see your cluster listed, click on it:

    ![Console Screenshot](/img/01-cluster/console-6.png)

3. On the next page you'll see the details about the cluster:

    ![Console Screenshot](/img/01-cluster/console-4.png)
    ![Console Screenshot](/img/01-cluster/console-5.png)

Wait until your cluster status changes to **InService** before proceeding. This should take ~10 minutes.