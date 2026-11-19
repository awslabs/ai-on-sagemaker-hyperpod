---
title: Setup for Environment
sidebar_position: 1
---

# Setup for Environment

## Verify the HyperPod Training Operator

```bash
kubectl get pods -n aws-hyperpod
```

Expected output:
```
NAME                                                              READY   STATUS    RESTARTS   AGE
health-monitoring-agent-bj57k                                     1/1     Running   0          17d
health-monitoring-agent-plcvm                                     1/1     Running   0          17d
hp-training-operator-hp-training-controller-manager-775bdf47f2s   1/1     Running   0          2d21h
```

## Available ESM2 Models

| # | Model | Parameters |
|---|---|---|
| 1 | facebook/esm2_t6_8M_UR50D | 8M |
| 2 | facebook/esm2_t12_35M_UR50D | 35M |
| 3 | facebook/esm2_t30_150M_UR50D | 150M |
| 4 | facebook/esm2_t33_650M_UR50D | 650M |
| 5 | facebook/esm2_t36_3B_UR50D | 3B |
| 6 | facebook/esm2_t48_15B_UR50D | 15B |

In this workshop, we will train the **8M parameter** ESM2 model.

## Setup Workspace

```bash
mkdir ~/esm2
cd ~/esm2
```

All environment variables are already pre-set from the previous sections (located in `fsx-shared/env_vars`).
