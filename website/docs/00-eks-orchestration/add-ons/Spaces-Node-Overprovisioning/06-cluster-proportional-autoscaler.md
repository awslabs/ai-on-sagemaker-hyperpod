---
title: Cluster Proportional Autoscaler
sidebar_position: 6
---

# Cluster Proportional Autoscaler

For clusters that grow and shrink significantly, a static replica count for placeholder pods is either insufficient (bursts stall) or wasteful (idle overhead during quiet periods). The Kubernetes [Cluster Proportional Autoscaler (CPA)](https://github.com/kubernetes-sigs/cluster-proportional-autoscaler) watches the node count and scales the placeholder Deployment proportionally.

```
replicas = max(
  ceil(schedulable_cores / coresPerReplica),
  ceil(schedulable_nodes / nodesPerReplica)
)  // clamped to [min, max]
```

You end up with roughly 1 warm placeholder per N active nodes, regardless of cluster size.

## 6.1 RBAC

CPA needs to list nodes and scale Deployments. Apply the full RBAC below — `kubectl apply` is idempotent if any object already exists.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: spaces-cpa
  namespace: ${OVERPROVISIONING_NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: spaces-cpa
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["list", "watch", "get"]
  - apiGroups: [""]
    resources: ["replicationcontrollers/scale"]
    verbs: ["get", "update"]
  - apiGroups: ["extensions", "apps"]
    resources: ["deployments/scale", "replicasets/scale"]
    verbs: ["get", "update"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: spaces-cpa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: spaces-cpa
subjects:
  - kind: ServiceAccount
    name: spaces-cpa
    namespace: ${OVERPROVISIONING_NS}
EOF

kubectl get clusterrole spaces-cpa
kubectl get clusterrolebinding spaces-cpa
```

Verify the ServiceAccount can actually list nodes:

```bash
kubectl auth can-i list nodes \
  --as=system:serviceaccount:${OVERPROVISIONING_NS}:spaces-cpa
# Expected: yes
```

## 6.2 ConfigMap — Scaling Ladder

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: spaces-overprovision-cpa-config
  namespace: ${OVERPROVISIONING_NS}
data:
  linear: |
    {
      "coresPerReplica": ${CPA_CORES_PER_REPLICA},
      "nodesPerReplica": ${CPA_NODES_PER_REPLICA},
      "min": ${CPA_MIN},
      "max": ${CPA_MAX},
      "preventSinglePointFailure": true,
      "includeUnschedulableNodes": false
    }
EOF
```

### How the ladder works

| Field | Current value | Meaning |
|---|---|---|
| `coresPerReplica` | `${CPA_CORES_PER_REPLICA}` | 1 placeholder per N CPU cores across NodePool nodes |
| `nodesPerReplica` | `${CPA_NODES_PER_REPLICA}` | 1 placeholder per N nodes in the NodePool |
| `min` | `${CPA_MIN}` | Always keep at least this many warm nodes |
| `max` | `${CPA_MAX}` | Never exceed this many placeholders (cost cap) |
| `preventSinglePointFailure` | `true` | Force `min >= 2` when the cluster has multiple nodes |
| `includeUnschedulableNodes` | `false` | Don't count cordoned/draining nodes toward replica math |

CPA takes the **maximum** of the `coresPerReplica` and `nodesPerReplica` calculations, then clamps to `[min, max]`.

:::warning Tune coresPerReplica to your node's vCPU count
Set `coresPerReplica` to approximately the vCPU count of your instance type. Using a value much smaller than the node's vCPU count causes CPA to over-scale. Example — on a NodePool of `ml.m5.12xlarge` (48 vCPU) with `coresPerReplica: 16`, CPA sees `ceil(96/16) = 6` for just 2 nodes and tries to run 6 placeholders on 2 nodes, which the anti-affinity rule in [Step 5](./05-placeholder-deployment.md#placeholder-deployment-cpu) will refuse. Set `coresPerReplica: 48` (or close to it) for `ml.m5.12xlarge`.
:::

### Changing the warm-node count immediately

Edit `min` (and optionally `max`) in the ConfigMap and re-apply. CPA reconciles within about 30 seconds.

## 6.3 Deployment

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spaces-overprovisioning-cpa
  namespace: ${OVERPROVISIONING_NS}
  labels:
    app: spaces-cpa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spaces-cpa
  template:
    metadata:
      labels:
        app: spaces-cpa
    spec:
      serviceAccountName: spaces-cpa
      priorityClassName: system-cluster-critical   # CPA must not be evicted
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      containers:
        - name: autoscaler
          # Pin an explicit version; update at deployment time.
          # Verify the latest tag with:
          #   crane ls registry.k8s.io/cpa/cluster-proportional-autoscaler | sort -V | tail -5
          image: registry.k8s.io/cpa/cluster-proportional-autoscaler:1.10.2
          resources:
            requests:
              cpu: "20m"
              memory: "20Mi"
            limits:
              cpu: "50m"
              memory: "64Mi"
          command:
            - /cluster-proportional-autoscaler
            - --namespace=${OVERPROVISIONING_NS}
            - --configmap=spaces-overprovision-cpa-config
            - --target=deployment/spaces-placeholder-cpu
            - --nodelabels=${NODE_LABEL_KEY}=${NODE_LABEL_VALUE}
            - --logtostderr=true
            - --v=2
EOF
```

### `--nodelabels` scopes CPA to your NodePool

Without `--nodelabels`, CPA would count every schedulable node in the cluster, including nodes owned by other NodePools and workloads. Passing `${NODE_LABEL_KEY}=${NODE_LABEL_VALUE}` restricts the count to nodes provisioned by your Spaces NodePool.

## Verify

```bash
kubectl rollout status deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS}

# Label-selector-based log streaming can fail if the CPA pod moves between
# nodes. Use the explicit pod name for reliable output.
CPA_POD=$(kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-cpa -o name | head -1)
kubectl logs -n ${OVERPROVISIONING_NS} $CPA_POD --tail=20 | grep -iE "nodes:|cores:|replicas:|error|forbidden"
```

**Expected:** log lines of the form `Nodes: X, Cores: Y, Replicas: Z` — no `forbidden` errors. If you see `nodes is forbidden`, re-apply the RBAC block from Section 6.1.

## Interaction with Manual `kubectl scale`

Once CPA is running, manual `kubectl scale deployment/spaces-placeholder-cpu --replicas=<N>` will be reverted by CPA within about 30 seconds. To make a lasting change:

- **For a permanent floor change:** edit `min` in the ConfigMap.
- **For a temporary override:** scale the CPA Deployment to 0 first, then scale the placeholder manually, then scale CPA back up when done.

```bash
# Temporary manual control
kubectl scale deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS} --replicas=0
kubectl scale deployment/spaces-placeholder-cpu     -n ${OVERPROVISIONING_NS} --replicas=<N>
# ... do your thing ...
kubectl scale deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS} --replicas=1
```

## Next steps

- [NodePool & Disruption](./07-nodepool-and-disruption.md) — configure the NodePool to keep warm nodes from being consolidated away.
