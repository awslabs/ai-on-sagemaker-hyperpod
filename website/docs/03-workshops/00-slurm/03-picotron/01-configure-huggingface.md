---
title: Configure HuggingFace Token
sidebar_position: 1
---

# Configure HuggingFace Token 🤗

In this section, we will guide you through configuring your HuggingFace Access Token, which is necessary to use Picotron.

:::note Run on HyperPod Controller Node
All steps in this section must be performed on the cluster head node. Before starting, ensure you've followed the instructions in the [SSH into Cluster](../02-cluster-setup/03-ssh-into-cluster.md) guide.

```bash
whoami      # Should return 'ubuntu'
sudo su - ubuntu
pwd         # Should return /fsx/ubuntu
```
:::

## Steps to Configure Your HuggingFace Token

1. **Create a Hugging Face Account**: If you don't already have one, create an account at [Hugging Face](https://huggingface.co).

2. **Generate a User Access Token**: After logging into your account, generate a [User Access Token](https://huggingface.co/docs/hub/en/security-tokens). If you're already logged in, you can directly access your tokens at [this link](https://huggingface.co/settings/tokens).

3. **Copy the token** to your clipboard.

4. **Set the token as an environment variable** in your terminal:

```bash
export HF_TOKEN=<your_token_here>
```

Replace `<your_token_here>` with the token you retrieved.

Now you have successfully configured your HuggingFace Token and can use it to access models and data from the HuggingFace Hub.

:::tip Troubleshooting
Getting a HuggingFace error like `503 - Service Not Available`? It's possible too many participants are trying to create tokens at the same time. Wait 2-3 minutes and try again.
:::
