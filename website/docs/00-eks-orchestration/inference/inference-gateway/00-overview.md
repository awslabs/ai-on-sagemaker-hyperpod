---
title: Routing LLM Traffic with the Inference Gateway
sidebar_position: 1
sidebar_label: Overview
---
# Routing LLM traffic with the Inference Gateway

This guide shows how to serve several models behind a single OpenAI-compatible endpoint on SageMaker HyperPod, and how the gateway decides where each request goes.

A plain Kubernetes `Service` load balances round-robin. That is a poor default for LLM inference, where requests have wildly unequal cost, a saturated replica queues while an idle one sits free, and a replica that already holds the KV blocks for a shared prompt prefix can skip prefill entirely. The Inference Gateway replaces round-robin with model-aware and load-aware routing.

## Two routing decisions

Every request through the gateway is resolved by two independent decisions. The examples in this section follow that split:

```text
request -> [1. which model pool?] -> [2. which pod in that pool?] -> vLLM
                    BBR                    endpoint picker
```

| Decision | Mechanism | Covered in |
| --- | --- | --- |
| Which model pool serves this request | Body-based routing (BBR) reads the `model` field from the request body | [Multi-model routing](./03-multi-model-routing.md) |
| Which pod inside that pool serves it | The endpoint picker scores candidate pods | [Endpoint picking](./04-endpoint-picking.md) |

## Core components

The gateway is delivered by the `amazon-sagemaker-hyperpod-inference` EKS add-on and splits across two namespaces:

- **Control plane**, in `hyperpod-inference-system`:
  - `inference-gateway-controller` reconciles your `InferenceGatewayConfig` and acts as the Envoy control plane
- **Data plane**, created per gateway:
  - An Envoy proxy deployment in `hyperpod-inference-system`
  - A body-based routing (BBR) deployment in `hyperpod-inference-system`, present only when BBR is enabled
  - One **endpoint picker** pod per scheduler, in your **model namespace**
- **Model backends**, in your model namespace e.g. the vLLM pods that serve the models

:::info
The Envoy proxy and the BBR pod run in `hyperpod-inference-system`, but the endpoint pickers run in your **model namespace**, next to the models they route to. This trips people up when looking for pods.
:::

## Key concept: schedulers

A **scheduler** is one entry in `spec.schedulers[]` of an `InferenceGatewayConfig`. It is a named routing target group that binds four things together:

| Field | Role |
| --- | --- |
| `name` | Names the scheduler, its `InferencePool`, and its endpoint picker pod |
| `modelName` | The value BBR matches against the request body's `model` field |
| `modelSelector` + `targetPort` | Which pods can serve it, selected by label |
| `weights` | How to score those pods when more than one is a candidate |

Each scheduler produces an endpoint picker pod named `<scheduler-name>-epp`.

## Prerequisites

Before proceeding, ensure you have:

- A functional HyperPod EKS cluster with GPU nodes and `kubectl` access
- The `amazon-sagemaker-hyperpod-inference` add-on installed **with the inference gateway component enabled**
- At least **2 free GPUs** for the multi-model example, or **3** for the endpoint picking example
- A namespace for your models

Each vLLM pod in these examples requests one whole GPU. The examples were validated on an `ml.g5.12xlarge` instance group (4 GPUs) using `Qwen/Qwen2.5-1.5B-Instruct` and `Qwen/Qwen2.5-0.5B-Instruct` on vLLM `v0.8.5`, so they fit on a single node.

### Verify the Inference Gateway is enabled

The gateway component is **off by default**. Confirm the add-on is active and check its configuration:

```bash
aws eks describe-addon \
  --cluster-name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" \
  --addon-name amazon-sagemaker-hyperpod-inference \
  --query 'addon.{version:addonVersion,status:status,health:health.issues}'
```

Expected output:

```json
{
    "version": "v2.0.0-eksbuild.1",
    "status": "ACTIVE",
    "health": []
}
```

Then confirm the gateway CRD and controller are present:

```bash
kubectl get crd inferencegatewayconfigs.inference.sagemaker.aws.amazon.com
kubectl get pods -n hyperpod-inference-system | grep inference-gateway-controller
```

Expected output:
```bash
NAME                                                         CREATED AT
inferencegatewayconfigs.inference.sagemaker.aws.amazon.com   2026-08-10T12:31:57Z
inference-gateway-controller-6bfc749674-dkkhs            1/1     Running   0          19d
```

:::warning
If the `inferencegatewayconfigs` CRD is missing, the add-on was installed without the gateway component. Update the add-on configuration with `inferenceGateway.enabled: true` before continuing. The `inferenceOperator` component defaults to enabled, but `inferenceGateway` does not.
:::

## Set shared environment variables

Every page in this section uses these variables:

```bash
export SYSTEM_NS=hyperpod-inference-system
export MODEL_NS=inference-gateway-lab
export GATEWAY_NAME=inference-gateway-demo

kubectl create namespace "${MODEL_NS}"
```

## What you will build

The pages that follow build up in order:

1. [Deploy your first gateway](./01-first-gateway.md) — one model, a single scheduler, and your first completion through the gateway
2. [Inspect the gateway](./02-gateway-anatomy.md) — map every resource the controller created back to the architecture above
3. [Multi-model routing](./03-multi-model-routing.md) — add a second model and prove that BBR routes each request to the right backend
4. [Endpoint picking](./04-endpoint-picking.md) — scale a model to multiple replicas and see how the endpoint picker chooses between them
5. [Cleanup and troubleshooting](./05-cleanup-and-troubleshooting.md)

## Related guides

- [Inference Operator](../inference-operator/sagemaker-jumpstart.md) for deploying models through the managed operator workflow
- [Inference with Load Balancer](../load-balancer-inference/inference-with-loadbalancer.md) for exposing a single model through an AWS load balancer
- [Bring Your Own Inference Framework](../bring-your-own-inference-framework/00-overview.md) for KV cache reuse across framework restarts with LMCache
