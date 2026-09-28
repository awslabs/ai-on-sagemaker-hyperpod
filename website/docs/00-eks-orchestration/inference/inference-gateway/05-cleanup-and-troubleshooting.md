---
title: Cleanup and Troubleshooting
sidebar_position: 6
sidebar_label: Cleanup and Troubleshooting
---
# Cleanup and troubleshooting

## 1. Cleanup

### 1.1 Delete the gateway config

Deleting the `InferenceGatewayConfig` garbage collects the whole data plane it created — the `Gateway`, the Envoy proxy and service, the BBR deployment, the endpoint pickers, and the generated `InferencePool` and `HTTPRoute` resources:

```bash
kubectl delete inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}"
```

Confirm the data plane is gone:

```bash
kubectl get pods -n "${MODEL_NS}" | grep -E 'epp|bbr'
kubectl get svc -n "${SYSTEM_NS}" | grep envoy
```

Both should return nothing. Your model deployments keep running — the gateway and the models have independent lifecycles.

### 1.2 Delete the model backends

```bash
kubectl delete inferenceendpointconfig vllm-qwen -n "${MODEL_NS}"
kubectl delete deploy vllm-qwen-small -n "${MODEL_NS}"
```

### 1.3 Delete the namespace

```bash
kubectl delete namespace "${MODEL_NS}"
```

:::info
The add-on itself is left in place. Removing it would tear down the control plane shared by every gateway in the cluster.
:::

## 2. Troubleshooting

### 2.1 Gateway config rejected on apply

**`bbr must be enabled when more than one scheduler is defined`**

Set `bbr.enabled: true`. This is required for any config with two or more schedulers, and is enforced at admission.

**`strict decoding error: unknown field "spec.<name>"`**

The CRD schema is closed, so unknown fields are rejected rather than ignored. Check the field against the live schema:

```bash
kubectl explain inferencegatewayconfig.spec --recursive
```

Validate a config without persisting it:

```bash
kubectl apply --dry-run=server -f your-config.yaml
```

### 2.2 Requests return 404

**`no matching model: set the model in the request body or the x-gateway-model-name header`**

The gateway found no scheduler whose `modelName` matches the request body's `model` value. Compare the two:

```bash
kubectl get inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}" \
  -o jsonpath='{range .spec.schedulers[*]}{.name}{" -> "}{.modelName}{"\n"}{end}'
```

**A vLLM `NotFoundError` instead of the gateway message**

The request reached a backend, which then rejected the model name. With a single scheduler and BBR disabled the gateway does no model matching and forwards everything to its one pool, so a bad model name surfaces at the backend rather than at the gateway.

### 2.3 Gateway ready but requests fail

Check that the scheduler's `modelSelector` actually matches running pods:

```bash
kubectl get pods -n "${MODEL_NS}" -l app=vllm-qwen
kubectl get inferencepool -n "${MODEL_NS}"
kubectl get endpointslice -n "${MODEL_NS}"
```

A scheduler whose selector matches nothing still reports `Ready`, because the config is valid — there are simply no endpoints to route to.

### 2.4 First request fails right after deploying a model

The pod is `Running` but vLLM is still loading. This happens when a hand-written `Deployment` has no readiness probe, in which case `kubectl rollout status` returns success prematurely. Add one:

```yaml
readinessProbe:
  httpGet:
    path: /ping
    port: 8000
  periodSeconds: 10
  failureThreshold: 3
```

Models deployed through the inference operator get an equivalent probe automatically.

### 2.5 Cannot resolve the gateway hostname

```
curl: (6) Could not resolve host: envoy-...svc.cluster.local
```

The `.svc.cluster.local` name resolves only inside the cluster. Run `curl` from a pod, as every example here does. The load balancers the gateway provisions are `internal` in scheme, so they are reachable from inside the VPC but not from a laptop.

### 2.6 Cannot find POST lines in backend logs

Model pods emit roughly 40 `GET /metrics` lines per second, and `kubectl logs -l <selector>` defaults to `--tail=10`. Request all lines and identify the pod:

```bash
kubectl logs -n "${MODEL_NS}" -l app=vllm-qwen --tail=-1 --prefix \
  | grep 'POST /v1/completions'
```

## 3. Useful commands

```bash
# Gateway status conditions
kubectl get inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}" \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'

# Controller reconciliation log
kubectl logs -n "${SYSTEM_NS}" deploy/inference-gateway-controller --tail=200

# Routing evidence from an endpoint picker
# --since is a lookback window; widen it if the request was issued a while ago
kubectl logs -n "${MODEL_NS}" -l app=qwen-epp --tail=-1 --since=15m \
  | grep -oE '"x-request-id":"[a-f0-9-]+","modelName":"[^"]+"'

# Per-pod request and prefix-cache counters
curl -s http://<pod-ip>:8000/metrics \
  | grep -E '^vllm:(request_success_total|gpu_prefix_cache_hits_total|gpu_prefix_cache_queries_total)'
```

## Related guides

- [Inference Operator](../inference-operator/sagemaker-jumpstart.md)
- [Inference with Load Balancer](../load-balancer-inference/inference-with-loadbalancer.md)
- [Bring Your Own Inference Framework](../bring-your-own-inference-framework/00-overview.md)
