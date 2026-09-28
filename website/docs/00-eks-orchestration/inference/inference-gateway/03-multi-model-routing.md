---
title: Multi-Model Routing with Body-Based Routing
sidebar_position: 4
sidebar_label: Multi-Model Routing
---
# Multi-model routing with body-based routing

This page adds a second model and turns on body-based routing (BBR), so that a single endpoint serves both models and routes each request by the `model` field in its body. You will then prove from logs that routing was correct.

## Overview

Body-based routing inspects the request body, extracts the `model` value, and selects the scheduler whose `modelName` matches. Each scheduler owns its own pool of backend pods.

You will:

1. Deploy a second model as a plain Kubernetes `Deployment`
2. Replace the gateway config with a two-scheduler config with BBR enabled
3. Send one request per model and verify each landed on the correct backend

The second model is deployed with a plain `Deployment` rather than the operator on purpose. The gateway selects backends **by label**, so it does not care how the pods were created.

## 1. Deploy the second model

### 1.1 Create a plain Deployment

```bash
cat <<EOF > vllm-qwen-small.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-qwen-small
  namespace: ${MODEL_NS}
  labels:
    app: vllm-qwen-small
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-qwen-small
  template:
    metadata:
      labels:
        app: vllm-qwen-small
    spec:
      containers:
        - name: vllm
          image: vllm/vllm-openai:v0.8.5
          args:
            - "--model"
            - "Qwen/Qwen2.5-0.5B-Instruct"
            - "--port"
            - "8000"
            - "--max-model-len"
            - "4096"
            - "--gpu-memory-utilization"
            - "0.4"
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet:
              path: /ping
              port: 8000
            periodSeconds: 10
            failureThreshold: 3
          resources:
            limits:
              nvidia.com/gpu: "1"
EOF

kubectl apply -f vllm-qwen-small.yaml
kubectl rollout status deploy/vllm-qwen-small -n "${MODEL_NS}" --timeout=600s
```

:::warning
Include the `readinessProbe`. Without one, `kubectl rollout status` reports success while vLLM is still loading the model and the port is still refusing connections, and your first request fails for no apparent reason. The inference operator adds this probe automatically; a hand-written `Deployment` does not.
:::

### 1.2 Confirm both backends are serving

```bash
kubectl get pods -n "${MODEL_NS}" -l 'app in (vllm-qwen,vllm-qwen-small)'
```

Expected output:

```
NAME                               READY   STATUS    RESTARTS   AGE
vllm-qwen-68c5644b78-r8cnl         3/3     Running   0          20m
vllm-qwen-small-85dbd7577f-fj8sl   1/1     Running   0          3m
```

One is `3/3` (operator, with sidecars) and one is `1/1` (plain `Deployment`). The gateway treats them identically.

## 2. Enable body-based routing

### 2.1 Delete the existing config

```bash
kubectl delete inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}"
```

### 2.2 Apply a two-scheduler config

```bash
cat <<EOF > gateway-bbr.yaml
apiVersion: inference.sagemaker.aws.amazon.com/v1alpha1
kind: InferenceGatewayConfig
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${MODEL_NS}
spec:
  bbr:
    enabled: true
  schedulers:
    - name: qwen
      modelName: "Qwen/Qwen2.5-1.5B-Instruct"
      modelSelector:
        matchLabels:
          app: vllm-qwen
      targetPort: 8000
      scheduler: llm-d
    - name: qwen-small
      modelName: "Qwen/Qwen2.5-0.5B-Instruct"
      modelSelector:
        matchLabels:
          app: vllm-qwen-small
      targetPort: 8000
      scheduler: llm-d
EOF

kubectl apply -f gateway-bbr.yaml
```

### 2.3 Confirm the new data plane

```bash
kubectl get inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}" \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'

kubectl get pods -n "${MODEL_NS}" | grep epp
kubectl get pods -n "${SYSTEM_NS}" | grep bbr
```

Expected output:

```
Accepted=True
Ready=True
GatewayProgrammed=True
BBRReady=True
AdmissionBlocked=False

qwen-epp-5495b88866-sdnff         1/1   Running   0   45s
qwen-small-epp-64646b99d6-drrqj   1/1   Running   0   45s

inference-gateway-demo-bbr-7dc6ffbbcb-s5wh5   1/1   Running   0   45s
```

Two schedulers now means two endpoint pickers, plus a BBR pod in the system namespace.

## 3. Send one request per model

Re-resolve the gateway URL, since the Envoy service was recreated:

```bash
SVC=$(kubectl get svc -n "${SYSTEM_NS}" \
  -l gateway.envoyproxy.io/owning-gateway-name="${GATEWAY_NAME}" \
  -o jsonpath='{.items[0].metadata.name}')
export GW="http://${SVC}.${SYSTEM_NS}.svc.cluster.local"
```

### 3.1 Request the 1.5B model

```bash
kubectl run curl-a --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 -n "${MODEL_NS}" -- \
  curl -sS --max-time 60 -X POST "${GW}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-1.5B-Instruct","prompt":"What is SageMaker?","max_tokens":20,"temperature":0}'
```

### 3.2 Request the 0.5B model

```bash
kubectl run curl-b --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 -n "${MODEL_NS}" -- \
  curl -sS --max-time 60 -X POST "${GW}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-0.5B-Instruct","prompt":"What is SageMaker?","max_tokens":20,"temperature":0}'
```

Both return HTTP 200, and each response echoes the model that served it:

```json
{"id":"cmpl-12795f39-...","model":"Qwen/Qwen2.5-1.5B-Instruct","choices":[...]}
{"id":"cmpl-1879bfc7-...","model":"Qwen/Qwen2.5-0.5B-Instruct","choices":[...]}
```

**Record the `id` from each response.** They are used next to prove routing.

## 4. Prove routing from logs

Two independent sources confirm where a request went.

### 4.1 Endpoint picker logs (authoritative)

The endpoint picker logs the request id alongside the model it resolved. Match the `cmpl-` id from each response:

```bash
for epp in qwen-epp qwen-small-epp; do
  echo "--- ${epp}"
  kubectl logs -n "${MODEL_NS}" -l app=${epp} --tail=-1 --since=15m \
    | grep -oE '"x-request-id":"[a-f0-9-]+","modelName":"[^"]+"'
done
```

Expected output:

```
--- qwen-epp
"x-request-id":"12795f39-19b3-4ead-9c18-6873402930f0","modelName":"Qwen/Qwen2.5-1.5B-Instruct"
--- qwen-small-epp
"x-request-id":"1879bfc7-ca1f-4e92-99bb-06d67c571960","modelName":"Qwen/Qwen2.5-0.5B-Instruct"
```

Each request id appears in exactly one endpoint picker's log, with the matching model name. That is the routing proof: no cross-contamination between pools.

:::tip
`--since=15m` is a lookback window over the log, not a filter on your request. If you paused between steps and the requests are now older than that, `grep` matches nothing and the loop prints just its two `--- ` headers, which reads like routing failed. Widen the window to `--since=1h`, or drop the flag entirely to search the whole log, before concluding anything is wrong.
:::

### 4.2 Backend access logs (corroborating)

The vLLM pods also log the request:

```bash
kubectl logs -n "${MODEL_NS}" -l app=vllm-qwen --tail=-1 --prefix \
  | grep 'POST /v1/completions'
```

Expected output:

```
[pod/vllm-qwen-68c5644b78-r8cnl/vllm-qwen] INFO:     10.1.39.21:40202 - "POST /v1/completions HTTP/1.1" 200 OK
```

## 5. Requesting an unknown model

Ask for a model no scheduler serves:

```bash
kubectl run curl-neg --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 -n "${MODEL_NS}" -- \
  curl -sS -w '\nHTTP %{http_code}\n' --max-time 45 \
  -X POST "${GW}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"does-not-exist","prompt":"hi","max_tokens":5}'
```

Expected output:

```
no matching model: set the model in the request body or the x-gateway-model-name header
HTTP 404
```

The gateway rejects it before any backend is involved — no endpoint picker logs it and no vLLM pod sees it.

:::info
This gateway-level `404` depends on BBR being enabled. BBR is what matches the body's `model` value against each scheduler's `modelName`, so it is also what can find no match and reject the request.

With a single scheduler and BBR disabled, as on [Deploy your first gateway](./01-first-gateway.md), no model matching happens at all. The gateway forwards every request to its one pool, and a bad model name surfaces at the backend instead as a vLLM `NotFoundError`. See [Troubleshooting §2.2](./05-cleanup-and-troubleshooting.md#22-requests-return-404) for both variants.
:::

## Validation

You have completed this page when:

- Both backends are `Running`, one from the operator and one from a plain `Deployment`
- `BBRReady=True`, with two endpoint pickers and one BBR pod
- Each response `id` appears in exactly one endpoint picker log with the matching `modelName`
- An unknown model returns a gateway-level `404`

## Next steps

Both pools have a single replica so far, so the endpoint picker has had no real choice to make. Continue to [Endpoint picking](./04-endpoint-picking.md) to give it one.
