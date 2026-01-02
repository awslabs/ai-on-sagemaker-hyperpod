

### 🚀 Welcome to **AI on SageMaker HyperPod**

Your home for deploying high performance clusters to Train, Fine Tune, and Host models on [**Amazon SageMaker HyperPod**](https://aws.amazon.com/sagemaker/ai/hyperpod/).

---

<div align="center">

<a href="http://awslabs.github.io/ai-on-sagemaker-hyperpod" target="_blank">
  <img src="https://img.icons8.com/color/48/000000/amazon-web-services.png" width="50" alt="AWS logo"/><br/>
  <strong><span style="font-size:22px;">🌐 Visit the AI on SageMaker HyperPod Website</span></strong><br/>
  <em>Click here to explore deployment patterns, tips and tricks, and samples</em>
</a>

</div>

---


### What can you find here
This is the home for all things related to Amazon Sagemaker Hyperpod, built by the ML Frameworks team. We strive to release content and assets that are based on our customer's feedback and help them to improve their operational efficiency. 

Explore practical examples, architectural patterns, troubleshooting, and many other contents. Work through running large distributed training jobs, fine tuning, distillation, and preference alignment, using frameworks such as [PyTorch](https://pytorch.org/), [JAX](https://docs.jax.dev/en/latest/notebooks/thinking_in_jax.html), [NeMo](https://www.nvidia.com/en-us/ai-data-science/products/nemo/), [Ray](https://docs.ray.io/en/latest/train/train.html), etc. We provide examples for [Meta's Llama](https://www.llama.com/), [Amazon Nova](https://aws.amazon.com/ai/generative-ai/nova/), [Mistral](https://mistral.ai/), [DeepSeek](https://www.deepseek.com/en), and others.

There are troubleshooting advise on specific problems you may find, best practices when integrating with other AWS services and open source projects, and code snippets that you may find useful to incorporate on your workloads.

> **Note:** AI On Sagemaker Hyperpod is an active development. For upcoming features and enhancements, please check out the [issues](https://github.com/awslbas/ai-on-sagemaker-hyperpod/issues) section.

## Examples provided
Those are some examples you can find on this project, using the EKS orchestration:
- [Running a Fully Sharded Data Parallel training example on multiple GPUs](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/eks-blueprints/training/fsdp/fully-sharded-data-parallel)
- [Running a Distributed Data Parallel training example using CPU only](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/eks-blueprints/training/ddp/distributed-data-parallel)
- [Using AWS Trainium chips to train your generative AI models](https://awslabs.github.io/ai-on-sagemaker-hyperpod/Adocs/eks-blueprints/training/trainium/aws-trainium)
- [Using Ray to run your large distributed training job](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/eks-blueprints/training/ray-train)
- [Using the Training Operator with Hyperpod](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/add-ons/training-operator)
- [Creating a hybrid infrastructure using SkyPilot](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/add-ons/integrations/skypilot)
- [Setting up Task Governance and Task Affinity for improved cluster governance and utlization](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/add-ons/Task%20Governance/Task%20Governance%20for%20Training)
- [Deploying your models for inference](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/eks-blueprints/inference/inference-operator/amazon-s3-and-amazon-fsx)

You can also find examples using the SLURM orchestration, on the website.

## Getting Started
Before delighting yourself with the features and examples provided here, we suggest you work through the setup of your Sagemaker Hyperpod cluster. On that initial step, we provide examples on how to do it using different methods (GUI, CLI scripts, Infrastructure as a Code - IaC, etc). After the deploying, we recommend running a few basic tests to validate you have a working cluster running as expected.

Then you can select which of the scenarios you want to work on. On every scenario we have two possible orchestration choices: using SLURM or EKS. You should select the specific example you want to go through and the specific orchestration engine you are using on your cluster. 

## Documentation
[Amazon Sagemaker Hyperpod](https://aws.amazon.com/sagemaker/ai/hyperpod) is part of the [Amazon Sagemaker AI](https://aws.amazon.com/sagemaker/ai) family of AI focused managed services on [AWS](https://aws.amazon.com). The documentation focus on helping customers setup their clusters and AWS accounts. 

This repository strive to go further and help customers setup the additional software stack required to quickly conduct proof-of-concepts and build production-ready clusters.

## Support & Feedback
AI on Sagemaker Hyperpod is maitained by the AWS ML Frameworks team and is not an AWS service. Support is provided on a best effort basis by the AI on Sagemaker Hyperpod community. If you have feedback, feature ideas, or wish to report bugs, please use the [Issues](https://awslabs.github.io/awslabs/ai-on-sagemaker-hyperpod) section of this Github.

## Security
See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notification) for more information.

## License 
This library is licensed under the Apache 2.0 License.

## Community
We're building an open-source community focused on **Development and Inference of Generative AI models** on ML Frameworks.

Come join us and contribute to shaping the future of AI on Amazon Sagemaker Hyperpod.

Built with ❤️ at AWS.
