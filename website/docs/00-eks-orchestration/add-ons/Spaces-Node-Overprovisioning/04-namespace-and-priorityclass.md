---
title: Namespace & PriorityClass
sidebar_position: 4
---

# Namespace & PriorityClass

## Create the Overprovisioning Namespace

One namespace is enough for the whole cluster. You do **not** need one `overprovisioning` namespace per team. The placeholder Deployment in this single namespace reserves node-level capacity that the Kubernetes scheduler can preempt for Space pods running in **any** team namespace. `PriorityClass` is cluster-scoped and preemption operates across namespaces.

:::warning Task Governance safety
If your cluster has Task Governance enabled, the `hyperpod-task-governance-admission-policy` `ValidatingAdmissionPolicy` applies to any namespace carrying **both**:

- `sagemaker.amazonaws.com/activate-quota=Enabled`
- `sagemaker.amazonaws.com/sagemaker-managed-queue=true`

Inside such namespaces, every Pod/Deployment must carry a non-empty `kueue.x-k8s.io/queue-name` label or it is denied.

Placeholder pods are `pause` containers — they are intentionally **not** Kueue-managed workloads. The `overprovisioning` namespace must never carry those two labels. Keep it label-free apart from the identification labels below.
:::

```bash
kubectl create namespace ${OVERPROVISIONING_NS} \
  --dry-run=client -o yaml | kubectl apply -f -

# Identification labels only — NO Task Governance labels.
kubectl label namespace ${OVERPROVISIONING_NS} \
  purpose=node-overprovisioning \
  managed-by=karpenter \
  --overwrite
```

Verify no Task Governance labels leaked in:

```bash
kubectl get ns ${OVERPROVISIONING_NS} -o jsonpath='{.metadata.labels}' \
  | grep -oE 'activate-quota|sagemaker-managed-queue' \
  && echo "ERROR: TG labels found — remove them" \
  || echo "OK: no TG labels on overprovisioning namespace"
```

**Expected:** `OK: no TG labels on overprovisioning namespace`.

## Create the `overprovisioning-placeholder` PriorityClass

Placeholder pods carry a **negative priority** so they are the first candidates for preemption when real Space pods need resources.

```bash
kubectl apply -f - <<EOF
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: overprovisioning-placeholder
description: "Negative priority for HyperPod Spaces overprovisioning placeholder pods."
value: -1000                  # lower than any real workload; preempted by default priority (0)
globalDefault: false          # do NOT apply this to every pod cluster-wide
preemptionPolicy: Never       # placeholders never preempt other pods themselves
EOF

kubectl get priorityclass overprovisioning-placeholder
```

**Expected:** `VALUE=-1000`, `GLOBAL-DEFAULT=false`.

### Why these values

| Field | Value | Reasoning |
|---|---|---|
| `value` | `-1000` | Any real Workspace pod at the default priority `0` can preempt this. The value only needs to be less than any priority used by legitimate workloads on the cluster; `-1000` is safely below Kubernetes system priorities and any typical user assignment. |
| `globalDefault` | `false` | Setting `true` would apply this priority to every pod that lacks a `priorityClassName`, silently downgrading unrelated workloads. Never enable this. |
| `preemptionPolicy` | `Never` | The placeholder itself must never preempt anything. It only serves as a preemption target. |

### PriorityClass `value` is immutable

The `value` field of a `PriorityClass` is **immutable** after creation. `kubectl apply` with a different value will silently leave the existing value in place — the API server rejects the mutation but does not surface an error to `apply`.

If you need to change the priority value:

```bash
# 1. Scale placeholders to 0 first so pods aren't left in an odd state
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=0

# 2. Delete and recreate the PriorityClass
kubectl delete priorityclass overprovisioning-placeholder
kubectl apply -f - <<EOF
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: overprovisioning-placeholder
value: <new-value>
globalDefault: false
preemptionPolicy: Never
EOF

# 3. Scale placeholders back up
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=${CPA_MIN}
```

Deleting the `PriorityClass` while placeholder pods are running would leave those pods with a dangling priority reference. Scale to `0` first.

## Do You Need a High-Priority Class for Workspace Pods?

No.

The Spaces controller does not set an explicit `priorityClassName` on the Workspace pod. Workspace pods run with the default priority `0`, which is already higher than the placeholder's `-1000`. The scheduler will preempt placeholders for incoming Workspace pods without any extra configuration.

You do not need a `spaces-high-priority` class or equivalent. If you were considering one, skip it — it adds surface area without functional benefit.

The [`kueue.x-k8s.io/priority-class`](./01-overview.md#priority--preemption-model) label on the Workspace is a **separate** concept (Kueue admission priority) and is set per-Workspace referencing an existing `WorkloadPriorityClass`. See [Verification](./08-verification.md) for how it's applied.

## Next steps

- [Placeholder Deployment](./05-placeholder-deployment.md) — deploy the placeholder Deployment with initContainer image pre-warming.
