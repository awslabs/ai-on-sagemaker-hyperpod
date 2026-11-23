---
title: Workshop Overview
sidebar_position: 1
---

# AIM406: End-to-end foundation model pipelines on SageMaker HyperPod

:::info Live workshop
This content is synced from the AWS Workshop Studio catalog. To run the workshop interactively in an AWS-hosted event, use the live version: [AIM406 on Workshop Studio](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US).
:::

:::note Comprehensive Reference Documentation
This workshop provides a guided, hands-on sandbox experience. For production deployment guidelines and best practices, see the [EKS Orchestration](/docs/eks-orchestration/getting-started/) reference documentation.
:::

## 🧬 Welcome to project Helix

**Mission briefing:** The world is facing an antimicrobial resistance crisis. 1.27 million people die annually from antibiotic-resistant infections.

**Your mission:** prove that AI can accelerate the discovery of new antimicrobial peptides.

## 🎮 Your role: ML Engineer at DNAAI

**You are:** a newly hired ML Engineer at DNAAI, a biotech startup focused on AI-powered drug discovery.

**Your tools:**

- Pre-configured Amazon SageMaker HyperPod cluster (2x `ml.g7.2xlarge` with NVIDIA RTX PRO 4500 Blackwell GPUs)
- FSx for Lustre with preprocessed UniRef50 dataset
- SageMaker Studio workspace with `kubectl` access
- Your ML engineering skills (and this workshop guide!)

In this workshop session, you will learn how to use Amazon SageMaker HyperPod to run distributed training across 2 GPU instances. For this session, we will use 2 x `ml.g7.2xlarge` instances (for more information on g7 instances, check the [documentation](https://aws.amazon.com/ec2/instance-types/g7/)).

You should have access to pre-provisioned AWS accounts — these AWS accounts already have a 2 x `ml.g7.2xlarge` Amazon SageMaker HyperPod EKS cluster. In addition to the cluster, we have an S3 bucket and an FSx for Lustre file system with a dataset pre-loaded, and a [SageMaker Studio workspace](https://aws.amazon.com/sagemaker/ai/studio/), from where you will be interacting with your cluster.

For this session, we will work together to use Amazon SageMaker HyperPod to train Meta AI's [ESM2 model](https://github.com/facebookresearch/esm), which is a state-of-the-art general-purpose protein language model. It can be used to predict structure, function, and other protein properties directly from individual sequences.

**Your team:**

- Infrastructure Engineers: "We built the cluster. Now make it perform well!"
- Data Scientists: "Dataset is ready. We tokenized everything last night. Good luck!"
- CEO: "Show me the return on investment, or I will end the project." (She's kidding. Mostly.)
- Investors: watching, judging, checkbooks ready.

:::note
The crawled source dropped the persona names and the dataset path in the team roster. See the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US) for the complete text.
:::

## 🗺️ Mission roadmap

### Level 1: cluster verification ⚙️

"Does this thing even work?"

- Verify your HyperPod cluster is operational
- Check access to the dataset
- Set up your environment
- Duration: 5 minutes

### Level 2: training 🚀

"Train a SOTA protein model? Challenge accepted."

- Submit distributed training job for ESM2
- Monitor training progress
- Watch GPU utilization increase
- Duration: 15 minutes

### Level 3: resiliency test 💪

"Murphy's Law strikes during the demo..."

- Simulate node failure during training
- Watch the HyperPod Training Operator's surgical recovery in action
- Impress investors with quick recovery time
- Duration: 20 minutes

### Level 4: production deployment 🎯

"The finale: deploy a live demo"

- Deploy an inference endpoint with the HyperPod Inference Operator
- Let investors interact with the model
- Achievement unlocked: Series B secured! 💰
- Duration: 10 minutes

### Bonus level: multi-team collaboration 🤝

"We just got 3 new research partners..."

- Set up HyperPod task governance for multiple teams
- Allocate resources fairly
- Show enterprise-scale readiness
- Duration: 15-20 minutes (if time permits)

## 🎯 What you'll learn

By the end of this workshop, you'll know how to:

- ✅ Deploy and manage SageMaker HyperPod clusters with EKS
- ✅ Run distributed training jobs using the HyperPod Training Operator
- ✅ Implement automatic fault recovery and resilience
- ✅ Monitor training jobs with `kubectl`, `kubetail` and the HyperPod console
- ✅ Manage multi-team resource allocation with task governance
- ✅ Deploy production inference endpoints with auto-scaling
- ✅ Apply these skills to a real scientific workload (and look cool doing it)

## 🧪 The science: why antimicrobial discovery?

**The problem:** antibiotic resistance is one of the biggest threats to global health. Traditional drug discovery takes 10-15 years and costs $2.6 billion per drug.

**DNAAI's proposed solution:** AI-powered protein language models like ESM2 can:

- Analyze millions of protein sequences in hours (not years)
- Predict antimicrobial properties from sequence alone
- Generate novel peptide candidates for testing
- Reduce discovery costs by 90%+

**The model:** [ESM2](https://github.com/facebookresearch/esm) (Evolutionary Scale Modeling) is a state-of-the-art protein language model from Meta AI. It understands protein sequences like GPT understands text.

## Recommended background knowledge

For this workshop it is recommended to have at least some working experience with the following tools and concepts:

- [AWS Virtual Private Cloud (VPC) networking](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Docker](https://www.docker.com/)

The workshop leverages several PyTorch training scripts from the [awsome-distributed-ai](https://github.com/awslabs/awsome-distributed-ai/tree/main/examples) GitHub repository. If you wish to customize these scripts for your own purposes, it is recommended to have working knowledge of Python and concepts such as [DistributedDataParallel](https://pytorch.org/docs/stable/generated/torch.nn.parallel.DistributedDataParallel.html), [FullyShardedDataParallel (FSDP)](https://pytorch.org/docs/stable/fsdp.html) and [SageMaker model parallelism (SMP v2)](https://docs.aws.amazon.com/sagemaker/latest/dg/model-parallel-v2.html).

Don't worry if you're new to some of these! We'll guide you through everything step-by-step.

## [Optional read] More about Amazon SageMaker HyperPod

[Amazon SageMaker HyperPod](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-ref.html) helps you provision resilient clusters for running machine learning (ML) workloads and developing state-of-the-art models such as large language models (LLMs), diffusion models, and foundation models (FMs). It accelerates development of FMs by removing undifferentiated heavy-lifting involved in building and maintaining large-scale compute clusters powered by thousands of accelerators such as [AWS Trainium](https://aws.amazon.com/machine-learning/trainium/) and NVIDIA A100 and H100 Graphical Processing Units (GPUs). When accelerators fail, self-healing clusters automatically detect and replace the faulty hardware on the fly so that you can focus on running ML workloads for weeks and months without disruption. Additionally, with SageMaker HyperPod, you can customize your computing environment to best suit your needs and configure it with the Amazon SageMaker distributed training libraries to achieve optimal performance on AWS.

[Amazon Elastic Kubernetes Service (Amazon EKS)](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html) is a managed service that eliminates the need to install, operate, and maintain your own Kubernetes control plane on Amazon Web Services (AWS). Kubernetes is an open-source system that automates the management, scaling, and deployment of containerized applications. Amazon EKS automatically manages the availability and scalability of the Kubernetes control plane nodes responsible for scheduling containers, managing application availability, storing cluster data, and other key tasks. With Amazon EKS, you can take advantage of all the performance, scale, reliability, and availability of AWS infrastructure, as well as integrations with AWS networking and security services.

By completing this workshop you will learn how to train large language models (LLMs) on SageMaker HyperPod worker nodes while using an EKS control plane to provide a native Kubernetes experience for container orchestration and workflow management via tools like the [Kubeflow Training Operator](https://www.kubeflow.org/docs/components/training/overview/).

:::important
The Workshop Studio version of this content can only be used at AWS-hosted events.
:::

## Cloud infrastructure costs

Since this workshop is designed for AWS-hosted events, you will not incur any costs. If you do follow these instructions to set up a cluster in your own account, however, please be aware that you may incur some additional cloud costs. Please review the following pricing pages for more information:

- [Amazon EKS pricing](https://aws.amazon.com/eks/pricing/)
- [Amazon SageMaker HyperPod pricing](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-ref.html)
- [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/)
- [Amazon FSx for Lustre pricing](https://aws.amazon.com/fsx/lustre/pricing/)
- [Amazon S3 pricing](https://aws.amazon.com/s3/pricing)
