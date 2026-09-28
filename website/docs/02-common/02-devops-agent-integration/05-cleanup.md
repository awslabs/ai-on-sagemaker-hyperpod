---
title: Cleaning Up
sidebar_position: 5
---

# Cleaning up

To remove all resources created by this solution, run:

```bash
make teardown-stack
```

This deletes the CloudFormation stack (the two custom resources first
disassociate the webhook and delete the skill assets **before** the Agent
Space is removed), then removes the assets bucket.

The email dedup-marker bucket (`hpda-markers-<slug>-<account>-<region>`) is
part of the stack and is removed with it.

**What gets removed:**

- The CloudFormation stack and all its resources (Lambdas, IAM roles,
  EventBridge rules, S3 buckets, Secrets Manager secret).
- The Agent Space in DevOps Agent.
- The EKS access entries (for EKS-orchestrated clusters).
- The webhook secret in Secrets Manager.
- The email dedup-marker bucket.
