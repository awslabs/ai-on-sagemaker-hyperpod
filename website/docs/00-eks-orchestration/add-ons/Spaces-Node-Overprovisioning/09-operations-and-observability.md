---
title: Operations & Observability
sidebar_position: 9
---

# Operations & Observability

Day-2 reference. Use the [Quick Reference](#quick-reference) table below to find the right command for the change you want to make; each row links to the detailed subsection.

## Quick Reference

| What you want to change | Where it's defined | Section |
|---|---|---|
| Number of warm nodes (manual, static) | Placeholder Deployment `replicas` | [Warm node count — manual](#warm-node-count--manual) |
| Number of warm nodes (auto, scales with cluster) | CPA ConfigMap `linear` | [Warm node count — CPA](#warm-node-count--cpa) |
| Per-placeholder CPU/memory (must match Space size) | Placeholder Deployment `containers.pause.resources` | [Resize each placeholder](#resize-each-placeholder) |
| Eligible instance types | NodePool `spec.template.spec.requirements` | [Change eligible instance types](#change-eligible-instance-types) |
| Cost ceiling for the Spaces NodePool | NodePool `spec.limits` | [Change the NodePool cost cap](#change-the-nodepool-cost-cap) |
| Consolidation policy | NodePool `spec.disruption.consolidationPolicy` | [Change consolidation behaviour](#change-consolidation-behaviour) |
| Disruption schedule | NodePool `spec.disruption.budgets` | [Change disruption budgets](#change-disruption-budgets) |
| Image versions to pre-warm | Placeholder `initContainers` | [Add a new image version to pre-warming](#add-a-new-image-version-to-pre-warming) |
| Which Kueue priority Spaces use | Per-Workspace label `kueue.x-k8s.io/priority-class` | [Choose a WorkloadPriorityClass](#choose-a-workloadpriorityclass) |
| Pause overprovisioning entirely | Scale Deployments to `0` | [Temporarily disable](#temporarily-disable-overprovisioning) |
| Full uninstall | Delete all objects | [Rollback](./10-rollback-and-troubleshooting.md#rollback--uninstall) |

## Warm node count — manual

```bash
# Scale up before a planned workshop / event
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=5

# Return to steady state
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=${CPA_MIN}
```

:::note
If CPA is installed, manual `kubectl scale` will be reverted within about 30 seconds. To make a lasting change, edit the CPA ConfigMap instead — see [Warm node count — CPA](#warm-node-count--cpa) below.
:::

## Warm node count — CPA

```bash
kubectl edit configmap spaces-overprovision-cpa-config -n ${OVERPROVISIONING_NS}
```

The `linear` JSON controls the formula `max(ceil(cores/coresPerReplica), ceil(nodes/nodesPerReplica))` clamped to `[min, max]`. Field meanings:

| Field | Effect |
|---|---|
| `min` | Floor — never go below this |
| `max` | Ceiling — never exceed this |
| `nodesPerReplica` | 1 placeholder per N cluster nodes |
| `coresPerReplica` | 1 placeholder per N cluster cores |
| `preventSinglePointFailure` | Forces `min: 2` when true |

CPA picks up the change within about 30 seconds. Verify:

```bash
CPA_POD=$(kubectl get pods -n ${OVERPROVISIONING_NS} -l app=spaces-cpa -o name | head -1)
kubectl logs -n ${OVERPROVISIONING_NS} $CPA_POD --tail=30
kubectl get deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} -o jsonpath='{.spec.replicas}'
```

## Resize each placeholder

```bash
kubectl patch deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} \
  --type=strategic -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"pause","resources":{"requests":{"cpu":"4","memory":"16Gi"},"limits":{"cpu":"4","memory":"16Gi"}}}]}}}}'

kubectl rollout status deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --timeout=180s
```

:::warning
The placeholder's request must match (or exceed) the typical Workspace request. Otherwise the Workspace does not fit alongside the placeholder on the same node, the scheduler preempts the placeholder every time, and you lose the coexist-path optimisation. Update the placeholder any time you change your WorkspaceTemplate's `defaultResources`.
:::

## Change eligible instance types

```bash
kubectl edit nodepool ${KARPENTER_NODEPOOL_NAME}
```

Update `spec.template.spec.requirements`:

```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["on-demand"]
  - key: node.kubernetes.io/instance-type
    operator: In
    values:
      - ml.m5.12xlarge
      - ml.m5.24xlarge     # fallback if primary type has no capacity
      - ml.m6i.12xlarge    # broader pool
```

Broaden the list to give Karpenter fallbacks when AWS returns `InsufficientCapacityError` for the primary type. Any new instance type must (1) exist in your `HyperpodNodeClass.spec.instanceGroups` and (2) be present in the SageMaker HyperPod cluster definition.

## Change the NodePool cost cap

```bash
kubectl edit nodepool ${KARPENTER_NODEPOOL_NAME}
```

Update `spec.limits`:

```yaml
spec:
  limits:
    cpu: "256"      # total vCPU cap across all Spaces nodes
    memory: "2Ti"
```

Karpenter refuses to provision new nodes if doing so would exceed these limits.

## Change consolidation behaviour

```bash
kubectl edit nodepool ${KARPENTER_NODEPOOL_NAME}
```

| Field | Choice | Effect |
|---|---|---|
| `consolidationPolicy: WhenEmpty` | **Recommended.** | Removes only nodes with zero pods. Placeholder-held nodes are not "empty". Required for this pattern to work. |
| `consolidationPolicy: WhenEmptyOrUnderutilized` | **Breaks overprovisioning.** | Consolidates nodes with less than ~50% pod utilisation. Placeholders use ~0% CPU by design, so every warm node looks underutilised. |
| `consolidateAfter: 5m` | Tune up or down. | How long a node must be empty before removal. Shorter is more aggressive off-hours scale-down. |

## Change disruption budgets

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
      # Saturday 08:00–14:00 UTC — no disruptions
      - schedule: "0 8 * * sat"
        duration: 6h
        nodes: "0"
      # Everything else — 1 disruption at a time
      - nodes: "1"
'
```

Cron uses standard 5-field format; times are UTC.

## Add a new image version to pre-warming

When you update a WorkspaceTemplate to a new SageMaker Distribution version, add a corresponding `initContainer` to the placeholder Deployment:

```bash
kubectl edit deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS}
# Add under spec.template.spec.initContainers:
#   - name: pull-workspace-image-new
#     image: <new-image-uri>
#     imagePullPolicy: IfNotPresent
#     command: ["sh", "-c", "echo 'new version pre-warmed'"]
#     resources:
#       requests: { cpu: "10m", memory: "64Mi" }
#       limits:   { cpu: "50m", memory: "128Mi" }
```

The rolling restart causes each new placeholder pod to pull the new image onto its assigned node.

## Choose a WorkloadPriorityClass

```bash
kubectl get workloadpriorityclass
```

Task Governance ships a default set (admins can add or remove):

| Name | Value | Typical use |
|---|---|---|
| `interactive-priority` | 60 | **Recommended for IDE Spaces** |
| `experimentation-priority` | 90 | Short exploration jobs |
| `training-priority` | 80 | Model training |
| `fine-tuning-priority` | 70 | Fine-tuning jobs |
| `inference-priority` | 100 | Inference workloads |

Reference the chosen class per-Workspace via the `kueue.x-k8s.io/priority-class` label.

:::warning
`kueue.x-k8s.io/priority-class` resolves against **Kueue** `WorkloadPriorityClass` resources (`kueue.x-k8s.io/v1beta1`), not Kubernetes-native `PriorityClass` resources. Using a name that doesn't exist as a WorkloadPriorityClass causes Kueue to log `WorkloadPriorityClass ... not found`, retry admission, and eventually admit with default priority `0` — a several-second delay plus noisy Kueue logs. Always confirm the class exists in your cluster with `kubectl get workloadpriorityclass` before referencing it.
:::

## Temporarily disable overprovisioning

For holidays or extended maintenance windows when you want to release warm nodes for cost.

```bash
# Scale CPA to 0 first, otherwise it will fight to restore replicas.
kubectl scale deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS} --replicas=0

# Scale placeholders to 0. Karpenter will consolidate empty nodes after consolidateAfter.
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=0

# Monitor scale-down
watch kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE}
```

Restore in the reverse order:

```bash
kubectl scale deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS} --replicas=1
# CPA will restore placeholder replicas based on the current cluster size.
# Or, if CPA is not installed:
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=${CPA_MIN}
```

## Observability

### What's Available and What Isn't

The HyperPod managed Karpenter controller runs in the SageMaker control plane, not as a pod in your cluster. So:

- `kubectl get pods -n kube-system -l app=karpenter` returns nothing.
- There is no `karpenter` Service to `port-forward` and no scrapable Prometheus endpoint at `:8080/metrics` in your cluster.
- Upstream Karpenter metrics (`karpenter_nodeclaims_total`, `karpenter_pods_state`, and so on) are not directly exposed.

Use the surfaces below instead.

### NodeClaim and pod state via kubectl

```bash
# Active NodeClaims for the Spaces NodePool
kubectl get nodeclaims -l karpenter.sh/nodepool=${KARPENTER_NODEPOOL_NAME}

# Pending pods (persistent pending indicates provisioning failure)
kubectl get pods -A --field-selector=status.phase=Pending

# Disruption-related conditions on each NodeClaim
kubectl get nodeclaims -l karpenter.sh/nodepool=${KARPENTER_NODEPOOL_NAME} -o yaml \
  | grep -A2 -E "type:|reason:|status:" | head -60
```

### Cluster events for disruption / consolidation

```bash
# Events Karpenter emits when consolidation is blocked
kubectl get events -A --field-selector reason=DisruptionBlocked
kubectl get events -A --field-selector reason=Unconsolidatable

# Broader view of preemption and consolidation activity
kubectl get events -A --sort-by='.lastTimestamp' \
  | grep -iE "disrupt|consolidat|preempt" | tail -20
```

### HyperPod cluster status

```bash
# Current vs target counts per instance group
aws sagemaker describe-cluster \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --query 'InstanceGroups[*].{Name:InstanceGroupName,Current:CurrentCount,Target:TargetCount,Status:Status}' \
  --output table

# HyperPod-side instance lifecycle events
aws sagemaker list-cluster-events \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --max-results 20 \
  --query 'Events[*].{Time:EventTime,Type:ResourceType,Group:InstanceGroupName,Msg:Description}' \
  --output table
```

### CloudWatch and Kubernetes-side telemetry

If you enabled the HyperPod observability add-on, SageMaker emits cluster-side metrics under the `AWS/SageMaker/Cluster` namespace in CloudWatch (instance health, lifecycle script outcomes, cluster scale events). See the [Observability add-on](../Observability/Observability.md) page.

For pod-level and Kubernetes-side telemetry (pod state, node conditions, resource utilisation), install the standard EKS observability stack — Container Insights and kube-state-metrics — which surface these without depending on the Karpenter controller being scrapable.

### Space startup latency canary (optional)

```bash
#!/bin/bash
# Periodic synthetic probe. Publishes to CloudWatch under HyperPod/Spaces.
SPACE_NAME="latency-probe-$(date +%s)"
START_MS=$(date +%s%3N)

cat <<EOF | kubectl apply -f -
apiVersion: workspace.jupyter.org/v1alpha1
kind: Workspace
metadata:
  name: $SPACE_NAME
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

while true; do
  STATUS=$(kubectl get workspace $SPACE_NAME -n ${TG_NAMESPACE_FOR_TEST} \
    -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
  if [ "$STATUS" = "True" ]; then
    END_MS=$(date +%s%3N)
    LATENCY_S=$(( (END_MS - START_MS) / 1000 ))
    echo "Space startup latency: ${LATENCY_S}s"
    aws cloudwatch put-metric-data \
      --namespace "HyperPod/Spaces" \
      --metric-data MetricName=SpaceStartupLatency,Value=$LATENCY_S,Unit=Seconds
    break
  fi
  sleep 2
done

kubectl delete workspace $SPACE_NAME -n ${TG_NAMESPACE_FOR_TEST}
```

## Cost Considerations

Each placeholder pod forces one EC2 instance to remain running. Numbers below are **indicative** — verify current on-demand pricing at [aws.amazon.com/ec2/pricing](https://aws.amazon.com/ec2/pricing/).

| Instance Type | Order of magnitude, on-demand | Cost of 1 warm node × 13 business hours | Overnight saving if scale-down works |
|---|---|---|---|
| `ml.m5.12xlarge` (CPU) | ~$2/hr | ~$26/day | ~$22/day |
| `ml.g5.12xlarge` (GPU) | ~$5–7/hr | ~$65–90/day | ~$55–75/day |

### Cost controls built into this pattern

1. **`WhenEmpty` consolidation** — Karpenter only removes nodes with zero pods, not slightly underutilised ones.
2. **Disruption budgets** — nodes are held warm only when it matters; off-hours scale-down is permitted.
3. **`consolidateAfter: 5m`** — when a Space ends and no placeholder re-schedules onto the node, it's released after 5 minutes.
4. **CPA `max`** — hard cap on the number of warm nodes.
5. **Idle shutdown on Spaces** (configured in your WorkspaceTemplate) — stops idle Workspaces after N minutes, releasing the node back to a placeholder or to Karpenter for consolidation.

## Next steps

- [Rollback & Troubleshooting](./10-rollback-and-troubleshooting.md) — clean uninstall and diagnosis for common failures.
