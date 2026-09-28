---
title: Deploy SGLang with LMCache
sidebar_position: 5
sidebar_label: SGLang
---

# Deploy SGLang with LMCache

This example runs SGLang on HyperPod and uses LMCache to read and write KV cache through the HyperPod managed tiered-storage daemon.

## Deploy

Download or copy `sglang-lmcache-hyperpod.yaml`, then apply it:

```bash
kubectl apply -f sglang-lmcache-hyperpod.yaml
kubectl rollout status deployment/sglang-lmcache -n sglang-hp-lmcache --timeout=15m
```

The example uses `lmsysorg/sglang:v0.5.15-cu130`, installs `lmcache==0.5.1` at startup, and launches SGLang with:

```text
--enable-lmcache --lmcache-config-file /tmp/lmcache.yaml
```

## Validate

```bash
kubectl port-forward -n sglang-hp-lmcache svc/sglang-lmcache 18000:8000
```

Download or copy `validate-kv-cache-reuse.py`. SGLang exposes a `/generate` endpoint. Send a deterministic long prefix, restart the pod, then replay the exact same prompt:

```bash
python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --endpoint-mode sglang \
  --phase store \
  --output sglang-store.json

kubectl rollout restart deployment/sglang-lmcache -n sglang-hp-lmcache
kubectl rollout status deployment/sglang-lmcache -n sglang-hp-lmcache --timeout=15m

python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --endpoint-mode sglang \
  --phase replay \
  --output sglang-replay.json
```

Expected replay evidence:

```text
cached_tokens > 0
LMCache retrieve started
```

## SGLang-Specific Notes

SGLang's LMCache integration may need IP mode to pass the full LMCache config, including `remote_url`, to LMCache. This workaround was validated with `lmsysorg/sglang:v0.5.15-cu130` and `lmcache==0.5.1`. The example manifest guards and then patches SGLang's LMCache mode at startup, and sets `use_layerwise: true` in the LMCache config.

If a newer SGLang release exposes LMCache IP mode through a CLI or config option, prefer that over the startup patch.
