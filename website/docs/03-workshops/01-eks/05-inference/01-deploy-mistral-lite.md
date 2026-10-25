---
title: Deploy Mistral Lite
sidebar_position: 1
---

# 🎯 Inference on HyperPod: The Grand Finale

> **Investor**: "Impressive. You've shown me training, resiliency, and multi-team governance. But can you deploy in PRODUCTION?"
>
> **CEO**: "ML Engineer, show them the inference deployment."
>
> **You**: "Time for the grand finale."

## What is the HyperPod Inference Operator?

The HyperPod Inference Operator extends your cluster to support production inference alongside training:

| Feature | Description |
|---|---|
| 🔄 Unified Infrastructure | Same cluster for training AND inference |
| 📈 Auto-Scaling | Dynamic allocation, scale from 0 to N replicas |
| 📊 Observability | Time-to-first-token, latency, throughput metrics |
| 🚀 Enterprise Deployment | Deploy from SageMaker JumpStart (400+ models) |

## What is Amazon SageMaker JumpStart?

JumpStart provides pretrained, open-source models. With the HyperPod Inference Operator, deploy 400+ models with just a click — including DeepSeek-R1, Mistral, Qwen3, and Llama4.

## 🚀 Deploying Mistral Lite via SageMaker Studio

### Step 1: Open SageMaker Studio

From the SageMaker Studio UI, open your Studio Domain.

### Step 2: Open JumpStart

Select **"Models"** on the right-hand side.

### Step 3: Search for Mistral Lite

Type "Mistral Lite" in the search bar and click on the model.

### Step 4: Click Deploy

Click the **Deploy** button on the top right.

### Step 5: Configure Deployment

| Setting | Value |
|---|---|
| Cluster | Your HyperPod cluster |
| Instance type | Match your cluster's instance type |
| Namespace | hyperpod-ns-team-a |
| Priority | Maximum (inference class) |
| Auto-scaling | Enabled, max replicas: 2 |

### Step 6: Monitor Deployment

```bash
kubectl get pods -n hyperpod-ns-team-a
```

Wait for status to change from `PodInitializing` to `Running`.

### Step 7: Test the Endpoint

Once the deployment status is **InService**, test via the SageMaker Studio UI:

1. Select your endpoint
2. Click the **Playground** tab
3. Enter a test prompt:

```json
{
  "inputs": "What is the capital of USA?"
}
```

## ✅ Success: Mistral Lite Deployed!

- ✅ Deployed Mistral Lite from SageMaker JumpStart
- ✅ Configured auto-scaling (1-2 replicas)
- ✅ Created a SageMaker endpoint for API access
- ✅ Tested the endpoint and verified it works

> **Investor**: *reaches for checkbook* 💰
