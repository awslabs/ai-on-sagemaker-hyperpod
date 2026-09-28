---
title: Pre-flight Checks
sidebar_position: 3
---

# Pre-flight Checks

Run every check below before applying any manifest. Each check has an **expected output** and a **remediation** if the result differs.

Set `KARPENTER_NODEPOOL_NAME`, `HYPERPOD_NODECLASS_NAME`, and `NODE_LABEL_KEY`/`NODE_LABEL_VALUE` from [Step 0](./02-prerequisites-and-values.md#step-0--set-your-cluster-specific-values) before running the commands below, or substitute them by hand.

## 1. Verify Continuous Provisioning Mode

Continuous provisioning is required for Karpenter autoscaling on HyperPod.

```bash
# --cluster-name accepts either the logical ClusterName or the full cluster ARN.
# The cluster ID hex suffix from the ARN alone is NOT valid.
aws sagemaker describe-cluster \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --query 'NodeProvisioningMode'
```

**Expected:** `"Continuous"`.

**If not:** the cluster was created with `Batch` provisioning and Karpenter cannot manage its instance groups. Recreate the HyperPod cluster with `NodeProvisioningMode: Continuous`.

## 2. Verify Karpenter Autoscaling is Enabled

```bash
aws sagemaker describe-cluster \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --query 'ClusterStatus'
# Expected: "InService"

aws sagemaker describe-cluster \
  --cluster-name <cluster-arn-or-logical-name> \
  --region <region> \
  --query 'AutoScaling'
# Expected:
# {
#   "Mode": "Enable",
#   "AutoScalerType": "Karpenter",
#   "Status": "InService"
# }
```

**If `AutoScaling` is missing or disabled:**

```bash
aws sagemaker update-cluster \
  --cluster-name <cluster-arn-or-logical-name> \
  --auto-scaling '{"Mode": "Enable", "AutoScalerType": "Karpenter"}' \
  --cluster-role <cluster-role-arn>
```

Wait for `AutoScaling.Status` to reach `InService` before proceeding.

:::note
In HyperPod managed Karpenter the controller runs in the SageMaker control plane and does **not** appear as a pod inside your cluster. `kubectl get pods -n kube-system -l app=karpenter` returns nothing - this is correct. Use the SageMaker API for control-plane status and `kubectl` for cluster-side state (`nodepools`, `nodeclaims`, node objects).
:::

## 3. Verify the Karpenter NodePool and HyperpodNodeClass

```bash
kubectl get nodepool ${KARPENTER_NODEPOOL_NAME}
```

**Expected:** the NodePool is listed and its `Ready` condition is `True`.

**If not found:** run `kubectl get nodepool` to list every NodePool in the cluster and update `KARPENTER_NODEPOOL_NAME` in Step 0.

```bash
kubectl get hyperpodnodeclass ${HYPERPOD_NODECLASS_NAME}
```

**Expected:** the NodeClass is listed and `Ready=True`. If `AutoScaling.Status` in check 2 has not yet reached `InService`, the NodeClass may still be `Ready=False`; wait and retry.

**If not found:** `kubectl get hyperpodnodeclass` to list all NodeClasses and update Step 0.

## 4. Verify the Spaces Add-on is Installed

```bash
kubectl get pods -n jupyter-k8s-system

kubectl get crd | grep workspace
# Expected:
#   workspaces.workspace.jupyter.org
#   workspacetemplates.workspace.jupyter.org

kubectl get workspacetemplates -A
```

**Expected:** the Spaces operator pods are running in `jupyter-k8s-system`, both CRDs are present, and your per-namespace WorkspaceTemplates are listed.

**If the Spaces add-on is not installed:** SageMaker AI console → HyperPod Clusters → your cluster → **IDE and Notebooks** tab → **Quick Install**. Installation typically takes 2–5 minutes and deploys cert-manager, the EBS CSI driver, the AWS Load Balancer Controller, and the Spaces controller.

## 5. Verify the Health Monitoring Agent

The HyperPod Health Monitoring Agent (HMA) runs in the `aws-hyperpod` namespace. Version `>= 1.0.742.0` is required for full health monitoring integration.

```bash
kubectl get pods -n aws-hyperpod -l app=health-monitoring-agent \
  -o jsonpath='{.items[*].spec.containers[*].image}'
kubectl get pods -n aws-hyperpod
```

**Expected:** `health-monitoring-agent`, `node-exporter`, and related HyperPod system pods are running.

## 6. Task Governance Admission Policy (Conditional)

Only relevant if you plan to run Workspaces in TG-managed namespaces (typical for HyperPod clusters).

```bash
kubectl get validatingadmissionpolicy hyperpod-task-governance-admission-policy
```

**Expected if TG is enabled:** the policy is found. Its binding scopes it to namespaces carrying both `sagemaker.amazonaws.com/activate-quota=Enabled` and `sagemaker.amazonaws.com/sagemaker-managed-queue=true`. Inside such namespaces, every Pod/Deployment must carry a non-empty `kueue.x-k8s.io/queue-name` label.

**If not found:** TG is not enabled. The overprovisioning namespace safety callout in [Step 4](./04-namespace-and-priorityclass.md) still applies out of habit, but the TG-related admission warnings do not apply to your cluster.

Enumerate TG-managed namespaces (for use as `TG_NAMESPACE_FOR_TEST`):

```bash
kubectl get ns \
  -o custom-columns='NAME:.metadata.name,TG_QUOTA:.metadata.labels.sagemaker\.amazonaws\.com/activate-quota,TG_QUEUE:.metadata.labels.sagemaker\.amazonaws\.com/sagemaker-managed-queue' \
  | grep Enabled
```

## 7. Confirm the Overprovisioning Namespace Does NOT Carry TG Labels

```bash
kubectl get ns ${OVERPROVISIONING_NS} -o jsonpath='{.metadata.labels}' 2>/dev/null \
  || echo "namespace does not exist yet (expected on a fresh install)"
```

**Expected:** the namespace does not exist yet, **or** its labels contain no `sagemaker.amazonaws.com/activate-quota` and no `sagemaker.amazonaws.com/sagemaker-managed-queue`.

**If it exists with TG labels:** remove them before proceeding. Placeholder pods are `pause` containers; they are intentionally not Kueue-managed workloads, and the TG admission policy would deny them.

```bash
kubectl label ns ${OVERPROVISIONING_NS} \
  sagemaker.amazonaws.com/activate-quota- \
  sagemaker.amazonaws.com/sagemaker-managed-queue-
```

## 8. Discover Node Taints and Allocatable Resources

Placeholder pods must tolerate every taint on your target nodes, otherwise they'll remain `Pending` and defeat the pattern.

```bash
kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE} \
  -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

**Record every taint reported.** Common ones on HyperPod:

| Taint | When it appears | Toleration to add |
|---|---|---|
| `sagemaker.amazonaws.com/node-health-status=Schedulable:NoSchedule` | Some HyperPod clusters apply a health-status taint on all nodes | `key: "sagemaker.amazonaws.com/node-health-status", operator: "Equal", value: "Schedulable", effect: "NoSchedule"` |
| `nvidia.com/gpu:NoSchedule` | NVIDIA GPU nodes (device plugin / GPU operator) | `key: "nvidia.com/gpu", operator: "Exists", effect: "NoSchedule"` |
| None | Many HyperPod clusters have no taints on Spaces nodes | No tolerations needed |

Your cluster may have none of these, one of them, or others specific to your environment. **Do not add tolerations for taints that don't exist**, and **do add tolerations for every taint that does exist**. [Step 5](./05-placeholder-deployment.md) shows where to plug tolerations into the placeholder Deployment.

### Read allocatable resources for sizing

```bash
NODE=$(kubectl get nodes -l ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE} -o name 2>/dev/null | head -1)
if [ -z "$NODE" ]; then
  echo "No labeled nodes yet - reading from any available node instead:"
  NODE=$(kubectl get nodes -o name | head -1)
fi
kubectl describe $NODE | awk '/^Allocatable:/,/^System Info:/' | head -8
```

**Record the `cpu` and `memory` values as `NODE_ALLOCATABLE_CPU` and `NODE_ALLOCATABLE_MEMORY` in Step 0.**

Example output shape (values vary by instance type):

```
Allocatable:
  cpu:                <allocatable-milli-cpu>       →  NODE_ALLOCATABLE_CPU
  ephemeral-storage:  ...
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  memory:             <allocatable-memory-Ki>       →  NODE_ALLOCATABLE_MEMORY
  pods:               <max-pods>
```

## 9. Identify Your WorkspaceTemplate Image

```bash
kubectl get workspacetemplates -A \
  -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.defaultImage}{"\n"}{end}'
```

**Record the image URI as `WORKSPACE_IMAGE` in Step 0.** This is exactly what the placeholder's `initContainer` will pre-pull. If you have more than one image in use, pick the one most commonly referenced by Workspaces on your target instance group - you can add additional `initContainer` entries later to pre-warm multiple images.

## 10. Check for Stale Overprovisioning Artefacts

Safe to run on a fresh install - it just reports whether an earlier attempt left objects behind.

```bash
kubectl get priorityclass overprovisioning-placeholder 2>/dev/null \
  && echo "EXISTS - review Step 4"    || echo "not found - proceed with Step 4"
kubectl get deploy spaces-placeholder-cpu -n ${OVERPROVISIONING_NS} 2>/dev/null \
  && echo "EXISTS - review Step 5"    || echo "not found - proceed with Step 5"
kubectl get deploy spaces-overprovisioning-cpa -n ${OVERPROVISIONING_NS} 2>/dev/null \
  && echo "EXISTS - review Step 6"    || echo "not found - proceed with Step 6"
kubectl get configmap spaces-overprovision-cpa-config -n ${OVERPROVISIONING_NS} 2>/dev/null \
  && echo "EXISTS - review Step 6"    || echo "not found - proceed with Step 6"
```

If any object already exists, decide whether to keep it or delete it before re-creating. `PriorityClass.value` is immutable - see the warning in [Step 4](./04-namespace-and-priorityclass.md#priorityclass-value-is-immutable).

## Next steps

- [Namespace & PriorityClass](./04-namespace-and-priorityclass.md) - create the namespace and priority class.
