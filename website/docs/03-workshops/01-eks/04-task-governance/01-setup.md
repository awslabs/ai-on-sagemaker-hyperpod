---
title: Task Governance Setup
sidebar_position: 1
---

# Task Governance: Team Expansion

## 💬 The Plot Twist

> **Investor**: "We just signed partnership agreements with two universities. Can you handle multiple teams on the same cluster?"
>
> **You**: "Absolutely. Let me show you Task Governance."

## 🎯 Mission: Multi-Team Resource Management

**The Challenge**: Your startup just got funding! Now you need to support:
- **Team A** (internal antimicrobial research team)
- **Team B** (university partner doing enzyme engineering)
- More partnerships coming!

## 🏗️ What is Task Governance?

SageMaker HyperPod Task Governance manages resource allocation across teams and projects on EKS clusters. It provides:
- Priority levels for tasks
- Compute allocation per team
- Lending and borrowing of idle compute
- Team-level task preemption

It leverages [Kueue](https://kueue.sigs.k8s.io/) for Kubernetes-native job queueing, scheduling, and quota management.

## 🔧 Installing Task Governance

Navigate to your HyperPod Cluster in the SageMaker AI console. In the **Dashboard** tab, click **"Install"** under the Amazon SageMaker HyperPod task governance add-on.

## Key Concepts

### Cluster Policy (Compute Prioritization)

Determines how idle compute is borrowed and tasks are prioritized:

- **Task Prioritization**: First In First Out, or Priority-based
- **Idle Compute Allocation**: First Come First Serve, or Fair Share

Example priority configuration:
```
inference (weight: 90)        ← Highest priority
experimentation (weight: 80)
training (weight: 70)
fine-tuning (weight: 50)      ← Lowest priority
```

### Compute Allocations

Defines a team's guaranteed compute and their fair-share weight for idle compute borrowing.
