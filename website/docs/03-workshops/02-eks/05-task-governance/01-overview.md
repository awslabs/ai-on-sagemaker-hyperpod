---
title: "Task Governance: Team Expansion"
sidebar_position: 1
---

# Task Governance: Team Expansion

:::tip Reference Documentation
For production guidance, see [Task Governance for Training](/docs/eks-orchestration/add-ons/Task%20Governance/Task%20Governance%20for%20Training).
:::

:::warning Did you deploy an inference endpoint? Free up the GPU node first 🧹
This module needs both GPUs. If you still have a JumpStart or vLLM deployment, or a training job running, delete it before continuing:

```bash
kubectl delete jumpstartmodel --all -n default
kubectl delete inferenceendpointconfig --all -n default
kubectl delete hyperpodpytorchjob hpto-job -n default --ignore-not-found
```
:::

## 💬 The Plot Twist

Just when we thought the investor had no more tricks left up his sleeve, he comes up with this question:

**Jane Doe**: "Funny you should mention that. We actually recently signed partnership agreements with two universities. ML Engineer, can we handle multiple teams on the same cluster?"

**You**: "Absolutely. Let me show you Task Governance."

## 🎯 Mission: Multi-Team Resource Management

**The Challenge**: Your startup just got funding! Now you need to support:

- **Team A** (Your internal antimicrobial research team)
- **Team B** (University partner doing enzyme engineering)
- **More partnerships coming!**

**Your task**: Set up task governance to:

- Allocate guaranteed compute to each team
- Allow teams to borrow idle resources
- Automatically reclaim resources when needed
- Prioritize critical workloads (inference > training)

**Why this matters**: In production, you'll have multiple teams, projects, and priorities. Task governance ensures fair resource allocation without manual intervention.

:::note
Yes, this will be the ML Infrastructure team's responsibility, but the infra engineers are MIA, and Jane Doe requires you to put the ML Infra Engineer hat on for the sake of the startup.
:::

## 🏗️ What is Task Governance?

SageMaker HyperPod task governance is a management system designed to streamline resource allocation and ensure efficient utilization of compute resources across teams and projects for your Amazon EKS clusters, providing administrators with the capability to set priority levels for various tasks, compute allocation for each team, how each team lends and borrows idle compute, and if a team preempts their own tasks.

HyperPod task governance leverages Kueue for Kubernetes-native job queueing, scheduling, and quota management and is installed using the HyperPod task governance EKS add-on.

Ready to set it up? Let's configure multi-team resource management! →

- [1. Setup Task Governance](./02-setup.md)
- [2. Multi-Team Example](./03-multi-team-scenario.md)
