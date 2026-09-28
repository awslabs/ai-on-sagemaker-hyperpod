---
title: HyperPod Managed KV Cache with LMCache
sidebar_position: 2
sidebar_label: Managed KV Cache
---

# HyperPod Managed KV Cache with LMCache

All framework examples in this section use the same LMCache configuration to connect to the HyperPod managed tiered-storage daemon.

## Prerequisites

- A SageMaker HyperPod EKS cluster with a GPU instance group
- Tiered storage enabled on the HyperPod cluster
- `kubectl` configured for the HyperPod EKS cluster
- A GPU node where the `ai-toolkit` daemon has created `/dev/shm/ai_toolkit_cache`

When creating or updating a HyperPod cluster, tiered storage is enabled with a `TieredStorageConfig` block. For example:

```json
{
  "Mode": "Enable",
  "InstanceMemoryAllocationPercentage": 20
}
```

## Shared LMCache Config

Use this shared configuration shape:

```yaml
chunk_size: 256
local_cpu: true
max_local_cpu_size: 4
save_unfull_chunk: true
remote_url: "sagemaker-hyperpod://PLACEHOLDER_NODE_IP:9200"
remote_serde: "naive"
extra_config:
  sagemaker_hyperpod_shared_memory_name: ai_toolkit_cache
```

For vLLM-based examples, `remote_url` is supplied by the `LMCACHE_REMOTE_URL` environment variable:

```bash
LMCACHE_REMOTE_URL=sagemaker-hyperpod://$(NODE_IP):9200
```

SGLang reads `remote_url` from its LMCache config file, so the SGLang example renders the node IP into the file at container startup.

The serving pod should get `NODE_IP` from the Kubernetes downward API:

```yaml
- name: NODE_IP
  valueFrom:
    fieldRef:
      fieldPath: status.hostIP
```

## Manifest Mapping

The settings above are translated into the example manifests as follows:

| Intent | Manifest field |
| --- | --- |
| Enable HyperPod L2 KV cache storage | HyperPod cluster `TieredStorageConfig` before applying the workload manifest |
| Point LMCache at the node-local HyperPod daemon | `LMCACHE_REMOTE_URL=sagemaker-hyperpod://$(NODE_IP):9200` for vLLM, or `remote_url` in the SGLang LMCache config file |
| Resolve `$(NODE_IP)` to the GPU node host IP | `env[].valueFrom.fieldRef.fieldPath: status.hostIP` |
| Tell LMCache the HyperPod shared-memory segment name | `extra_config.sagemaker_hyperpod_shared_memory_name: ai_toolkit_cache` |
| Keep partial prompt chunks available for the restart/replay proof | `save_unfull_chunk: true` |
| Mount the HyperPod daemon shared-memory segment into the serving pod | `volumeMounts[].mountPath: /dev/shm/ai_toolkit_cache` with `hostPath.type: File` |
| Keep replay keys stable across process restart | `PYTHONHASHSEED=0` |

For Dynamo and llm-d, these fields are in the workload manifest ConfigMap and container environment. For SGLang, the manifest renders the node IP into the LMCache config file before launching the server.

## Shared Memory Mount

Mount the daemon-owned shared memory file, not the whole `/dev/shm` directory:

```yaml
volumeMounts:
  - name: hp-tiered-cache
    mountPath: /dev/shm/ai_toolkit_cache

volumes:
  - name: hp-tiered-cache
    hostPath:
      path: /dev/shm/ai_toolkit_cache
      type: File
```

Mounting the whole `/dev/shm` directory can allow a terminating client process to unlink the daemon-owned segment. The examples use a file mount to avoid that failure mode.

## Runtime Settings

Use `PYTHONHASHSEED=0` for deterministic store, restart, replay validation. The replay request must produce the same LMCache keys after the serving process restarts:

```yaml
- name: PYTHONHASHSEED
  value: "0"
```

## Validation

A successful L2 validation requires a store, restart, replay flow:

1. Send a deterministic prompt through the framework frontend.
2. Confirm LMCache stores the prompt KV cache to HyperPod L2.
3. Restart only the serving pod or deployment.
4. Replay the exact same prompt.
5. Confirm a cache hit after restart.

Use [Validate Cache Reuse](./05-validate-kv-cache-reuse.md) for the commands and metrics/log checks.
