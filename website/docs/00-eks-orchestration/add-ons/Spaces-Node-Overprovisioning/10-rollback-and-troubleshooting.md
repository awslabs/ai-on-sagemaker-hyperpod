---
title: Rollback & Troubleshooting
sidebar_position: 10
---

# Rollback & Troubleshooting

## Rollback / Uninstall

Remove all overprovisioning components in order. This does not affect your WorkspaceTemplates, Karpenter NodePool, or Task Governance configuration — those were prerequisites, not created by this add-on.

```bash
# 1. Remove the placeholder Deployment (warm nodes will go idle;
#    Karpenter will consolidate them after consolidateAfter).
kubectl delete deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS}

# 2. Remove CPA and its config
kubectl delete deployment/spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS}
kubectl delete configmap/spaces-overprovision-cpa-config -n ${OVERPROVISIONING_NS}
kubectl delete serviceaccount/spaces-cpa -n ${OVERPROVISIONING_NS}
kubectl delete clusterrole/spaces-cpa
kubectl delete clusterrolebinding/spaces-cpa

# 3. Remove the PriorityClass
kubectl delete priorityclass overprovisioning-placeholder

# 4. Remove the namespace (also removes any remaining pods)
kubectl delete namespace ${OVERPROVISIONING_NS}

# 5. Verify cleanup
kubectl get ns ${OVERPROVISIONING_NS} 2>/dev/null                              && echo "namespace still exists"    || echo "namespace deleted"
kubectl get priorityclass overprovisioning-placeholder 2>/dev/null             && echo "priorityclass still exists" || echo "priorityclass deleted"
kubectl get clusterrole spaces-cpa 2>/dev/null                                 && echo "clusterrole still exists"  || echo "clusterrole deleted"

# 6. Verify Karpenter consolidates the now-idle warm nodes
kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE} -w
# Expected: nodes transition to NotReady, then are removed within the NodePool's consolidateAfter window.
```

After rollback:

- **Existing running Workspaces are unaffected.** They continue on their current nodes until stopped or deleted through the normal Spaces flow.
- **New Workspace creation falls back to the cold-start path.** Karpenter provisions nodes on demand; startup returns to the multi-minute range.

## Troubleshooting

### Placeholder Stuck in `Pending`

```bash
kubectl describe pod -n ${OVERPROVISIONING_NS} <placeholder-pod-name>
```

Look at the `Events:` section and `Conditions:`. Common causes:

**1. Taint mismatch.** The placeholder does not tolerate a taint on the target nodes, so no node satisfies the pod's tolerations.

```bash
kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE} \
  -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

Add a matching toleration entry to the placeholder Deployment's `spec.template.spec.tolerations`. Repeat for every taint reported.

**2. nodeAffinity mismatch.** No existing node matches the placeholder's `nodeAffinity`, and Karpenter cannot provision a matching node from the current NodePool.

```bash
kubectl get nodepool ${KARPENTER_NODEPOOL_NAME} -o yaml | grep -A20 requirements
```

Confirm the instance type / label referenced in the placeholder's `nodeAffinity` is also in the NodePool `requirements`.

**3. NodePool limits reached.**

```bash
kubectl get nodepool ${KARPENTER_NODEPOOL_NAME} -o jsonpath='{.spec.limits}'
kubectl get nodeclaims -l karpenter.sh/nodepool=${KARPENTER_NODEPOOL_NAME}
```

If total consumption is at or near `spec.limits`, Karpenter will not provision. Increase the limits or reduce demand.

**4. `HyperpodNodeClass` not `Ready`.**

```bash
kubectl get hyperpodnodeclass ${HYPERPOD_NODECLASS_NAME} \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

The NodeClass will not reach `Ready` until `AutoScaling.Status` is `InService`. See [Pre-flight 2](./03-preflight-checks.md#2-verify-karpenter-autoscaling-is-enabled).

**5. `AutoScaling.Status` not `InService`.**

```bash
aws sagemaker describe-cluster \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --query 'AutoScaling'
```

Karpenter cannot provision nodes until this reports `Status: InService`.

**6. Image pull failure.** The initContainer cannot pull `${WORKSPACE_IMAGE}`.

```bash
kubectl describe pod -n ${OVERPROVISIONING_NS} <placeholder-pod-name> | grep -A10 "Events"
```

Look for `ErrImagePull` / `ImagePullBackOff`. Check ECR authentication, node IAM role, and network egress from the node's subnets.

### Image Not Pre-warmed (Slow Startup on a Warm Node)

Symptom: a Space lands on a warm placeholder node but still takes minutes to start.

```bash
PLACEHOLDER_POD=$(kubectl get pod -n ${OVERPROVISIONING_NS} \
  -l type=cpu -o name | head -1)
kubectl describe $PLACEHOLDER_POD -n ${OVERPROVISIONING_NS} \
  | grep -A10 "Init Containers:"
```

Possible causes:

1. **The initContainer is still running.** A very large image on a very fresh node — check the timestamps and be patient. Increase `CPA_MIN` to keep at least one fully-Running warm node available while others are still warming.
2. **The initContainer failed.** Fix the underlying pull error and let the pod restart.
3. **The node was replaced after the initContainer completed.** The new node has not yet pre-warmed. Same mitigation as (1) — keep `CPA_MIN >= 2`.
4. **kubelet's image GC evicted the cached image.** Check node disk pressure:

   ```bash
   kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE} \
     -o custom-columns=NAME:.metadata.name,DISK-PRESSURE:.status.conditions[?(@.type=="DiskPressure")].status
   ```

   If a node reports `DiskPressure=True`, increase the node's ephemeral storage in your instance-group configuration or reduce the number of pre-pulled images.

### CPA Logs Show `forbidden` Errors

The ClusterRole from [Step 6.1](./06-cluster-proportional-autoscaler.md#61-rbac) was not applied or was later overwritten.

```bash
kubectl auth can-i list nodes \
  --as=system:serviceaccount:${OVERPROVISIONING_NS}:spaces-cpa
# Expected: yes
```

If `no`, re-apply the RBAC block.

### `PriorityClass` `apply` Silently Ignored

`PriorityClass.value` is immutable. `kubectl apply` with a different value will succeed but leave the old value in place. Delete and recreate:

```bash
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=0
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
kubectl scale deployment/spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} --replicas=${CPA_MIN}
```

### NodePool `apply` Fails with `strict decoding error`

Symptom:

```
strict decoding error: unknown field "spec.template.spec.terminationGracePeriodSeconds"
```

`terminationGracePeriodSeconds` is not a valid field under `spec.template.spec` in the HyperPod managed Karpenter v1 schema. Remove it. Valid fields under `spec.template.spec` are `expireAfter`, `nodeClassRef`, `requirements`, `taints`, `startupTaints`.

### `describe-cluster` Returns `ResourceNotFound`

The `--cluster-name` flag accepts either the logical `ClusterName` or the full cluster ARN. The **cluster ID hex suffix from the ARN alone is not valid**. Use one of:

```bash
# Logical name (from `aws sagemaker list-clusters`)
aws sagemaker describe-cluster --cluster-name <logical-cluster-name> --region <region>

# Full ARN
aws sagemaker describe-cluster \
  --cluster-name arn:aws:sagemaker:<region>:<account-id>:cluster/<cluster-id> \
  --region <region>
```

### WorkspaceTemplate `apply` Fails with Unknown Field Errors

Common older-docs traps:

- Use `defaultIdleShutdown.idleTimeoutInMinutes`, **not** `idleShutdownTimeoutMinutes`.
- Use `idleShutdownOverrides.minIdleTimeoutInMinutes` / `maxIdleTimeoutInMinutes`, **not** `minTimeoutMinutes` / `maxTimeoutMinutes`.
- `defaultIdleShutdown.detection.httpGet` is **mandatory** when `defaultIdleShutdown.enabled: true`. For SageMaker Distribution JupyterLab, use `path: /api/idle`, `port: 8888`, `scheme: HTTP`.

`kubectl explain workspacetemplate.spec.defaultIdleShutdown` and `kubectl explain workspacetemplate.spec.idleShutdownOverrides` against the live API are authoritative.

### Stopped Space Immediately Restores the Warm Buffer

Expected behaviour, not a bug. When a user stops a Workspace (`desiredStatus: Stopped`) the Spaces controller deletes the underlying Deployment and Service. The placeholder Deployment immediately schedules a replacement pod, which lands on the same warm node (labels, tolerations, and anti-affinity all match, and the image is already cached). The node never becomes empty, so Karpenter's `consolidateAfter` timer does not start. This is what "self-healing warm buffer" means in practice.

If you specifically want a stopped Space to release the node for cost, scale the placeholder Deployment to `0` first — then stopping/deleting the Space leaves the node empty and Karpenter will consolidate it after `consolidateAfter`.

## Known Limitations

- **On-demand only.** HyperPod managed Karpenter does not support spot instances for autoscaling instance groups.
- **`DeepHealthChecks` incompatibility.** Instance groups with DHC enabled are incompatible with Karpenter autoscaling — pods remain `Pending` for the duration of the 60–90 minute DHC. Do not enable DHC on Spaces instance groups.
- **Instance groups must start at 0.** Karpenter manages all scaling; pre-existing non-Karpenter nodes in a Karpenter-managed instance group will be scaled down.
- **EBS AZ binding.** Space EBS volumes are AZ-bound. A Space may fail to schedule if the AZ holding its EBS volume has no available warm node. Align placeholder zones with EBS volume zones where possible.
- **Task Governance denies un-labelled Workloads.** In TG-managed namespaces, every Pod/Deployment must carry `kueue.x-k8s.io/queue-name`. The Spaces controller propagates this label from Workspace metadata to the underlying Deployment; **users must set it on the Workspace itself.**
- **The Karpenter controller is not visible in the cluster.** No pod, no metrics endpoint, no logs via `kubectl`. Use `NodeClaim`s, events, and the SageMaker API for observability. See [Operations & Observability](./09-operations-and-observability.md#observability).

## Where to Get Help

- Open an issue in the [`awslabs/ai-on-sagemaker-hyperpod`](https://github.com/awslabs/ai-on-sagemaker-hyperpod/issues) repo.
- HyperPod documentation: [SageMaker HyperPod EKS Cluster IDE](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-cluster-ide.html), [Task Governance](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-eks-operate-console-ui-governance.html).
- Kubernetes docs: [Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/), [Cluster Proportional Autoscaler](https://github.com/kubernetes-sigs/cluster-proportional-autoscaler).
