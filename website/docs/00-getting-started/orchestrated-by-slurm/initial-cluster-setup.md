---
title: Creating your SageMaker HyperPod cluster
sidebar_position: 1
sidebar_title: Creating your SageMaker HyperPod cluster
slug: initial-cluster-setup
preview: /img/01-setup/preview-initial-cluster-setup.png
---

# Setting up your cluster following the best practices

## Initial cluster setup

To create a SageMaker HyperPod in just a few clicks, navigate to the [Amazon Sagemaker AI](https://159553542841-zhzikwuj.us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/landing) console and click on `HyperPod Clusters`. Under [Cluster Management](https://159553542841-zhzikwuj.us-west-2.console.aws.amazon.com/sagemaker/home?region=us-west-2#/cluster-management), click on the `Create HyperPod Cluster` button. More details, read the official AWS documentation [here](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html). 

![Amazon Sagemaker Hyperpod cluster creation experience](/img/01-cluster/slurm-cluster-creation-console.png)

- With the **new quick** setup path, you can now launch a fully-operational cluster optimized for large-scale AI workloads directly from the AWS console using a streamlined single-page interface that provisions all dependencies including VPCs, subnets, FSx storage, EKS orchestrator, and essential configurations required for building and deploying models. 

- The **custom setup** path empowers platform engineering teams already familiar with AWS to fine-tune every setting, from specific subnet configurations to selective installations, all within the same unified console experience, along with the ability to export auto-generated CloudFormation templates for production deployment.

To get started, navigate to the [SageMaker AI console](https://console.aws.amazon.com/sagemaker/home?#/cluster-management) and follow the instructions at: 
[Getting started with SageMaker HyperPod using the SageMaker console](https://docs.aws.amazon.com/sagemaker/latest/dg/smcluster-getting-started-slurm-console.html)

![Console experience with a single instance group](/img/01-cluster/orchestrated-by-slurm-setup.png)

After you click on Submit, you will see your cluster being created. You can check the console to verify what's the status of this process. When the clsuter shows as **InService** then you can start using it. The whole process usually don't take more than 20 minutes to be ready.
