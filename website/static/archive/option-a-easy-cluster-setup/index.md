---
title : "1. [LEGACY] (Option A) Easy Cluster Setup"
weight : 1
---
In this section, we provide you with a [completely automated solution](https://github.com/aws-samples/awsome-distributed-training/tree/main/1.architectures/7.sagemaker-hyperpod-eks/automate-smhp-eks) that will help you create your own SageMaker HyperPod EKS cluster by yourself! 

Before running this script, please ensure you have the following:
1. Administrator Access to your console via IAM. Run `aws configure`. 
2. Complete the [prerequisite steps](/00-setup), and deploy the CloudFormation stack(s).
3. Linux based development environment (macOS is great!)
4. Install: `jq`

:::::alert{header="Note:"}
Yes, the script supports all 3 deployment modes (Full Deployment, Integrative Deployment, and Minimal Deployment). Make sure you've deployed the [CloudFormation Stack](/00-setup/index.md) prior to running this script.
:::::