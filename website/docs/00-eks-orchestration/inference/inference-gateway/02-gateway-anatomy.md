---
title: Inspect the Gateway
sidebar_position: 3
sidebar_label: Gateway Anatomy
---
# Inspect the gateway

Applying one `InferenceGatewayConfig` caused the controller to create a number of resources across two namespaces. This page maps each of them back to the architecture, so that later troubleshooting is not guesswork.

## Overview

From a single custom resource, the `inference-gateway-controller` generated:

- An Envoy proxy deployment and service, in `hyperpod-inference-system`
- A `Gateway` and an `HTTPRoute`, using the Kubernetes Gateway API
- An `InferencePool`, from the Gateway API Inference Extension
- One endpoint picker deployment per scheduler, in your model namespace

## 1. Data plane pods

### 1.1 System namespace

```bash
kubectl get pods -n "${SYSTEM_NS}"
```

Expected output:

```
NAME                                                              READY   STATUS    RESTARTS   AGE
envoy-hyperpod-inference-system-inference-gateway-demo-de0zd9l8   2/2     Running   0          5m
hyperpod-inference-alb-5d8686444f-7rb5w                           1/1     Running   0          8h
hyperpod-inference-alb-5d8686444f-fhz4t                           1/1     Running   0          8h
hyperpod-inference-controller-manager-69468f998f-hxsdl            1/1     Running   0          8h
inference-gateway-controller-6bfc749674-dkkhs                     1/1     Running   0          8h
keda-admission-webhooks-6ffc97877d-ht4fg                          1/1     Running   0          8h
keda-operator-978d6445d-clx9v                                     1/1     Running   0          8h
keda-operator-metrics-apiserver-7fcdcb4fc7-7684s                  1/1     Running   0          8h
```

Only the `envoy-*` pod was created by your gateway. The rest are add-on control plane, installed once.

### 1.2 Model namespace

```bash
kubectl get pods -n "${MODEL_NS}"
```

Expected output:

```
NAME                                 READY   STATUS    RESTARTS   AGE
qwen-epp-061acb9a-6dfbc555fb-h56vb   2/2     Running   0          5m
vllm-qwen-86fc6f794-n2g5n            3/3     Running   0          12m
```

`qwen-epp-*` is the endpoint picker for the scheduler named `qwen`. The workload is named `<scheduler-name>-epp-<spec-hash>`, so a config with three schedulers produces three of them, and the hash changes when you edit the scheduler.

Do not hardcode that generated name. Select on labels instead: pods carry `app=<scheduler-name>-epp`, and both pods and the Deployment carry `inference.sagemaker.aws.amazon.com/scheduler=<scheduler-name>`.

:::info
One pod because the config set `replicas: 1` (default is `2`) — see [Endpoint picking](./04-endpoint-picking.md).

`2/2` is containers, not replicas: each pod runs an `otel-collector` sidecar alongside `epp`. That is why log commands need `-c epp`.
:::

## 2. Generated Gateway API resources

### 2.1 InferencePool and HTTPRoute

Each scheduler becomes an `InferencePool` plus an `HTTPRoute`, both in your model namespace:

```bash
kubectl get inferencepool,httproute -n "${MODEL_NS}"
```

Expected output:

```
NAME                                                  AGE
inferencepool.inference.networking.k8s.io/qwen        5m

NAME                                                        HOSTNAMES   AGE
httproute.gateway.networking.k8s.io/qwen                                5m
httproute.gateway.networking.k8s.io/inference-gateway-demo-health       5m
```

### 2.2 The Gateway

The `Gateway` itself lives in the system namespace:

```bash
kubectl get gateway -n "${SYSTEM_NS}"
```

Expected output:

```
NAME                     CLASS               ADDRESS                                                                         PROGRAMMED   AGE
inference-gateway-demo   inference-gateway   k8s-hyperpod-envoyhyp-8551468ca7-...elb.us-west-2.amazonaws.com                  True         5m
```

## 3. Which endpoint-picker implementation is running

The `scheduler` field in your config chooses between two implementations. The container image is the reliable way to tell which one is active:

```bash
kubectl get pods -n "${MODEL_NS}" -l app=qwen-epp \
  -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
```

| `scheduler` value | Image |
| --- | --- |
| `llm-d` | `llm-d-epp` |
| `epp` | `inference-gateway-epp` |

## 4. How the endpoint picker is wired

Inspect the endpoint picker's arguments to see how it is bound to its pool:

The Deployment name carries a generated hash, so select it by scheduler label rather than by name:

```bash
kubectl get deploy -n "${MODEL_NS}" \
  -l inference.sagemaker.aws.amazon.com/scheduler=qwen \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].args}{"\n"}'
```

Expected output:

```
["--pool-name","qwen","--pool-namespace","inference-gateway-lab","--pool-group","inference.networking.k8s.io","--zap-encoder","json","--config-file","/config/default-plugins.yaml","--enable-pprof=false","--metrics-endpoint-auth=false","--tracing=false"]
```

The endpoint picker is an Envoy external processing (`ext_proc`) service. Envoy calls it per request, and it replies with the endpoint to use.

## Request path

Putting it together, a request flows:

```text
client
  -> Envoy proxy                (hyperpod-inference-system)
  -> BBR ext_proc               (only when bbr.enabled: true)
  -> HTTPRoute -> InferencePool (model namespace)
  -> endpoint picker ext_proc   (model namespace)
  -> chosen vLLM pod            (model namespace)
```

## Validation

You have completed this page when you can name each data-plane pod, say which namespace it is in, and explain why.

## Next steps

Continue to [Multi-model routing](./03-multi-model-routing.md) to add a second model and see body-based routing decide between them.
