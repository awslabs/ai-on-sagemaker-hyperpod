---
title: Deploy Dynamo with LMCache
sidebar_position: 3
sidebar_label: Dynamo
---

# Deploy Dynamo with LMCache

This example runs a Dynamo frontend and Dynamo vLLM worker on HyperPod. The vLLM worker uses LMCache to read and write KV cache through the HyperPod managed tiered-storage daemon.

## Deploy

Download or copy `dynamo-vllm-lmcache-hyperpod.yaml`, then apply it:

```bash
kubectl apply -f dynamo-vllm-lmcache-hyperpod.yaml
kubectl rollout status deployment/dynamo-lmcache-frontend -n dynamo-hp-lmcache --timeout=15m
kubectl rollout status deployment/dynamo-lmcache-worker -n dynamo-hp-lmcache --timeout=15m
```

The manifest runs the Dynamo frontend and vLLM worker as separate Deployments. For this single-node example, both pods share a node-local file-discovery directory. For production multi-node deployments, use a production discovery backend such as etcd or DNS.

## Test The Frontend

Start the frontend port-forward:

```bash
kubectl port-forward -n dynamo-hp-lmcache svc/dynamo-lmcache-frontend 18000:8000
```

In a second terminal, start the worker metrics port-forward:

```bash
kubectl port-forward -n dynamo-hp-lmcache svc/dynamo-lmcache-worker-metrics 18081:8081
```

Then query the frontend:

```bash
curl -s http://127.0.0.1:18000/v1/models
curl -s http://127.0.0.1:18000/health
```

The health response should list a backend `generate` endpoint:

```text
dyn://dynamo-hp-lmcache.backend.generate
```

## Prove L2 Reuse

Download or copy `validate-kv-cache-reuse.py`, then run the shared probe:

```bash
python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18081/metrics \
  --phase store \
  --output dynamo-store.json

kubectl rollout restart deployment/dynamo-lmcache-worker -n dynamo-hp-lmcache
kubectl rollout status deployment/dynamo-lmcache-worker -n dynamo-hp-lmcache --timeout=15m

python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18081/metrics \
  --phase replay \
  --output dynamo-replay.json
```

Expected replay evidence:

```text
cached_tokens > 0
vllm:external_prefix_cache_hits_total > 0
lmcache:num_hit_tokens_total > 0
lmcache:num_remote_read_requests_total > 0
```

## Notes

For `nvcr.io/nvidia/ai-dynamo/vllm-runtime:1.0.1`, use vLLM's `--kv-transfer-config` form. The older `--connector lmcache` helper may be rejected by this image.
