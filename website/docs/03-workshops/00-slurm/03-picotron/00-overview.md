---
title: Picotron Overview
sidebar_position: 0
---

# Picotron

This test case demonstrates how to use [Picotron](https://github.com/huggingface/picotron), a distributed training framework designed for education and research. Developed by HuggingFace, Picotron focuses on simplicity, hackability, and providing an easy-to-understand implementation of 4D parallelism (Data, Tensor, Pipeline, Context). We recommend checking out the repository for more information!

Picotron is a lightweight, educational framework for pre-training Llama-like models. While not optimized for peak performance, it offers a clear and minimalistic codebase, making it ideal for learning and experimentation in distributed training.

## Pre-Requisites

:::note Run on HyperPod Controller Node
All steps in this section must be performed on the cluster head node. Before starting, ensure you've followed the instructions in the [SSH into Cluster](../02-cluster-setup/03-ssh-into-cluster.md) guide to log into the head node. To verify that you're on the head node, run the following commands:

```bash
whoami      # Should return 'ubuntu'

# If you're not the 'ubuntu' user, switch to it
sudo su - ubuntu
pwd         # Should return /fsx/ubuntu
```
:::
