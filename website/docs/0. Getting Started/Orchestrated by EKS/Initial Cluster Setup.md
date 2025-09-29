---
titla: New cluster creation experience
sidebar_position: 1
---

# Setting up your cluster including best practices

## Initial cluster setup
SageMaker HyperPod now provides a new cluster creation experience that sets up all the resources needed for large-scale AI/ML workloads, including, networking, storage, compute, and IAM permissions in just a few clicks. The new cluster creation experience for SageMaker HyperPod introduces dual quick and custom setup paths that simplify getting started for both beginners and advanced AWS customers.  

![Amazon Sagemaker Hyperpod cluster creation experience](/img/01-cluster/cluster-creation-console.png)

- With the **new quick** setup path, you can now launch a fully-operational cluster optimized for large-scale AI workloads directly from the AWS console using a streamlined single-page interface that provisions all dependencies including VPCs, subnets, FSx storage, EKS orchestrator, and essential configurations required for building and deploying models. 

- The **custom setup** path empowers platform engineering teams already familiar with AWS to fine-tune every setting, from specific subnet configurations to selective installations, all within the same unified console experience, along with the ability to export auto-generated CloudFormation templates for production deployment.

To get started, navigate to the [SageMaker AI console](https://console.aws.amazon.com/sagemaker/home?#/cluster-management) and follow the instructions at: 
[Getting started with SageMaker HyperPod using the SageMaker console](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-create-cluster.html)

For an EKS-orchestrated Sagemaker Hyperpod, you will need to add at least one instance group right now. More instance groups can be added later. This allows you to create your Sagemaker Hyperpod cluster now even without having access to GPU-based instances, reducing the total cost of deploying the cluster. After the deployment, and you getting familiar with the basics of your new cluster, you can add an instance group with GPU-based instances and start running your workloads. 

![Console experiecen with a single instance group](/img/01-cluster/orchestrated-by-eks-setup.png)

After you click on Submit, you will see your cluster being created. You can check the console to verify what's the status of this process. When the clsuter shows as **InService** then you can start using it. The whole process usually don't take more than 20 minutes to be ready.

## 
