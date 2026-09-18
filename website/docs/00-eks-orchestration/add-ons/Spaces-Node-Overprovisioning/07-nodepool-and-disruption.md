---
title: NodePool & Disruption
sidebar_position: 7
---

# NodePool & Disruption

This page covers the Karpenter side of the pattern. If you already have a working `NodePool` and `HyperpodNodeClass` dedicated to Spaces, review the disruption settings below and skip the rest.

## Why This Matters

Karpenter's default disruption behaviour (consolidate any node whose real utilisation is low) will happily destroy warm nodes. Placeholders use minimal CPU on purpose, so any policy that treats "low CPU use" as "consolidatable" tears the warm buffer down within minutes of building it up. The NodePool below is configured to preserve the pattern.

## 7.1 HyperpodNodeClass

`HyperpodNodeClass` references SageMaker HyperPod instance groups that must already exist in the cluster. Instance groups must start at `0` nodes so Karpenter can manage all scaling.

```bash
kubectl apply -f - <<EOF
apiVersion: karpenter.sagemaker.amazonaws.com/v1
kind: HyperpodNodeClass
metadata:
  name: ${HYPERPOD_NODECLASS_NAME}
spec:
  instanceGroups:
    - <your-cpu-instance-group-name>
EOF
```

Discover your instance group names with:

```bash
aws sagemaker describe-cluster \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --query 'InstanceGroups[*].InstanceGroupName'
```

Wait for the NodeClass to be `Ready`:

```bash
kubectl get hyperpodnodeclass ${HYPERPOD_NODECLASS_NAME} \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True
```

The NodeClass will not reach `Ready` until `AutoScaling.Status` is `InService` — verify that first with the check in [Pre-flight 2](./03-preflight-checks.md#2-verify-karpenter-autoscaling-is-enabled).

## 7.2 NodePool

```bash
kubectl apply -f - <<EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ${KARPENTER_NODEPOOL_NAME}
spec:
  template:
    metadata:
      labels:
        ${NODE_LABEL_KEY}: ${NODE_LABEL_VALUE}
    spec:
      nodeClassRef:
        group: karpenter.sagemaker.amazonaws.com
        kind: HyperpodNodeClass
        name: ${HYPERPOD_NODECLASS_NAME}
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]           # spot is not supported on HyperPod managed Karpenter
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - ${INSTANCE_TYPE}
      expireAfter: 720h                    # 30-day maximum node lifetime
  limits:
    cpu: "256"                             # cost ceiling — adjust for your budget
    memory: "2Ti"
  disruption:
    consolidationPolicy: WhenEmpty         # see WhenEmpty note below
    consolidateAfter: 5m
    budgets:
      # Off-hours: allow up to 1 node disruption at a time
      - nodes: "1"
      # Optionally, block ALL disruptions during working hours to keep the
      # warm buffer intact. Cron is UTC. Adjust to your team's timezone.
      # - schedule: "0 7 * * mon-fri"
      #   duration: 13h
      #   nodes: "0"
EOF
```

:::warning terminationGracePeriodSeconds is not a valid NodePool field
Some older documentation shows `terminationGracePeriodSeconds` under `spec.template.spec`. It does not exist in the HyperPod managed Karpenter v1 schema — including it will fail apply with `strict decoding error: unknown field "spec.template.spec.terminationGracePeriodSeconds"`. Valid fields under `spec.template.spec` are `expireAfter`, `nodeClassRef`, `requirements`, `taints`, and `startupTaints`.
:::

## 7.3 `WhenEmpty` vs `WhenEmptyOrUnderutilized`

**Always use `WhenEmpty` for the Spaces NodePool.** This is the single most important disruption setting for the overprovisioning pattern.

| `consolidationPolicy` | Behaviour | Impact on overprovisioning |
|---|---|---|
| `WhenEmpty` | Karpenter removes only nodes with **zero** pods | Placeholder-held nodes are never considered empty. Warm buffer preserved. **This is what you want.** |
| `WhenEmptyOrUnderutilized` | Karpenter also consolidates nodes whose pods use less than ~50% of capacity | Placeholders use ~0% CPU by design. Every warm node looks "underutilised". Karpenter tears the warm buffer down. **Breaks the pattern.** |

The `consolidateAfter` window (`5m` above) is how long a node must be genuinely empty before Karpenter removes it — this covers off-hours scale-down. Tune it up if you see thrashing between Space stops and node terminations; tune it down for more aggressive overnight cost savings.

## 7.4 Disruption Budgets

Budgets control **when** and **how many** nodes Karpenter is permitted to remove.

### Off-hours default

The bare NodePool above allows up to 1 disruption at a time, at any time. That's a reasonable default for teams whose usage is spread over the day.

### Blocking disruptions during business hours

If you want to guarantee zero warm-node turnover during working hours, add a scheduled budget of `nodes: "0"`. Cron expressions use standard 5-field format and are UTC.

```bash
kubectl patch nodepool ${KARPENTER_NODEPOOL_NAME} --type=merge --patch '
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 5m
    budgets:
      # Weekdays 07:00–20:00 UTC — no disruptions
      - schedule: "0 7 * * mon-fri"
        duration: 13h
        nodes: "0"
        reasons:
          - "Empty"
          - "Underutilized"
      # Saturday 08:00–14:00 UTC — no disruptions
      - schedule: "0 8 * * sat"
        duration: 6h
        nodes: "0"
      # Everything else — allow up to 1 disruption at a time
      - nodes: "1"
'
```

Adjust the cron `schedule` and `duration` to your team's timezone and working hours.

### Verifying disruption behaviour

The Karpenter controller is not visible as a pod in HyperPod managed Karpenter — the controller runs in the SageMaker control plane. Use Kubernetes events, NodeClaim conditions, and the SageMaker `list-cluster-events` API instead of `kubectl logs`.

```bash
# Events where Karpenter blocked a disruption
kubectl get events -A --field-selector reason=DisruptionBlocked
kubectl get events -A --field-selector reason=Unconsolidatable

# NodeClaims for the Spaces NodePool
kubectl get nodeclaims -l karpenter.sh/nodepool=${KARPENTER_NODEPOOL_NAME}

# NodeClaim conditions (Consolidatable, Disruptable, Ready, etc.)
kubectl get nodeclaims -l karpenter.sh/nodepool=${KARPENTER_NODEPOOL_NAME} -o yaml \
  | grep -A2 -E "type:|reason:|status:" | head -60

# HyperPod-side instance lifecycle events
aws sagemaker list-cluster-events \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --max-results 20 \
  --query 'Events[*].{Time:EventTime,Type:ResourceType,Group:InstanceGroupName,Msg:Description}' \
  --output table
```

## 7.5 Related Karpenter Notes

- **On-demand only.** HyperPod managed Karpenter does not support spot instances for autoscaling instance groups. Warm nodes cannot use spot pricing.
- **DeepHealthChecks incompatibility.** Instance groups with DeepHealthChecks enabled are incompatible with Karpenter autoscaling — pods remain `Pending` for the duration of the 60–90 minute DHC. Do not enable DHC on Spaces instance groups.
- **Instance groups must start at 0.** If an instance group has pre-existing non-Karpenter nodes, HyperPod Karpenter will attempt to scale them down.
- **EBS AZ binding.** Space EBS volumes are bound to a specific Availability Zone. If your NodePool spans multiple AZs, a Space may fail to schedule if the AZ that holds its EBS volume has no available warm node. Align placeholder scheduling zone with EBS volume zones where possible.
- **`karpenter.sh/do-not-disrupt: "true"` vs a duration.** The boolean `"true"` annotation on the placeholder pod permanently protects it from voluntary disruption. The duration form (e.g. `"8h"`) only protects for the specified window after the pod starts. Use `"true"` for placeholders and rely on NodePool disruption budgets for schedule-based control.

## Next steps

- [Verification](./08-verification.md) — end-to-end tests to confirm the warm pool works.
