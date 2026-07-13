---
title: Deploy llm-d with LMCache
sidebar_position: 4
sidebar_label: llm-d
---

# Deploy llm-d with LMCache

This example uses llm-d as the serving framework and configures its vLLM model server to use LMCache with HyperPod managed tiered storage.

## Deploy

Install llm-d following the upstream llm-d guide for your gateway provider and model service. Then apply the HyperPod LMCache overlay in `llm-d-vllm-lmcache-hyperpod.yaml`.

At minimum, the model server must include:

- `LMCacheConnectorV1` in vLLM `--kv-transfer-config`
- `LMCACHE_REMOTE_URL=sagemaker-hyperpod://$(NODE_IP):9200`
- `LMCACHE_CONFIG_FILE=/etc/lmcache/config.yaml`
- A file mount for `/dev/shm/ai_toolkit_cache`

For a minimal model-server deployment:

```bash
kubectl apply -f llm-d-vllm-lmcache-hyperpod.yaml
kubectl rollout status deployment/llmd-lmcache-decode -n llm-d-hp-lmcache --timeout=15m
```

## Validate

Port-forward the llm-d gateway or the model server service, depending on your deployment:

```bash
kubectl port-forward -n llm-d-hp-lmcache svc/llmd-lmcache-decode 18000:8000
```

Download or copy `validate-kv-cache-reuse.py`, then run the shared probe:

```bash
python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18000/metrics \
  --phase store \
  --output llmd-store.json

kubectl rollout restart deployment/llmd-lmcache-decode -n llm-d-hp-lmcache
kubectl rollout status deployment/llmd-lmcache-decode -n llm-d-hp-lmcache --timeout=15m

python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18000/metrics \
  --phase replay \
  --output llmd-replay.json
```

Expected replay evidence:

```text
cached_tokens > 0
external_prefix_cache_hits_total > 0
Retrieved N out of N required tokens
```

## Notes

If the llm-d gateway or router runs on a non-HyperPod node, verify pod-to-pod routing to the HyperPod GPU node. In restricted network layouts, colocating the gateway/router path with the HyperPod node may be required.
