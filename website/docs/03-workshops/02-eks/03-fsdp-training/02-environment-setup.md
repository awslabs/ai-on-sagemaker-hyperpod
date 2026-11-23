---
title: Setup for Environment
sidebar_position: 2
---

# Setup for environment

## Verify that the HyperPod Training Operator is installed on your cluster

```bash
kubectl get pods -n aws-hyperpod
```

Output:

```text
NAME                                                              READY   STATUS    RESTARTS   AGE
health-monitoring-agent-bj57k                                     1/1     Running   0          17d
health-monitoring-agent-plcvm                                     1/1     Running   0          17d
hp-training-operator-hp-training-controller-manager-775bdf47f2s   1/1     Running   0          2d21h
```

:::note
The live workshop has an expandable "Don't see the training operator pods?" troubleshooting block here whose contents were not captured in the crawl. See the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/02-fsdp/01-setup) if the operator pods are missing.
:::

## Available ESM2 models on Hugging Face

1. [facebook/esm2_t6_8M_UR50D](https://huggingface.co/facebook/esm2_t6_8M_UR50D)
2. [facebook/esm2_t12_35M_UR50D](https://huggingface.co/facebook/esm2_t12_35M_UR50D)
3. [facebook/esm2_t30_150M_UR50D](https://huggingface.co/facebook/esm2_t30_150M_UR50D)
4. [facebook/esm2_t33_650M_UR50D](https://huggingface.co/facebook/esm2_t33_650M_UR50D)
5. [facebook/esm2_t36_3B_UR50D](https://huggingface.co/facebook/esm2_t36_3B_UR50D)
6. [facebook/esm2_t48_15B_UR50D](https://huggingface.co/facebook/esm2_t48_15B_UR50D)

In this workshop, we will be training the [8M parameter ESM2 model](https://huggingface.co/facebook/esm2_t6_8M_UR50D).

## Set up a directory to work out of

Create a workspace:

```bash
mkdir ~/esm2-workspace
cd ~/esm2-workspace
```

All your environment variables are already pre-set from the previous sections. These variables are located in `fsx-shared/env_vars`, and should already be sourced by default. We will refer to them in our job YAML in the next section.
