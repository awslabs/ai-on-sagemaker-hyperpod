---
title: Overview & Architecture
sidebar_position: 1
---

# Overview & Architecture

## What This Add-On Does

SageMaker HyperPod EKS clusters running the **Spaces** (IDE and Notebooks) add-on with Karpenter autoscaling will scale to zero when no workspaces are active. That's cost-efficient, but the next user who opens a workspace pays the full **cold-start** — EC2 instance launch, Kubernetes node registration, container image pull, and workspace pod initialisation — before their IDE is usable.

This add-on eliminates that cold-start by keeping a small pool of pre-provisioned nodes warm, with the SageMaker Distribution image already cached on each one. When a user creates a new Space, it lands on a warm node in seconds instead of minutes.

### What you get

- **Warm nodes**, held by low-priority placeholder pods that are cheap to preempt when real workloads arrive.
- **Pre-pulled container images**, cached on each warm node by an `initContainer` that runs before the placeholder becomes ready.
- **Automatic scale-out**, driven by the Cluster Proportional Autoscaler (CPA) — the warm pool grows with the cluster.
- **Cost controls**, via `min`/`max` caps on the CPA and Karpenter's `WhenEmpty` consolidation.

## How It Works

1. A low-priority (`-1000`) **placeholder Deployment** holds one `pause` pod on each warm node.
2. Before the `pause` container starts, an `initContainer` **pre-pulls** the SageMaker Distribution image so it is cached on the node.
3. When a real Workspace pod arrives — default Kubernetes priority is `0`, which is higher than `-1000` — the scheduler **preempts** the placeholder if the node cannot accommodate both.
4. **Karpenter provisions a replacement node** for the displaced placeholder in the background, and the new placeholder's `initContainer` re-pulls the image onto the replacement node.
5. The **Cluster Proportional Autoscaler** scales the placeholder Deployment as the cluster grows, so the warm buffer stays proportional to real usage.

```
┌─────────────────────────────────────────────────────────────────┐
│                SageMaker HyperPod EKS Cluster                   │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐         │
│  │   Node A     │   │   Node B     │   │   Node C     │         │
│  │ [Space Pod]  │   │ [Placeholder]│   │ [Placeholder]│         │
│  │ (Running)    │   │ (Running)    │   │ (Running)    │         │
│  │ image cached │   │ image cached │   │ image cached │         │
│  └──────────────┘   └──────────────┘   └──────────────┘         │
│                             │                                   │
│  New Space request ─────────┤  Preempts placeholder             │
│                             ▼                                   │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐         │
│  │   Node A     │   │   Node B     │   │   Node C     │         │
│  │ [Space Pod]  │   │ [NEW Space]  │   │ [Placeholder]│         │
│  │ (Running)    │   │ scheduled    │   │ (Running)    │         │
│  │              │   │ instantly,   │   │              │         │
│  │              │   │ image cached │   │              │         │
│  └──────────────┘   └──────────────┘   └──────────────┘         │
│                                                                 │
│  Karpenter provisions Node D for the displaced placeholder      │
│  (background — initContainer pre-pulls image on Node D)         │
└─────────────────────────────────────────────────────────────────┘
```

## Priority & Preemption Model

Two priority systems coexist in this cluster. They serve different purposes.

| Layer | Resource kind | API group | What it drives | Managed by |
|---|---|---|---|---|
| Kubernetes scheduler priority | `PriorityClass` | `scheduling.k8s.io/v1` | Node-level preemption at pod-scheduling time (numeric value) | This guide |
| Kueue admission priority | `WorkloadPriorityClass` | `kueue.x-k8s.io/v1beta1` | Admission ordering and quota-based preemption in Kueue | Cluster admin / Task Governance |

This add-on creates **only** the Kubernetes `PriorityClass` (`overprovisioning-placeholder`, value `-1000`). The Kueue `WorkloadPriorityClass` set is managed separately — HyperPod Task Governance ships defaults such as `interactive-priority`, `training-priority`, and so on. Users reference an existing `WorkloadPriorityClass` on the Workspace itself via the `kueue.x-k8s.io/priority-class` label.

### Why the Spaces controller doesn't need a high-priority class

The Spaces controller does **not** set an explicit `priorityClassName` on the Workspace pod. Workspaces run with the default priority `0`. Since the placeholder is at `-1000`, `0 > -1000` is sufficient for the scheduler to preempt placeholders whenever a Workspace needs the node. No extra plumbing is required on the Workspace side.

## Karpenter on HyperPod: What's Different

The Karpenter installation on a HyperPod EKS cluster is **managed by SageMaker**. Two consequences matter for this guide:

- **The Karpenter controller is not a pod in your cluster.** `kubectl get pods -n kube-system -l app=karpenter` returns nothing. The controller runs in the SageMaker control plane. Verify Karpenter is active via `aws sagemaker describe-cluster … --query 'AutoScaling'` (Section 3.2 of [Prerequisites & Values](./02-prerequisites-and-values.md)).
- **Node provisioning uses `HyperpodNodeClass`, not `EC2NodeClass`.** Karpenter calls `sagemaker:UpdateCluster` to scale HyperPod instance groups rather than provisioning EC2 instances directly. Instance groups must start at `0` nodes so Karpenter can manage all scaling.

Everything else — `NodePool`, disruption budgets, consolidation policies, `NodeClaim` — behaves like upstream Karpenter v1.

## Image Pre-Warming: `initContainers` vs DaemonSet

The AWS documentation shows two ways to pre-cache images across nodes: an `initContainer` inside the placeholder Deployment, or a dedicated `DaemonSet` that runs on every node. Both are valid.

| Approach | Pros | Cons |
|---|---|---|
| **`initContainer` in placeholder Deployment** (this guide) | Single object; no extra RBAC; image is pulled exactly when a warm node is provisioned for a placeholder | Image is only cached on nodes that currently hold a placeholder pod |
| **DaemonSet** (AWS-documented alternative) | Warms images on every node regardless of placeholder state; most resilient | Extra RBAC; images pulled even on nodes that may never serve a Space |

This add-on uses the `initContainer` approach because Spaces land only on nodes reserved by placeholders — those are the only nodes that need the image cached. If your cluster topology means Spaces can land on nodes that never held a placeholder (for example, a shared NodePool covering multiple workload classes), prefer the DaemonSet approach.

## Expected Latency

Startup times below are **indicative** — measured on one cluster with a CPU-only Spaces workload on `ml.m5.12xlarge` and the `sagemaker-distribution:latest-cpu` image (approximately 3.5 GB). Your numbers will vary with instance type, image size, region, and network conditions.

| Scenario | Approximate startup latency | Notes |
|---|---|---|
| Cold-start (no warm node, image not cached) | 5–7 minutes | Karpenter node provisioning + image pull + workspace init |
| Warm start, Workspace **coexists** with placeholder on the same node | ~15 seconds | Fastest path; no preemption |
| Warm start, Workspace **preempts** placeholder | ~30–40 seconds | Placeholder evicted, Workspace scheduled onto now-free warm node |

For GPU Spaces, the pattern extends by adding `nvidia.com/gpu: "1"` to the placeholder's resource requests and tolerating the GPU node taint. Startup timings scale with image size — the `sagemaker-distribution:latest-gpu` image is roughly 9.85 GB, about 2.7× the CPU image — so pre-warming saves proportionally more wall-clock time on GPU nodes. This guide documents the CPU path end-to-end; see [Placeholder Deployment → GPU extension](./05-placeholder-deployment.md#gpu-spaces-extension) for the delta.

## Next steps

- [Prerequisites & Values](./02-prerequisites-and-values.md) — what your cluster needs and the variables you'll set once.
- [Pre-flight Checks](./03-preflight-checks.md) — read-only checks with expected output and remediation.
