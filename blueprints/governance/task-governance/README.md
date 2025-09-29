---
title : " Task Governance"
---

---
title : "Setup"
weight : 72
---

SageMaker HyperPod task governance is a management system designed to streamline resource allocation and ensure efficient utilization of compute resources across teams and projects for your Amazon EKS clusters. It provides administrators with the capability to set priority levels for various tasks, allocate compute resources for each team, determine how idle compute is borrowed and lent between teams, and configure whether a team can preempt its own tasks.

HyperPod task governance leverages Kueue for Kubernetes-native job queueing, scheduling, and quota management and is installed using the HyperPod task governance EKS add-on.

## Setup Task Governance EKS add-on
To install SageMaker HyperPod task governance, you will need Kubernetes version 1.30 or greater and you will need to remove any existing installations of Kueue. 

::::tabs{variant="container" activeTabId="setup_console"}

:::tab{id="setup_console" label="Setup using the AWS Console"}

Navigate to your HyperPod Cluster in the SageMaker AI console. In the **Dashboard** tab, click `Install` under the Amazon SageMaker HyperPod task governance add-on. 

:image[AddOn]{src="/static/images/10-task-governance/addon.png" height=150 disableZoom=true}
:::

:::tab{id="setup_cli" label="Setup using AWS CLI"}
To install the **SageMaker HyperPod task governance EKS add-on**, run the following command:

```
aws eks create-addon --region $REGION --cluster-name $EKS_CLUSTER_NAME --addon-name amazon-sagemaker-hyperpod-taskgovernance
```

Verify successful installation with:

```
aws eks describe-addon --region $REGION --cluster-name $EKS_CLUSTER_NAME --addon-name amazon-sagemaker-hyperpod-taskgovernance
```

If the installation was successful, you should see details about the installed add-on in the output.
:::

::::

## Task governance concepts

Amazon SageMaker HyperPod task governance uses policies to define resource allocation and task prioritization. These policies are categorized into **compute prioritization** and **compute allocation**.

### Cluster policy
Compute prioritization, also known as **cluster policy**, determines how idle compute is borrowed and how tasks are prioritized across teams. A cluster policy consists of two key components:

- Task Prioritization
- Idle Compute Allocation

:image[Cluster-Policy]{src="/static/images/10-task-governance/cluster-policy.png" height=150}

As an administrator, you should define your organization's priorities and configure the cluster policy accordingly.

#### Idle compute allocation

Idle compute allocation defines how idle compute are distributed among teams. This determines whether and how teams can borrow idle compute. You can choose between the following allocation strategies:

- **First-come first-serve**: Teams are not prioritized over one another. Each incoming task has an equal chance of obtaining over-quota resources. Compute is allocated based on the order of task submission, meaning a single user could use 100% of the idle compute if they request it first.
- **Fair-share**: Teams borrow idle compute based on their assigned **Fair-share weight**. These weights are defined in **Compute Allocation** and determine how compute is distributed among teams when idle resources are available.

#### Task prioritization
Task prioritization determines how tasks are queued as compute becomes available. You can choose between the following methods:

- **First-come first-serve**: Tasks are queued in the order they are submitted.
- **Task ranking**: Tasks are queued based on their assigned priority. Tasks within the same priority class are processed on a first-come, first-serve basis. If **Task Preemption** is enabled in **Compute Allocation**, higher-priority tasks can preempt lower-priority tasks within the same team

Here's an example configuration for a cluster policy. In this example, we have `inference` tasks as top priority, and have enabled the idle compute allocation to the fair-share strategy (based on team weights).

:image[Cluster-Policy-Priorities]{src="/static/images/10-task-governance/settings.png" height=650}

### Compute allocations

Compute allocation, or compute quota, defines a team’s compute allocation and what weight (or priority level) a team is given for fair-share idle compute allocation.

You will need at minimum two compute allocations created in order to borrow capacity and preempt tasks across teams. The total reserved quota should not surpass the cluster's available capacity for that resource, to ensure proper quota management. For example, if a cluster comprises 20 ml.c5.2xlarge instances, the cumulative quota assigned to teams should remain under 20. For more details on how compute is allocated in task governance, please follow the [documentation for task governance](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-governance.html). 

:image[CQ1]{src="/static/images/10-task-governance/cq-1.png" height=650}

In the next section, we will walk through a detailed example with step-by-step instructions on configuring these settings.
