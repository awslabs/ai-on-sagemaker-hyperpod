---
title: Placeholder Deployment
sidebar_position: 5
---

# Placeholder Deployment

The placeholder Deployment keeps "warm" pods running on pre-provisioned nodes. It also pre-pulls the SageMaker Distribution image onto each warm node using an `initContainer`, so the image is already cached by the time a real Workspace lands.

## Design Decisions

| Setting | Value | Why |
|---|---|---|
| `priorityClassName` | `overprovisioning-placeholder` (`-1000`) | Preemptable by any real Workspace pod (default priority `0`) |
| `terminationGracePeriodSeconds` | `0` | Evicted instantly - no delay when a Workspace needs the node |
| `nodeAffinity` | `node.kubernetes.io/instance-type` or NodePool label | Ensures placeholders land on the target instance family / NodePool |
| `podAntiAffinity` | `requiredDuringScheduling` on `kubernetes.io/hostname` | **One placeholder per node** - forces Karpenter to provision separate nodes |
| `initContainer.image` | `${WORKSPACE_IMAGE}` | Pulls the Workspace image onto the node at startup; cached by containerd for subsequent Workspaces |
| `initContainer.imagePullPolicy` | `IfNotPresent` | Only pulls if the image is not already cached on the node |
| Main container image | `registry.k8s.io/pause:3.9` | Minimal footprint after the image pre-pull is complete |
| `karpenter.sh/do-not-disrupt` | `"true"` (annotation) | Prevents Karpenter from proactively draining warm nodes |
| CPU / memory requests | `${PLACEHOLDER_CPU_REQUEST}` / `${PLACEHOLDER_MEMORY_REQUEST}` | See sizing guidance below |

## Sizing Guidance

Read allocatable resources from one of your nodes:

```bash
NODE=$(kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE} -o name | head -1)
kubectl describe $NODE | awk '/^Allocatable:/,/^System Info:/' | head -8
```

Record the values as `NODE_ALLOCATABLE_CPU` and `NODE_ALLOCATABLE_MEMORY` in [Step 0](./02-prerequisites-and-values.md#step-0--set-your-cluster-specific-values). Then pick one of the two sizing strategies below.

### Option A - Small placeholder (recommended default)

Set placeholder requests small (for example `2 vCPU` / `8 GiB`).

Workspaces smaller than `(NODE_ALLOCATABLE_CPU - PLACEHOLDER_CPU_REQUEST)` **coexist** on the same node as the placeholder - the fastest warm-start path, no preemption. Larger Workspaces preempt the placeholder.

### Option B - Large placeholder (exclusive reservation)

Set placeholder requests near the node's allocatable capacity (leaving a small margin for daemonset overhead).

Each placeholder holds an entire node exclusively. All Workspaces will preempt the placeholder - slightly slower warm-start, but you're guaranteed a full node's worth of capacity is available when needed.

:::note
The formula for the coexist/preempt threshold is `NODE_ALLOCATABLE_CPU - PLACEHOLDER_CPU_REQUEST`. Substitute values from your own node - do not use constants copied from another cluster.
:::

## Placeholder Deployment (CPU)

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spaces-placeholder-cpu
  namespace: ${OVERPROVISIONING_NS}
  labels:
    app: spaces-overprovisioning
    type: cpu
spec:
  replicas: ${CPA_MIN}        # CPA will manage this after Step 6; starts at CPA_MIN
  selector:
    matchLabels:
      app: spaces-placeholder
      type: cpu
  template:
    metadata:
      labels:
        app: spaces-placeholder
        type: cpu
      annotations:
        karpenter.sh/do-not-disrupt: "true"
        kubernetes.io/description: "Capacity reservation with image pre-warming for HyperPod CPU Spaces"
    spec:
      priorityClassName: overprovisioning-placeholder
      terminationGracePeriodSeconds: 0
      # Tolerations - add ONE ENTRY PER TAINT reported by preflight check 8.
      # Delete this block entirely if your target nodes have no taints.
      # tolerations:
      #   - key: "sagemaker.amazonaws.com/node-health-status"
      #     operator: "Equal"
      #     value: "Schedulable"
      #     effect: "NoSchedule"
      initContainers:
        - name: pull-workspace-image
          image: ${WORKSPACE_IMAGE}
          imagePullPolicy: IfNotPresent
          command:
            - "sh"
            - "-c"
            - "echo 'Workspace image pre-warmed on node '$(hostname)"
          resources:
            requests:
              cpu: "10m"
              memory: "64Mi"
            limits:
              cpu: "50m"
              memory: "128Mi"
      containers:
        - name: pause
          image: registry.k8s.io/pause:3.9
          imagePullPolicy: IfNotPresent
          resources:
            requests:
              cpu: "${PLACEHOLDER_CPU_REQUEST}"
              memory: "${PLACEHOLDER_MEMORY_REQUEST}"
            limits:
              cpu: "${PLACEHOLDER_CPU_REQUEST}"
              memory: "${PLACEHOLDER_MEMORY_REQUEST}"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node.kubernetes.io/instance-type
                    operator: In
                    values:
                      - ${INSTANCE_TYPE}
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: spaces-placeholder
              topologyKey: kubernetes.io/hostname
EOF
```

### If your NodePool allows multiple instance types

If the NodePool provisions more than one instance type (for example `ml.m5.12xlarge` and `ml.m5.24xlarge`), match on the NodePool label instead of pinning to a single instance type:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: ${NODE_LABEL_KEY}
              operator: In
              values:
                - ${NODE_LABEL_VALUE}
```

## Verify

```bash
kubectl rollout status deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS}

# Every placeholder Running, each on a DIFFERENT node
kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder -o wide

# initContainer terminated with exitCode=0 on each pod
kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.initContainerStatuses[0].state}{"\n"}{end}'
```

**Expected:** `${CPA_MIN}` pods `Running`, each on a distinct node, initContainer `Terminated` with `Completed`/`exitCode=0`.

**If a pod is stuck `Pending`:** see [Troubleshooting → Placeholder stuck Pending](./10-rollback-and-troubleshooting.md#placeholder-stuck-in-pending).

## Behaviour on a Freshly Provisioned Node

```
Node provisioned by Karpenter
  → Placeholder pod scheduled
    → initContainer runs, pulls ${WORKSPACE_IMAGE} onto the node
    → Main pause container starts - node is "warm + image-ready"
      → User creates a Space
        → Workspace pod preempts placeholder (instant scheduling)
        → Workspace image is ALREADY on the node - no pull needed
```

:::note initContainer resource requests are not additive
Kubernetes runs init containers sequentially, so the scheduler uses `max(sum(init.requests), sum(container.requests))` for placement decisions. Since the init container above requests only `10m` CPU and `64Mi` memory, the scheduler uses the `pause` container's requests. This is the desired behaviour - the node is sized for the Space, not the pull.
:::

## Updating the Pre-pulled Image

When you update your WorkspaceTemplate to a new image tag, roll the initContainer image forward on the placeholder:

```bash
kubectl set image deployment/spaces-placeholder-cpu \
  pull-workspace-image=<new-image-uri> \
  -n ${OVERPROVISIONING_NS}

kubectl rollout status deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS}
```

Each new placeholder pod pulls the new image onto its assigned node. Old cached images remain on the node until kubelet's image GC evicts them.

## Timing Reality: First Workspace on a Brand-New Node

When Karpenter provisions a **new** replacement node for a displaced placeholder, there is a transient window where:

- The new node is provisioned.
- The placeholder pod starts its `initContainer`, which pulls the image. Timing depends on image size, ECR proximity, and network. As a rough calibration, `sagemaker-distribution:latest-cpu` is about 3.5 GB.
- During this window, the only available warm node is still in the `initContainer` phase.

If a **second** concurrent Space request arrives during this window, it will need to either wait for the initContainer to complete or trigger Karpenter to provision another node from scratch.

**Mitigation:** keep `CPA_MIN >= 2` so that there is always at least one fully `Running` (image-ready) warm node while another is being re-provisioned.

## GPU Spaces Extension

This guide documents the CPU pattern end-to-end. To extend the pattern to GPU Spaces, add three things to the placeholder Deployment above:

1. **Request a GPU on the `pause` container** so Karpenter provisions a GPU node:

   ```yaml
   resources:
     requests:
       cpu: "<gpu-node-cpu-request>"
       memory: "<gpu-node-memory-request>"
       nvidia.com/gpu: "1"
     limits:
       cpu: "<gpu-node-cpu-request>"
       memory: "<gpu-node-memory-request>"
       nvidia.com/gpu: "1"
   ```

2. **Tolerate the GPU node taint** applied by the NVIDIA device plugin / GPU operator:

   ```yaml
   tolerations:
     - key: "nvidia.com/gpu"
       operator: "Exists"
       effect: "NoSchedule"
   ```

3. **Point the `initContainer` at the GPU-flavoured image** - for example `public.ecr.aws/sagemaker/sagemaker-distribution:latest-gpu`, which is roughly 9.85 GB (~2.7× the CPU image). The larger image means pre-warming saves proportionally more wall-clock time on GPU nodes.

Everything else - priorityClass, anti-affinity, imagePullPolicy - remains identical to the CPU variant. Deploy as a **separate** Deployment (`spaces-placeholder-gpu`) so you can scale CPU and GPU warm pools independently.

## Next steps

- [Cluster Proportional Autoscaler](./06-cluster-proportional-autoscaler.md) - scale the placeholder Deployment automatically with cluster size.
