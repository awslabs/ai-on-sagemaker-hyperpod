---
title: Setup
sidebar_position: 2
---

# Setup

## 🔧 Installing Task Governance

**What we're doing**: Installing the SageMaker HyperPod task governance add-on to enable multi-team resource management.

**Requirements**:

- Kubernetes version 1.30 or greater
- No existing Kueue installations (clean cluster)

## Step 1: Install the Task Governance Add-on

Navigate to your HyperPod Cluster in the SageMaker AI console. Open the **Add-ons** tab and click `Install` under the **Amazon SageMaker HyperPod task governance** add-on.

Wait for the add-on status to show `Active` before continuing.

:::tip
See [Installing the add-on](/docs/eks-orchestration/add-ons/Task%20Governance/Task%20Governance%20for%20Training#installing-the-add-on) in the reference documentation for the equivalent CLI steps.
:::

## Task governance concepts \[ INFORMATIONAL \]

Amazon SageMaker HyperPod task governance uses policies to define resource allocation and task prioritization. These policies are categorized into **compute prioritization** and **compute allocation**.

### Cluster policy

Compute prioritization, also known as **cluster policy**, determines how idle compute is borrowed and how tasks are prioritized across teams. A cluster policy consists of two key components:

- Task Prioritization
- Idle Compute Allocation

As an administrator, you should define your organization's priorities and configure the cluster policy accordingly.

### Idle compute allocation

Idle compute allocation defines how idle compute is distributed among teams. This determines whether and how teams can borrow idle compute. You can choose between the following allocation strategies:

- **First come, first served**: Teams are not prioritized over one another. Each incoming task has an equal chance of obtaining over-quota resources. Compute is allocated based on the order of task submission, meaning a single user could use 100% of the idle compute if they request it first.
- **Fair-share**: Teams borrow idle compute based on their assigned weights. These weights are defined in the compute allocation and determine how compute is distributed among teams when idle resources are available.

### Task prioritization

Task prioritization determines how tasks are queued as compute becomes available. You can choose between the following methods:

- **First come, first served**: Tasks are queued in the order they are submitted.
- **Task ranking**: Tasks are queued based on their assigned priority. Tasks within the same priority class are processed on a first-come, first-serve basis. If preemption is enabled in the compute allocation, higher-priority tasks can preempt lower-priority tasks within the same team.

Here's an example configuration for a cluster policy. In this example, we have `inference` tasks as top priority, and have enabled the idle compute allocation to the fair-share strategy (based on team weights).

```
inference (weight: 90)        ← Highest priority
experimentation (weight: 80)
training (weight: 70)
fine-tuning (weight: 50)      ← Lowest priority
```

### Compute allocations

Compute allocation, or compute quota, defines a team's compute allocation and what weight (or priority level) a team is given for fair-share idle compute allocation.

You will need at minimum **two** compute allocations created in order to borrow capacity and preempt tasks across teams. The total reserved quota should not surpass the cluster's available capacity for that resource, to ensure proper quota management. For example, if a cluster comprises 20 `ml.c5.2xlarge` instances, the cumulative quota assigned to teams should remain under 20. For more details on how compute is allocated in task governance, please follow the [documentation for task governance](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-governance.html).

In the next section, we will walk through a detailed example with step-by-step instructions on configuring these settings.

Let's show Jane Doe that we can onboard the university partners smoothly!
