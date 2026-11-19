---
title: Setup for Environment
sidebar_position: 2
---

# Setup for Environment

## Verify that the HyperPod Training Operator is installed on your cluster

```bash
kubectl get pods -n aws-hyperpod
```

Output:

```
NAME                                                              READY   STATUS    RESTARTS   AGE
health-monitoring-agent-bj57k                                     1/1     Running   0          17d
health-monitoring-agent-plcvm                                     1/1     Running   0          17d
hp-training-operator-hp-training-controller-manager-775bdf47f2s   1/1     Running   0          2d21h
```

:::warning Don't see the training operator pods?
Install the HyperPod training operator add-on on your cluster before continuing — see [HyperPod Training Operator overview](/docs/eks-orchestration/add-ons/hp-training-operator/overview).
:::

## Available ESM2 models on HuggingFace

1. [facebook/esm2_t6_8M_UR50D](https://huggingface.co/facebook/esm2_t6_8M_UR50D)
2. [facebook/esm2_t12_35M_UR50D](https://huggingface.co/facebook/esm2_t12_35M_UR50D)
3. [facebook/esm2_t30_150M_UR50D](https://huggingface.co/facebook/esm2_t30_150M_UR50D)
4. [facebook/esm2_t33_650M_UR50D](https://huggingface.co/facebook/esm2_t33_650M_UR50D)
5. [facebook/esm2_t36_3B_UR50D](https://huggingface.co/facebook/esm2_t36_3B_UR50D)
6. [facebook/esm2_t48_15B_UR50D](https://huggingface.co/facebook/esm2_t48_15B_UR50D)

In this workshop, we will be training the [8M parameter ESM2 Model](https://huggingface.co/facebook/esm2_t6_8M_UR50D).

## 0. Setup directory to work out of

Create workspace:

```bash
mkdir ~/esm2-workspace
cd ~/esm2-workspace
```

All your environment variables come from `fsx-shared/env_vars`, which you set up in the [Verify Cluster Connection](../02-cluster-setup/03-verify-cluster-connection.md) section. Make sure they are sourced in this terminal:

```bash
source ~/fsx-shared/env_vars
```

We will refer to them in our job YAML in the next section.
