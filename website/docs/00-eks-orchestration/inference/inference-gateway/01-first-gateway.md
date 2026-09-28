---
title: Deploy Your First Gateway
sidebar_position: 2
sidebar_label: First Gateway
---
# Deploy your first gateway

This page deploys one model, puts a single-scheduler gateway in front of it, and sends the first completion through it. Start here before adding a second model.

## Overview

You will:

1. Deploy `Qwen/Qwen2.5-1.5B-Instruct` using the HyperPod inference operator
2. Create an `InferenceGatewayConfig` with one scheduler and BBR disabled
3. Resolve the in-cluster gateway URL and send a completion request

At this stage there is only one model pool and one replica, so no routing decision is actually being made. That is intentional — it establishes a working baseline that later pages build on.

## 1. Deploy the model backend

### 1.1 Create the InferenceEndpointConfig

The inference operator deploys models through the `InferenceEndpointConfig` resource. Create one for the 1.5B model:

```bash
cat <<EOF > vllm-qwen-operator.yaml
apiVersion: inference.sagemaker.aws.amazon.com/v1
kind: InferenceEndpointConfig
metadata:
  name: vllm-qwen
  namespace: ${MODEL_NS}
spec:
  modelName: vllm-qwen
  replicas: 1
  modelSourceConfig:
    modelSourceType: huggingface
    huggingFaceModel:
      modelId: Qwen/Qwen2.5-1.5B-Instruct
  worker:
    image: vllm/vllm-openai:v0.8.5
    modelInvocationPort:
      containerPort: 8000
      name: http
    modelVolumeMount:
      name: model-volume
      mountPath: /opt/ml/model
    resources:
      limits:
        nvidia.com/gpu: "1"
      requests:
        nvidia.com/gpu: "1"
    args:
      - "--model"
      - "Qwen/Qwen2.5-1.5B-Instruct"
      - "--port"
      - "8000"
      - "--max-model-len"
      - "4096"
      - "--gpu-memory-utilization"
      - "0.4"
EOF
```

Two details in this manifest matter later:

- **`metadata.name` drives the pod label.** The operator labels its pods `app=<metadata.name>`, which is what the gateway's `modelSelector` matches. Naming this resource `vllm-qwen` produces `app=vllm-qwen`.
- **The model id is passed in `args`.** For `modelSourceType: huggingface`, the operator does not pre-populate `modelVolumeMount`, so vLLM downloads the weights itself.

### 1.2 Deploy and wait

```bash
kubectl apply -f vllm-qwen-operator.yaml
kubectl rollout status deploy/vllm-qwen -n "${MODEL_NS}" --timeout=600s
```

Loading a 1.5B model takes a few minutes. Watch the pod become ready:

```bash
kubectl get pods -n "${MODEL_NS}" -w
```

Expected output once ready:

```
NAME                         READY   STATUS    RESTARTS   AGE
vllm-qwen-68c5644b78-r8cnl   3/3     Running   0          2m
```

:::info
The pod reports `3/3` because the operator injects two sidecars — `sidecar-reverse-proxy` and `otel-collector` — alongside your model container. The operator also generates a readiness probe on `/ping:8000`, so `READY` is a trustworthy signal that vLLM is actually serving.
:::

### 1.3 Confirm the pod label

The gateway finds backends by label, so verify it before wiring the gateway:

```bash
kubectl get pods -n "${MODEL_NS}" -l app=vllm-qwen \
  --show-labels --no-headers
```

Expected output:

```
vllm-qwen-68c5644b78-r8cnl   3/3   Running   0   2m   app=vllm-qwen,deploying-service=hyperpod-inference,pod-template-hash=68c5644b78
```

## 2. Create the gateway

### 2.1 Define a single-scheduler config

```bash
cat <<EOF > gateway-single.yaml
apiVersion: inference.sagemaker.aws.amazon.com/v1alpha1
kind: InferenceGatewayConfig
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${MODEL_NS}
spec:
  bbr:
    enabled: false
  schedulers:
    - name: qwen
      modelName: "Qwen/Qwen2.5-1.5B-Instruct"
      modelSelector:
        matchLabels:
          app: vllm-qwen
      targetPort: 8000
      scheduler: llm-d
EOF

kubectl apply -f gateway-single.yaml
```

The `scheduler` field selects the endpoint-picker implementation, either `llm-d` or `epp`. BBR stays disabled here because there is only one scheduler.

### 2.2 Wait for the gateway to become ready

```bash
kubectl get inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}" \
  -o "custom-columns=NAME:.metadata.name,CONDITIONS:.status.conditions[*].status"
```

Expected output, once all conditions are satisfied:

```
NAME                     CONDITIONS
inference-gateway-demo   True,True,True,True,False
```

To see which condition is which:

```bash
kubectl get inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}" \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
```

Expected output:

```
Accepted=True
Ready=True
GatewayProgrammed=True
BBRReady=True
AdmissionBlocked=False
```

## 3. Send your first request

### 3.1 Resolve the in-cluster gateway URL

The controller creates an Envoy service whose name includes a generated suffix, so look it up by label rather than hardcoding it:

```bash
SVC=$(kubectl get svc -n "${SYSTEM_NS}" \
  -l gateway.envoyproxy.io/owning-gateway-name="${GATEWAY_NAME}" \
  -o jsonpath='{.items[0].metadata.name}')

export GW="http://${SVC}.${SYSTEM_NS}.svc.cluster.local"
echo "${GW}"
```

Expected output:

```
http://envoy-hyperpod-inference-system-inference-gateway-demo-de027949.hyperpod-inference-system.svc.cluster.local
```

### 3.2 Invoke the model

Send the request from a pod inside the cluster:

```bash
kubectl run curl-invoke --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 -n "${MODEL_NS}" -- \
  curl -sS -w '\nHTTP %{http_code}\n' --max-time 60 \
  -X POST "${GW}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-1.5B-Instruct","prompt":"What is SageMaker HyperPod?","max_tokens":20,"temperature":0}'
```

Expected output:

```json
{"id":"cmpl-3a1cb58a-0c94-42e7-bbf8-36562f0f40b3","object":"text_completion","created":1788380097,"model":"Qwen/Qwen2.5-1.5B-Instruct","choices":[{"index":0,"text":" It is a fully managed service that makes it easy to train","logprobs":null,"finish_reason":"length","stop_reason":null,"prompt_logprobs":null}],"usage":{"prompt_tokens":6,"total_tokens":26,"completion_tokens":20}}
HTTP 200
```

:::info
Run `curl` from a pod inside the cluster. The `.svc.cluster.local` name will not resolve from your laptop. The gateway also provisions internal load balancers, which are reachable only from inside the VPC.
:::

## Validation

You have completed this page when:

- The `InferenceEndpointConfig` pod is `3/3 Running` with the label `app=vllm-qwen`
- `Accepted`, `Ready`, and `GatewayProgrammed` are all `True`
- A POST to `/v1/completions` returns HTTP 200 with a completion

## Next steps

Continue to [Inspect the gateway](./02-gateway-anatomy.md) to see every resource the controller created on your behalf.
