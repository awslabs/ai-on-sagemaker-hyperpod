---
sidebar_position: 1
title: Introduction
---

> 💡 *Optimized Blueprints for deploying high performance clusters to train, fine tune, and host (inference) models on Amazon Sagemaker Hyperpod*

![SageMaker Logo](/img/01-cluster/sagemaker_logo.png) 

## Train, fine tune, and host generative AI models on Amazon Sagemaker Hyperpod

Welcome to the **AI on Sagemaker Hyperpod**, your home for deploying large distributed training clusters on [Amazon Sagemaker Hyperpod](https://aws.amazon.com/sagemaker/ai/hyperpod/).

### What can you find here
This is the home for all things related to Amazon Sagemaker Hyperpod, built by the ML Frameworks team at AWS with support from the open source community. We strive to deliver content and assets based on real-world use cases and customer feedback.

Explore practical examples, architectural patterns, troubleshooting, and many other contents. Work through running large distributed training jobs, fine tuning, distillation, and preference alignment, using frameworks such as [PyTorch](https://pytorch.org/), [JAX](https://docs.jax.dev/en/latest/index.html), [NeMo](https://www.nvidia.com/en-us/ai-data-science/products/nemo/), [Ray](https://www.ray.io/#use-cases), etc. We provide examples for [Meta's Llama](https://www.llama.com/), [Amazon Nova](https://nova.amazon.com/), [Mistral](https://mistral.ai/), [DeepSeek](https://www.deepseek.com/en), and others.

There is troubleshooting advise on specific problems you may find, best practices when integrating with other AWS services and open source projects, and code snippets that you may find useful to incorporate on your workloads.

> **Note:** AI On Sagemaker Hyperpod is an active development. For upcoming features and enhancements, please check out the [issues](https://github.com/awslabs/ai-on-sagemaker-hyperpod/issues) section.

## Examples provided
Those are the examples you can find on this project: 
- [Running a Fully Sharded Data Parallel training example on multiple GPUs](/docs/eks-blueprints/training/fsdp/fully-sharded-data-parallel)
- [Running a Distributed Data Parallel training example using CPU only](/docs/eks-blueprints/training/ddp/distributed-data-parallel)
- [Using AWS Trainium chips to train your generative AI models](/docs/eks-blueprints/training/trainium/aws-trainium)
- [Using Ray to run your large distributed training job](/docs/eks-blueprints/training/ray-train/ray-train-readme)
- [Using the Training Operator with Hyperpod](/docs/add-ons/hp-training-operator/overview)

- [Creating a hybrid infrastructure using SkyPilot](/docs/add-ons/integrations/skypilot)
- [Setting up Task Governance and Task Affinity for improved cluster governance and utilization](/docs/add-ons/Task%20Governance/Task%20Governance%20for%20Training)
- [Deploying your models for inference](/docs/eks-blueprints/inference/inference-operator/sagemaker-jumpstart)

## Getting Started
Before delighting yourself with the features and examples provided here, we suggest you work through the setup of your Sagemaker Hyperpod cluster. On that initial step, we provide examples on how to do it using different methods (GUI, CLI scripts, Infrastructure as a Code - IaC, etc). After deploying your cluster, we recommend running a few basic tests to validate you have a working cluster running as expected.

Then you can select which of the scenarios you want to work on. On every scenario we have two possible orchestration choices: using SLURM or EKS. You should select the specific example you want to go through and the specific orchestration engine you are using on your cluster. 

## Documentation
[Amazon Sagemaker Hyperpod](https://aws.amazon.com/sagemaker/ai/hyperpod) is part of the [Amazon Sagemaker AI](https://aws.amazon.com/sagemaker/ai) family of AI focused managed services on [AWS](https://aws.amazon.com). The documentation focus on helping customers setup their clusters and AWS accounts. 

This repository strive to go further and help customers setup the additional software stack required to quickly conduct proof-of-concepts and build production-ready clusters.

## Support & Feedback
AI on Sagemaker Hyperpod is maintained by the AWS ML Frameworks team and is not an AWS service. Support is provided on a best effort basis by the AI on Sagemaker Hyperpod community. If you have feedback, feature ideas, or wish to report bugs, please use the [Issues](https://github.com/awslabs/ai-on-sagemaker-hyperpod/issues) section of this Github.

## Security
See [CONTRIBUTING](https://github.com/awslabs/ai-on-sagemaker-hyperpod/blob/main/CONTRIBUTING.md#security-issue-notification) for more information.

## License 
This library is licensed under the Apache 2.0 License.

## Community
We're building an open-source community focused on **Development and Inference of Generative AI models** on ML Frameworks.

Come join us and contribute to shaping the future of AI on Amazon Sagemaker Hyperpod.

Built with ❤️ at AWS.

