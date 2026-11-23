---
title: Task Governance - Team Expansion
sidebar_position: 1
---

# Task governance: team expansion

:::warning
Did you deploy an inference endpoint? Free up the GPU node first 🧹 — see the [vLLM cleanup step](../04-inference/06-deploy-vllm.md#cleanup-delete-the-inference-deployment-required).
:::

## 💬 The plot twist

Just when we thought the investor had no more questions, he comes up with this one:

> **Jane Doe:** "Funny you should mention that. We actually recently signed partnership agreements with two universities. ML Engineer, can we handle multiple teams on the same cluster?"
>
> **You:** "Absolutely. Let me show you task governance."

## 🎯 Mission: multi-team resource management

**The challenge:** your startup just got funding! Now you need to support:

- Your internal antimicrobial research team
- A university partner doing enzyme engineering
- More partnerships coming!

**Your task:** set up task governance to:

- Allocate guaranteed compute to each team
- Allow teams to borrow idle resources
- Automatically reclaim resources when needed
- Prioritize critical workloads (inference > training)

**Why this matters:** in production, you'll have multiple teams, projects, and priorities. Task governance ensures fair resource allocation without manual intervention.

:::note
Yes, this would normally be the ML Infrastructure team's responsibility, but they are unavailable, and Jane Doe requires you to act as the ML Infrastructure Engineer for the sake of the startup.
:::

:::note
The crawl dropped the team names from the challenge list above; they are described rather than named. The next pages name them Team A and Team B.
:::

## 🏗️ What is task governance?

SageMaker HyperPod task governance is a management system designed to streamline resource allocation and ensure efficient utilization of compute resources across teams and projects for your Amazon EKS clusters. It provides administrators with the capability to set priority levels for various tasks, compute allocation for each team, how each team lends and borrows idle compute, and whether a team preempts their own tasks.

HyperPod task governance leverages [Kueue](https://kueue.sigs.k8s.io/) for Kubernetes-native job queueing, scheduling, and quota management, and is installed using the HyperPod task governance EKS add-on.

Ready to set it up? Let's configure multi-team resource management! →

- [1. Set up task governance](./02-setup.md)
- [2. Multi-team example](./03-multi-team-scenario.md)
