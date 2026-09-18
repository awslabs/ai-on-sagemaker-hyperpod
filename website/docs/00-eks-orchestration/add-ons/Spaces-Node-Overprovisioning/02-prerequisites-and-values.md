---
title: Prerequisites & Values
sidebar_position: 2
---

# Prerequisites & Values

## Required Cluster Components

Confirm your cluster meets these requirements before applying anything.

| Component | Requirement |
|---|---|
| HyperPod EKS cluster | Running with `NodeProvisioningMode: Continuous` |
| Karpenter | Enabled — `AutoScaling.Status: InService`, with at least one `NodePool` and one `HyperpodNodeClass` targeting your Spaces instance group |
| Spaces add-on | Installed — the `workspaces.workspace.jupyter.org` and `workspacetemplates.workspace.jupyter.org` CRDs are present |
| WorkspaceTemplates | Per-namespace templates already deployed. This add-on does not create any WorkspaceTemplates |
| Task Governance | Optional. If enabled, the `hyperpod-task-governance-admission-policy` `ValidatingAdmissionPolicy` will apply to any namespace carrying both `sagemaker.amazonaws.com/activate-quota=Enabled` and `sagemaker.amazonaws.com/sagemaker-managed-queue=true`. The `overprovisioning` namespace created in [Step 4](./04-namespace-and-priorityclass.md) must **not** carry those labels |
| Image pull access | Nodes must be able to pull from `public.ecr.aws/sagemaker/sagemaker-distribution` (or wherever your WorkspaceTemplate image lives) |

## Information You'll Gather

The pre-flight checks in the [next section](./03-preflight-checks.md) collect these values. Fill them into the Step 0 block below before applying any manifest in this guide.

| Variable | What it is | How to find it |
|---|---|---|
| `OVERPROVISIONING_NS` | Namespace that will hold placeholder pods and CPA | Business decision — default is `overprovisioning` |
| `KARPENTER_NODEPOOL_NAME` | Karpenter `NodePool` scoped to your Spaces instance group | `kubectl get nodepool` |
| `HYPERPOD_NODECLASS_NAME` | `HyperpodNodeClass` referenced by the NodePool | `kubectl get hyperpodnodeclass` |
| `NODE_LABEL_KEY` / `NODE_LABEL_VALUE` | Label the NodePool sets on every node it provisions | `kubectl get nodepool <name> -o yaml \| grep -A10 labels` |
| `INSTANCE_TYPE` | Primary instance type in the NodePool | `kubectl get nodepool <name> -o yaml \| grep instance-type` |
| `NODE_ALLOCATABLE_CPU` | Allocatable CPU on one node of that type | `kubectl describe node <node> \| awk '/^Allocatable:/,/^System Info:/'` |
| `NODE_ALLOCATABLE_MEMORY` | Allocatable memory on one node of that type | same as above |
| `PLACEHOLDER_CPU_REQUEST` | CPU request per placeholder pod | Derived from allocatable — see sizing guidance in [Placeholder Deployment](./05-placeholder-deployment.md#sizing-guidance) |
| `PLACEHOLDER_MEMORY_REQUEST` | Memory request per placeholder pod | Derived from allocatable |
| `CPA_MIN` | Minimum warm-node count | Business decision |
| `CPA_MAX` | Maximum warm-node count (cost cap) | Business decision |
| `CPA_NODES_PER_REPLICA` | CPA ratio — 1 placeholder per N nodes | Tune to burst pattern |
| `CPA_CORES_PER_REPLICA` | CPA ratio — 1 placeholder per N cores | Should match the vCPU count of your instance type |
| `WORKSPACE_IMAGE` | Container image your WorkspaceTemplates use | `kubectl get workspacetemplate -A -o yaml \| grep image` |
| `WORKSPACE_TEMPLATE_NAMESPACE` | Namespace where your WorkspaceTemplates live | `kubectl get workspacetemplates -A` |
| `TG_NAMESPACE_FOR_TEST` | A TG-managed namespace for the verification tests | `kubectl get ns -l sagemaker.amazonaws.com/activate-quota=Enabled` (skip if TG is not enabled) |
| `TEMPLATE_FOR_TEST` | A WorkspaceTemplate name for the verification tests | `kubectl get workspacetemplates -A` |
| `WORKSPACE_PRIORITY_CLASS` | Kueue `WorkloadPriorityClass` for verification Workspaces | `kubectl get workloadpriorityclass` (skip if TG is not enabled) |

## Step 0 — Set Your Cluster-Specific Values

Fill in every value below, then run the sanity-check loop at the bottom. Every `kubectl` and YAML command in this guide references these variables — set them once and copy-paste the rest.

```bash
# ─────────────────────────────────────────────────────────────────────────────
# EDIT ALL VALUES BELOW TO MATCH YOUR CLUSTER, THEN EXPORT.
# Use the pre-flight checks in the next section to gather any values you don't
# already know.
# ─────────────────────────────────────────────────────────────────────────────

# Namespace that will hold placeholder pods and CPA.
# MUST NOT carry Task Governance labels (see Step 4).
export OVERPROVISIONING_NS="overprovisioning"

# Karpenter NodePool name scoped to your HyperPod instance group.
# Find with: kubectl get nodepool
export KARPENTER_NODEPOOL_NAME="<your-nodepool-name>"

# HyperpodNodeClass name referenced by the NodePool.
# Find with: kubectl get hyperpodnodeclass
export HYPERPOD_NODECLASS_NAME="<your-nodeclass-name>"

# Label key/value the NodePool sets on every node it provisions.
# The placeholder pod's affinity uses this so placeholders only land on warm
# nodes managed by this NodePool.
# Find with: kubectl get nodepool <name> -o yaml | grep -A10 labels
export NODE_LABEL_KEY="<your-node-label-key>"
export NODE_LABEL_VALUE="<your-node-label-value>"

# Primary instance type allowed by the NodePool.
# Used for nodeAffinity in the placeholder Deployment.
# Example: ml.m5.12xlarge
export INSTANCE_TYPE="<your-instance-type>"

# Allocatable CPU and memory on each node.
# Find with: kubectl describe node <node> | awk '/^Allocatable:/,/^System Info:/'
# Values below are INDICATIVE for ml.m5.12xlarge; verify against your own node.
export NODE_ALLOCATABLE_CPU="<your-node-allocatable-cpu>"       # e.g. 47810m
export NODE_ALLOCATABLE_MEMORY="<your-node-allocatable-memory>" # e.g. 193044768Ki (~184 GiB)

# CPU and memory REQUEST per placeholder pod.
# Sizing rule:
#   PLACEHOLDER_CPU    <= NODE_ALLOCATABLE_CPU  minus daemonset overhead
#   PLACEHOLDER_MEMORY <= NODE_ALLOCATABLE_MEMORY minus daemonset overhead
#
# Set small (e.g. 2 / 8Gi) so that Workspaces smaller than
# (NODE_ALLOCATABLE_CPU - PLACEHOLDER_CPU_REQUEST) can COEXIST on the same
# node as the placeholder — this is the fastest warm-start path, no preemption.
#
# Set large (near allocatable) if you want each placeholder to hold an
# entire node exclusively — every Workspace will then preempt the placeholder.
export PLACEHOLDER_CPU_REQUEST="<your-placeholder-cpu-request>"       # e.g. 2
export PLACEHOLDER_MEMORY_REQUEST="<your-placeholder-memory-request>" # e.g. 8Gi

# Steady-state number of warm nodes (placeholder replicas at minimum).
# CPA may scale this up. This is the floor. Example: 2
export CPA_MIN="<your-cpa-min>"

# Maximum placeholder replicas CPA will ever create (cost cap). Example: 5
export CPA_MAX="<your-cpa-max>"

# CPA scaling: 1 placeholder per N nodes in the NodePool. Example: 3
export CPA_NODES_PER_REPLICA="<your-nodes-per-replica>"

# CPA scaling: 1 placeholder per N CPU cores across the NodePool.
# Tip: set to the vCPU count of your instance type for roughly 1 placeholder
# per node. Example: 48 for ml.m5.12xlarge.
export CPA_CORES_PER_REPLICA="<your-cores-per-replica>"

# WorkspaceTemplate container image — the initContainer pre-pulls this so it
# is cached on warm nodes.
# Find with: kubectl get workspacetemplate -A -o yaml | grep image
# Example: public.ecr.aws/sagemaker/sagemaker-distribution:latest-cpu
export WORKSPACE_IMAGE="<your-workspace-image>"

# Namespace where your WorkspaceTemplates are stored (referenced by the
# verification Workspaces in Step 8).
# Find with: kubectl get workspacetemplates -A
export WORKSPACE_TEMPLATE_NAMESPACE="<your-workspace-template-namespace>"

# --- Verification-only values (Step 8) ---
# Skip these if Task Governance is not enabled in your cluster; the
# verification tests can run in any non-TG namespace without Kueue labels.

# A TG-managed namespace and template name to use for verification.
# Find TG namespaces:  kubectl get ns -l sagemaker.amazonaws.com/activate-quota=Enabled
# Find templates:      kubectl get workspacetemplates -A
export TG_NAMESPACE_FOR_TEST="<your-tg-namespace>"
export TEMPLATE_FOR_TEST="<your-workspace-template-name>"

# Kueue WorkloadPriorityClass (kueue.x-k8s.io/v1beta1) to apply to verification
# Workspaces. This is a Kueue WorkloadPriorityClass, NOT a k8s PriorityClass.
# Find with: kubectl get workloadpriorityclass
# Task Governance ships defaults including interactive-priority (60),
# training-priority (80), etc.
export WORKSPACE_PRIORITY_CLASS="<your-workload-priority-class>"

# ─────────────────────────────────────────────────────────────────────────────
# SANITY CHECK — run this after filling in the values above.
# Any <...> placeholder will produce an ERROR line.
# ─────────────────────────────────────────────────────────────────────────────
for var in KARPENTER_NODEPOOL_NAME HYPERPOD_NODECLASS_NAME NODE_LABEL_KEY NODE_LABEL_VALUE \
           INSTANCE_TYPE NODE_ALLOCATABLE_CPU NODE_ALLOCATABLE_MEMORY \
           PLACEHOLDER_CPU_REQUEST PLACEHOLDER_MEMORY_REQUEST \
           CPA_MIN CPA_MAX CPA_NODES_PER_REPLICA CPA_CORES_PER_REPLICA \
           WORKSPACE_IMAGE WORKSPACE_TEMPLATE_NAMESPACE; do
  val="${!var}"
  if [[ -z "$val" || "$val" == *"<"* ]]; then
    echo "ERROR: \$${var} is not set or still a placeholder (value: '${val}')"
  fi
done
echo "Sanity check complete — fix any ERROR lines above before proceeding."
```

## How to Apply Manifests with These Variables

Every manifest in this guide uses `${VAR}` references so you can apply them either way:

```bash
# Option A — envsubst (requires gettext: brew install gettext / apt install gettext)
envsubst < manifest.yaml | kubectl apply -f -

# Option B — heredoc, which expands shell variables inline
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${OVERPROVISIONING_NS}
EOF
```

All examples in this guide use the heredoc style, which works with either approach.

:::note
The `NODE_ALLOCATABLE_CPU`/`NODE_ALLOCATABLE_MEMORY` example values above are **indicative** for `ml.m5.12xlarge`. `ml.m5.12xlarge` has 48 vCPU and 192 GiB of memory in total; allocatable is lower after the kubelet's system reservation and any system pods. Always read your own node with `kubectl describe node` before setting placeholder requests.
:::

## Next steps

- [Pre-flight Checks](./03-preflight-checks.md) — verify each of these values and confirm the cluster is ready.
