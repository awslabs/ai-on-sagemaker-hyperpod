---
title: Reviewing the cluster console
sidebar_position: 2
---

Now that we've created a cluster, we can monitor the status in the [SageMaker console](https://console.aws.amazon.com/sagemaker/home), this will show us cluster status, running instances, node groups, and allow us to easy modify the cluster.


1. Go to [SageMaker HyperPod](https://console.aws.amazon.com/sagemaker/home?/cluster-management#cluster-management) console.

2. You'll see your cluster listed, click on it:

    ![Console Screenshot](/img/01-cluster/console.png)

3. On the next page you'll see the details about the instances nodes and worker groups. 

    ![Console Screenshot](/img/01-cluster/console-2.png)

Wait until your cluster status changes to **InService** before proceeding. This should take ~10 minutes.

---

You can also view your compute nodes from the [Amazon EKS console](https://console.aws.amazon.com/eks/home): 

![Console Screenshot](/img/01-cluster/console-3.png)

In the Access tab, you will see the IAM access entries created for the HyperPod service linked role, the HyperPod execution role, and the role that you used to create the EKS cluster. 

![Console Screenshot](/img/01-cluster/eks-console-hyperpod-service-linked-role.png)