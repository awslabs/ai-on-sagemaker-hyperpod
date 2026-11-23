---
title: Deploy Gemma 2B Instruct from SageMaker JumpStart
sidebar_position: 2
---

# Deploy Gemma 2B Instruct from SageMaker JumpStart

## 🎯 The plan

**What we're deploying:** Gemma 2B Instruct as an AI assistant.

**How we'll deploy:** using the console and the HyperPod Inference Operator.

## What is the HyperPod Inference Operator?

The HyperPod Inference Operator extends your HyperPod cluster's functionality to support production inference workloads alongside training. It provides a deployment method for models on HyperPod using `kubectl`, the HyperPod CLI, the SageMaker Studio UI and the SageMaker Python SDK. The service provides advanced autoscaling capabilities with dynamic resource allocation that automatically adjusts based on demand. Additionally, it includes comprehensive observability and monitoring features that track critical metrics such as time-to-first-token, latency, and GPU utilization to help you optimize performance.

### Key features

**🔄 Unified infrastructure**

- Use the same cluster for training AND inference
- Maximize GPU utilization
- Seamlessly transition resources between workloads
- Reduce total cost of ownership

**📈 Advanced auto-scaling**

- Dynamic resource allocation based on demand
- Scale from 0 to N replicas automatically
- Handle traffic spikes gracefully
- Pay only for what you use

**📊 Comprehensive observability**

- Track time-to-first-token, inter-token latency, time-per-output-token, and other inference metrics
- Monitor latency and throughput
- GPU utilization metrics
- Integration with Amazon CloudWatch

**🚀 Enterprise-ready deployment**

- Deploy from SageMaker JumpStart (400+ models)
- Support for custom models (S3, FSx)
- Single-node and multi-node inference
- SageMaker endpoint integration

Good news! The ML Infrastructure team is available again, and they have reported that the inference operator is already installed on your cluster. You are good to go!

## What is Amazon SageMaker JumpStart?

Amazon SageMaker JumpStart provides pretrained, open-source models for a wide range of problem types to help you get started with machine learning. You can incrementally train and tune these models before deployment. JumpStart also provides solution templates that set up infrastructure for common use cases, and executable example notebooks for machine learning with SageMaker AI.

You can deploy, fine-tune, and evaluate pretrained models from popular model hubs through the JumpStart landing page.

With the HyperPod Inference Operator, you can deploy over 400 open-weights foundation models from SageMaker JumpStart on HyperPod with just a click, including the latest state-of-the-art models like DeepSeek-R1, Mistral, Qwen3, and Llama 4. SageMaker JumpStart models will be deployed on HyperPod clusters orchestrated by EKS and will be made available as SageMaker endpoints or Application Load Balancers (ALBs).

For this challenge, we will deploy the Gemma 2B Instruct model using this one-click approach, directly from the SageMaker JumpStart console.

[So let's go ahead and deploy! →](./03-deploy-jumpstart-ui.md)
