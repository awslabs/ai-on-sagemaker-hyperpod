---
title: Verification
sidebar_position: 8
---

# Verification

Run these checks in order. They confirm the warm pool is healthy, that Workspaces land on warm nodes via both scheduling paths (coexist and preempt), and that Karpenter provisions replacement nodes correctly.

## 8.1 Baseline — Placeholders Are Healthy

```bash
# Placeholders running, one per node
kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder -o wide
# Expected: ${CPA_MIN} pods, STATUS=Running, each on a DIFFERENT node

# Confirm each placeholder is on a separate warm node
kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'

# Confirm the initContainer pre-pull completed successfully on each placeholder
kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.initContainerStatuses[0].state}{"\n"}{end}'
# Expected: terminated with exitCode=0

# CPA is running and has reconciled
CPA_POD=$(kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-cpa -o name | head -1)
kubectl logs -n ${OVERPROVISIONING_NS} $CPA_POD --tail=5
# Expected: lines like "Nodes: 2, Cores: 96, Replicas: 2"
```

**Pass criteria:** all placeholder pods `Running`, each on a distinct node, initContainer `Completed`, CPA emitting scaling decisions.

## 8.2 Baseline Cold-Start Measurement (Optional)

Establish a cold-start baseline for later comparison. This intentionally drains the warm pool.

```bash
# Scale placeholders and CPA to 0 so nodes drain
kubectl scale deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS} --replicas=0
kubectl scale deployment/spaces-placeholder-cpu     -n ${OVERPROVISIONING_NS} --replicas=0

# Wait for nodes to be terminated (up to consolidateAfter + provisioning time)
watch kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE}

# When no warm nodes remain, create a Workspace and time it end-to-end
START=$(date +%s)
cat <<EOF | kubectl apply -f -
apiVersion: workspace.jupyter.org/v1alpha1
kind: Workspace
metadata:
  name: cold-start-baseline
  namespace: ${TG_NAMESPACE_FOR_TEST}
  labels:
    kueue.x-k8s.io/queue-name: ${TG_NAMESPACE_FOR_TEST}-localqueue
    kueue.x-k8s.io/priority-class: ${WORKSPACE_PRIORITY_CLASS}
spec:
  template:
    name: ${TEMPLATE_FOR_TEST}
    namespace: ${WORKSPACE_TEMPLATE_NAMESPACE}
  resources:
    requests:
      cpu: "${PLACEHOLDER_CPU_REQUEST}"
      memory: "${PLACEHOLDER_MEMORY_REQUEST}"
EOF

kubectl wait workspace/cold-start-baseline -n ${TG_NAMESPACE_FOR_TEST} \
  --for=jsonpath='{.status.conditions[?(@.type=="Available")].status}'=True \
  --timeout=600s
END=$(date +%s)
echo "Cold-start latency: $((END - START)) seconds"

# Clean up and restore the warm pool
kubectl delete workspace cold-start-baseline -n ${TG_NAMESPACE_FOR_TEST}
kubectl scale deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS} --replicas=1
```

Record the number — this is your yardstick for the warm-path tests.

:::note
If Task Governance is not enabled in your cluster, omit the two `kueue.x-k8s.io/*` labels and place the Workspace in any non-TG namespace.
:::

## 8.3 Warm-Path Test — Workspace Coexists With Placeholder

This test creates a Workspace small enough to fit alongside the placeholder on the same warm node. No preemption occurs.

**Formula:** if the Workspace requests `cpu <= NODE_ALLOCATABLE_CPU - PLACEHOLDER_CPU_REQUEST`, it will coexist. Substitute your own values.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: workspace.jupyter.org/v1alpha1
kind: Workspace
metadata:
  name: overprovisioning-coexist-test
  namespace: ${TG_NAMESPACE_FOR_TEST}
  labels:
    kueue.x-k8s.io/queue-name: ${TG_NAMESPACE_FOR_TEST}-localqueue
    kueue.x-k8s.io/priority-class: ${WORKSPACE_PRIORITY_CLASS}
spec:
  template:
    name: ${TEMPLATE_FOR_TEST}
    namespace: ${WORKSPACE_TEMPLATE_NAMESPACE}
  resources:
    requests:
      cpu: "${PLACEHOLDER_CPU_REQUEST}"     # fits alongside placeholder
      memory: "${PLACEHOLDER_MEMORY_REQUEST}"
EOF

# Confirm the condition type your Workspace CRD uses (run once — some
# versions expose "Ready" instead of "Available"; adjust the wait accordingly).
kubectl get workspace overprovisioning-coexist-test -n ${TG_NAMESPACE_FOR_TEST} \
  -o jsonpath='{range .status.conditions[*]}{.type}{"\n"}{end}'

START=$(date +%s)
kubectl wait workspace/overprovisioning-coexist-test -n ${TG_NAMESPACE_FOR_TEST} \
  --for=jsonpath='{.status.conditions[?(@.type=="Available")].status}'=True \
  --timeout=120s
END=$(date +%s)
echo "Workspace ready in $((END - START)) seconds"
```

**Expected:** Workspace reaches `Available=True` within seconds — the fast warm-coexist path, no Karpenter cold start.

### Confirm it landed on a pre-warmed node

```bash
WS_NODE=$(kubectl get workspace overprovisioning-coexist-test -n ${TG_NAMESPACE_FOR_TEST} \
  -o jsonpath='{.status.podName}' 2>/dev/null \
  || kubectl get pods -n ${TG_NAMESPACE_FOR_TEST} \
       -l workspace.jupyter.org/name=overprovisioning-coexist-test \
       -o jsonpath='{.items[0].spec.nodeName}')
echo "Workspace landed on node: $WS_NODE"

kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder -o wide \
  | grep "$WS_NODE" \
  && echo "Confirmed: Workspace coexists with placeholder on warm node" \
  || echo "Workspace on a different node — check nodeAffinity / tolerations"
```

### Confirm no image pull occurred

```bash
kubectl describe pod -n ${TG_NAMESPACE_FOR_TEST} \
  $(kubectl get pods -n ${TG_NAMESPACE_FOR_TEST} \
      -l workspace.jupyter.org/name=overprovisioning-coexist-test \
      -o jsonpath='{.items[0].metadata.name}') \
  | grep -A2 "Events:"
# Expected: "Container image already present on machine"
# If you see "Pulling image", the initContainer on the placeholder had not
# completed pre-warming on that node yet.
```

## 8.4 Warm-Path Test — Workspace Preempts Placeholder

This test creates a Workspace too large to fit alongside the placeholder. The scheduler preempts the placeholder to free the node.

**Formula:** if the Workspace requests `cpu > NODE_ALLOCATABLE_CPU - PLACEHOLDER_CPU_REQUEST`, it forces preemption. Substitute your own values in `<large-cpu>` and `<large-memory>` below.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: workspace.jupyter.org/v1alpha1
kind: Workspace
metadata:
  name: overprovisioning-preempt-test
  namespace: ${TG_NAMESPACE_FOR_TEST}
  labels:
    kueue.x-k8s.io/queue-name: ${TG_NAMESPACE_FOR_TEST}-localqueue
    kueue.x-k8s.io/priority-class: ${WORKSPACE_PRIORITY_CLASS}
spec:
  template:
    name: ${TEMPLATE_FOR_TEST}
    namespace: ${WORKSPACE_TEMPLATE_NAMESPACE}
  resources:
    requests:
      # Set CPU > (NODE_ALLOCATABLE_CPU - PLACEHOLDER_CPU_REQUEST) to force preemption.
      cpu: "<large-cpu>"
      memory: "<large-memory>"
EOF

START=$(date +%s)
kubectl wait workspace/overprovisioning-preempt-test -n ${TG_NAMESPACE_FOR_TEST} \
  --for=jsonpath='{.status.conditions[?(@.type=="Available")].status}'=True \
  --timeout=180s
END=$(date +%s)
echo "Workspace ready in $((END - START)) seconds"
```

**Expected event sequence:**

```
Preempting pod ${OVERPROVISIONING_NS}/spaces-placeholder-cpu-xxx on node <placeholder-node>
Successfully scheduled overprovisioning-preempt-test on node <placeholder-node>
```

**Expected latency:** faster than baseline cold-start (§8.2), because the node was already provisioned and the image was already cached — you're only paying for scheduler preemption and Workspace init.

### Confirm Karpenter provisioned a replacement node

After preemption, the displaced placeholder pod enters `Pending`. Karpenter should provision a new node for it.

```bash
kubectl get nodeclaims -l karpenter.sh/nodepool=${KARPENTER_NODEPOOL_NAME}

# Watch the displaced placeholder transition Pending → Running on the new node
kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder -w
```

## 8.5 Verify CPA is Working

```bash
CPA_POD=$(kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-cpa -o name | head -1)
kubectl logs -n ${OVERPROVISIONING_NS} $CPA_POD --tail=20 \
  | grep -iE "nodes:|cores:|replicas:|error|forbidden"
```

**Expected:** lines of the form `Nodes: X, Cores: Y, Replicas: Z`. No `forbidden` errors.

If you see `nodes is forbidden`: the ClusterRole from [Step 6.1](./06-cluster-proportional-autoscaler.md#61-rbac) was not applied. Re-apply it.

## 8.6 Cleanup

```bash
kubectl delete workspace overprovisioning-coexist-test -n ${TG_NAMESPACE_FOR_TEST}
kubectl delete workspace overprovisioning-preempt-test -n ${TG_NAMESPACE_FOR_TEST}

# Wait for placeholders to return to CPA_MIN. Karpenter provisions the
# replacement node → placeholder reschedules → initContainer re-runs.
kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-placeholder -w
```

**Expected:** back to `${CPA_MIN}` Running pods on distinct nodes.

## Next steps

- [Operations & Observability](./09-operations-and-observability.md) — day-2 runbook, monitoring, cost.
