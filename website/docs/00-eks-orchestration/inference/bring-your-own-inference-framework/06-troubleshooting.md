---
title: Troubleshooting
sidebar_position: 7
sidebar_label: Troubleshooting
---

# Troubleshooting

## LMCache Looks For `shared_memory`

The HyperPod adapter must receive the shared memory name through LMCache config:

```yaml
extra_config:
  sagemaker_hyperpod_shared_memory_name: ai_toolkit_cache
```

Passing the name only in vLLM `kv_connector_extra_config` may not be enough.

## The Shared Memory Segment Is Missing

The examples mount `/dev/shm/ai_toolkit_cache` with `hostPath.type: File`. That file must already exist on the GPU node.

If it is missing, restart the HyperPod `ai-toolkit` daemon pod on that node, then redeploy the serving workload.

## Store Works But Replay Misses

Start with the store, restart, replay commands in [Validate Cache Reuse](./05-validate-kv-cache-reuse.md), then check:

- `PYTHONHASHSEED=0` is set before the server starts.
- `save_unfull_chunk: true` is set.
- The replay prompt is byte-for-byte identical.
- You restarted only the serving pod, not the HyperPod `ai-toolkit` daemon.
- The prompt is long enough to cross the LMCache chunk threshold.

## Pod Does Not Schedule

The example manifests use `g6-workers` as the HyperPod instance-group label. If your cluster uses a different GPU instance group, update:

```yaml
nodeSelector:
  sagemaker.amazonaws.com/instance-group-name: g6-workers
```
