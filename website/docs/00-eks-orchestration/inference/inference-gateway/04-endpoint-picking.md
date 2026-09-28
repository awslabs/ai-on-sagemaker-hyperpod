---
title: Endpoint Picking Across Replicas
sidebar_position: 5
sidebar_label: Endpoint Picking
---
# Endpoint picking across replicas

Body-based routing decides *which pool* serves a request. Within that pool, the endpoint picker decides *which pod*. Everything so far ran at one replica per model, so that second decision had only one candidate. This page gives it a real choice.

## Overview

A plain Kubernetes `Service` distributes round-robin, which is the wrong default for LLM inference:

- **Requests have wildly unequal cost.** Prompt and output length vary by orders of magnitude; round-robin ignores that.
- **vLLM queues.** A saturated replica keeps queueing while an idle one sits free.
- **KV cache and prefix reuse.** If a replica already holds the KV blocks for a shared prompt prefix — a system prompt, a few-shot block, conversation history — sending a matching request there skips prefill entirely. That is a large first-token latency win, and round-robin destroys it.

Those three concerns map onto the scheduler's `weights` field.

### Available scorers

```bash
kubectl explain inferencegatewayconfig.spec.schedulers.weights
```

| Weight | Scores on |
| --- | --- |
| `queue` | Pending request queue depth |
| `kvCache` | KV cache utilization |
| `prefix` | Shared prompt prefix already cached on the pod |
| `runningRequests` | Requests currently in flight |
| `loraAffinity` | LoRA adapter already loaded on the pod |
| `predictedLatency` | Predicted request latency |
| `lru` | Least-recently-used spreading (valid only when `scheduler: llm-d`) |

Omitting `weights` uses defaults, which is what the previous page did.

## 1. Scale a model to two replicas

Scale the plain `Deployment`:

```bash
kubectl scale deploy vllm-qwen-small -n "${MODEL_NS}" --replicas=2
kubectl rollout status deploy/vllm-qwen-small -n "${MODEL_NS}" --timeout=600s
```

Confirm both replicas are serving:

```bash
kubectl get pods -n "${MODEL_NS}" -l app=vllm-qwen-small \
  -o custom-columns='POD:.metadata.name,READY:.status.containerStatuses[*].ready,IP:.status.podIP'
```

Expected output:

```
POD                                READY   IP
vllm-qwen-small-85dbd7577f-7b2zl   true    10.1.39.66
vllm-qwen-small-85dbd7577f-fj8sl   true    10.1.71.86
```

:::info
This example needs a third GPU, since both models are running. If your node group has only two, scale `vllm-qwen` to zero first with `kubectl scale deploy vllm-qwen -n "${MODEL_NS}" --replicas=0`.
:::

## 2. Read the per-pod counters

vLLM exposes both a request counter and prefix-cache statistics per pod. These are easier to read than parsing access logs:

```bash
for ip in $(kubectl get pods -n "${MODEL_NS}" -l app=vllm-qwen-small \
  -o jsonpath='{range .items[*]}{.status.podIP}{" "}{end}'); do
  echo "--- ${ip}"
  kubectl run "counters-${ip//./-}" --rm -i --restart=Never \
    --image=curlimages/curl:8.10.1 -n "${MODEL_NS}" -- \
    curl -sS -m 15 "http://${ip}:8000/metrics" \
    | grep -E '^vllm:(request_success_total|gpu_prefix_cache_hits_total|gpu_prefix_cache_queries_total)'
done
```

| Metric | Meaning |
| --- | --- |
| `vllm:request_success_total` | Requests completed by this pod |
| `vllm:gpu_prefix_cache_queries_total` | Prefix cache lookups, in blocks |
| `vllm:gpu_prefix_cache_hits_total` | Prefix cache hits, in blocks |

The hit rate is `hits_total / queries_total`. Record these values before each batch below and diff them afterwards.

## 3. Send a shared-prefix batch

Send a batch of requests that all begin with the same long prefix. A simple serial loop is enough — prefix affinity is driven by cache state, not by concurrency, so no load generator is required.

```bash
kubectl run batch-shared --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 -n "${MODEL_NS}" -- sh -c '
GW="'"${GW}"'"
# ~700 token shared preamble, identical for every request
P="You are an expert cloud infrastructure assistant specialising in Kubernetes and LLM serving."
i=1; while [ $i -le 40 ]; do
  P="$P Guideline $i: consider scheduling, queue depth, KV cache reuse, prefix affinity, GPU memory pressure, and endpoint selection when advising on inference architecture."
  i=$((i+1))
done
n=1; while [ $n -le 12 ]; do
  BODY=$(printf "{\"model\":\"Qwen/Qwen2.5-0.5B-Instruct\",\"prompt\":\"%s Question %s: name one factor.\",\"max_tokens\":4,\"temperature\":0}" "$P" "$n")
  printf "%s" "$BODY" | curl -sS -o /dev/null -m 60 -w "%{http_code} " \
    -X POST "$GW/v1/completions" -H "Content-Type: application/json" --data-binary @-
  n=$((n+1))
done
echo'
```

Now re-read the counters from step 2 and compute the deltas.

Expected result:

Every request went to a single pod, and that pod served a high prefix-cache hit rate (~92% in our run; run-dependent)

## 4. Compare against unique prefixes

Re-run the batch with a unique prefix per request, so there is no shared prefix to reuse. The only change from the previous batch is that the preamble is rebuilt **inside** the request loop and seeded with `$n`, so the leading tokens differ every time:

```bash
kubectl run batch-unique --rm -i --restart=Never \
  --image=curlimages/curl:8.10.1 -n "${MODEL_NS}" -- sh -c '
GW="'"${GW}"'"
n=1; while [ $n -le 12 ]; do
  # rebuilt per request, so no two prompts share leading tokens
  P="Request $n context:"
  j=1; while [ $j -le 40 ]; do
    P="$P Unique-$n-segment-$j padding text for request $n segment $j with no shared leading tokens."
    j=$((j+1))
  done
  BODY=$(printf "{\"model\":\"Qwen/Qwen2.5-0.5B-Instruct\",\"prompt\":\"%s Question %s: name one factor.\",\"max_tokens\":4,\"temperature\":0}" "$P" "$n")
  printf "%s" "$BODY" | curl -sS -o /dev/null -m 60 -w "%{http_code} " \
    -X POST "$GW/v1/completions" -H "Content-Type: application/json" --data-binary @-
  n=$((n+1))
done
echo'
```

Read the counters again and compute the deltas as in step 2.

Expected result:

Requests are distributed between the two pods.

## 5. Turn prefix scoring off

The clearest demonstration is to disable prefix scoring and re-send the identical shared-prefix batch.

```bash
kubectl delete inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}"

cat <<EOF > gateway-no-prefix.yaml
apiVersion: inference.sagemaker.aws.amazon.com/v1alpha1
kind: InferenceGatewayConfig
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${MODEL_NS}
spec:
  bbr:
    enabled: false
  schedulers:
    - name: qwen-small
      modelName: "Qwen/Qwen2.5-0.5B-Instruct"
      modelSelector:
        matchLabels:
          app: vllm-qwen-small
      targetPort: 8000
      scheduler: llm-d
      weights:
        prefix: 0
        queue: 3
        kvCache: 2
EOF

kubectl apply -f gateway-no-prefix.yaml
```

Wait for the Gateway to become ready:

```bash
kubectl get inferencegatewayconfig "${GATEWAY_NAME}" -n "${MODEL_NS}" \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
```


Then, send the same shared-prefix batch again (step 3).

Expected result:

Requests are distributed between the two pods.

Turning prefix scoring off flips total concentration into a split. This is the most direct evidence that the `weights` field drives real routing behaviour.

## Validation

You have completed this page when you can:

- Predict the distribution change before running the `prefix: 0` comparison
- Explain the 92% to 0% hit-rate difference in terms of KV cache reuse
- Explain why concentration on one pod is correct behaviour for shared-prefix traffic

## Next steps

Continue to [Cleanup and troubleshooting](./05-cleanup-and-troubleshooting.md).
