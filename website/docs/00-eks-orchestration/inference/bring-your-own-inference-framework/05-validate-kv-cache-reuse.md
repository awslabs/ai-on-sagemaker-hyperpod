---
title: Validate KV Cache Reuse
sidebar_position: 6
sidebar_label: Validate Cache Reuse
---

# Validate KV Cache Reuse

The core test is the same for every framework:

1. Send a deterministic prompt.
2. Confirm the serving process stores KV cache to HyperPod L2.
3. Restart the serving deployment.
4. Replay the exact same prompt.
5. Confirm the replay reads from L2.

## Why Restart?

Restarting the serving pod clears process-local state and GPU KV cache. If replay shows a hit after restart, the surviving source is the HyperPod managed tiered-storage daemon.

## Shared Probe

Download or copy `validate-kv-cache-reuse.py`. For OpenAI-compatible vLLM paths, pass the metrics URL that matches the framework service you port-forwarded:

| Framework | Metrics URL |
| --- | --- |
| Dynamo | `http://127.0.0.1:18081/metrics` |
| llm-d | `http://127.0.0.1:18000/metrics` |
| SGLang | Omit `--metrics-url`; use log-based evidence |

For Dynamo:

```bash
python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18081/metrics \
  --phase store \
  --output store.json
```

For llm-d:

```bash
python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18000/metrics \
  --phase store \
  --output store.json
```

Then restart the serving deployment and replay with the same framework-specific metrics URL. Dynamo uses the worker metrics service:

```bash
python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18081/metrics \
  --phase replay \
  --output replay.json
```

llm-d exposes metrics on the same service as the OpenAI-compatible API:

```bash
python3 validate-kv-cache-reuse.py \
  --base-url http://127.0.0.1:18000 \
  --metrics-url http://127.0.0.1:18000/metrics \
  --phase replay \
  --output replay.json
```

For SGLang, add `--endpoint-mode sglang` and omit `--metrics-url` unless you expose framework metrics separately.

## Inspect Replay Evidence

The probe writes the response usage and selected metrics into the replay artifact. Start there:

```bash
jq '.request.usage, .selected_metrics_after[]?' replay.json
```

For vLLM-based examples, also query the metrics endpoint directly while the port-forward is still running:

```bash
curl -s http://127.0.0.1:18081/metrics | grep -E 'vllm:external_prefix_cache|lmcache:num_hit_tokens|lmcache:num_remote_read'
```

If the vLLM service exposes metrics on the same port as the OpenAI API, use:

```bash
curl -s http://127.0.0.1:18000/metrics | grep -E 'vllm:external_prefix_cache|lmcache:num_hit_tokens|lmcache:num_remote_read'
```

For log-based confirmation, check the serving deployment logs after the replay request:

```bash
kubectl logs -n dynamo-hp-lmcache deployment/dynamo-lmcache-worker --since=10m | grep -E 'Retrieved [0-9]+ out of|LMCache|remote read'
kubectl logs -n llm-d-hp-lmcache deployment/llmd-lmcache-decode --since=10m | grep -E 'Retrieved [0-9]+ out of|LMCache|remote read'
kubectl logs -n sglang-hp-lmcache deployment/sglang-lmcache --since=10m | grep -E 'LMCache retrieve|cached_tokens|remote read'
```

The strongest replay proof is a post-restart request with nonzero cached tokens plus LMCache remote-read or retrieve evidence.

## Passing Signals

Strong passing signals:

```text
usage.prompt_tokens_details.cached_tokens > 0
vllm:external_prefix_cache_hits_total > 0
lmcache:num_hit_tokens_total > 0
lmcache:num_remote_read_requests_total > 0
Retrieved N out of N required tokens
```

Store-only signals:

```text
lmcache:num_stored_tokens_total > 0
lmcache:num_remote_write_requests_total > 0
PUT success
```

Store-only signals prove the write path, but not L2 reuse. A complete pass requires post-restart read evidence.
