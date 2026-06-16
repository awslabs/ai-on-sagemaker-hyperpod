---
title: Cleanup
sidebar_position: 7
---

# Cleanup

Now that we've completed the workshop, let's clean up the resources we created.

:::important
Please do not delete the `sagemaker-vpc` CloudFormation template until your HyperPod cluster has completely finished deleting.
:::

## Delete the Cluster via CLI

```bash
aws sagemaker delete-cluster --cluster-name ml-cluster
```

## Delete the Cluster via the SageMaker HyperPod Console

Navigate to the [SageMaker HyperPod Console](https://console.aws.amazon.com/sagemaker/home?%2Fcluster-management#/cluster-management) and delete the cluster from the UI.

:::warning
Cluster deletion can take a few minutes. **DO NOT** proceed to the final step (deleting CloudFormation stack) until the cluster has completely finished deleting.
:::

## Final Step - Delete CloudFormation Resources

Once you have confirmed successful deletion of your HyperPod Cluster (no resources showing up in the [HyperPod Cluster Management Console](https://console.aws.amazon.com/sagemaker/home?%2Fcluster-management#/cluster-management)), you can proceed with deleting the CloudFormation stacks deployed during the setup phase.

Delete the stacks in the following order:

1. `aws cloudformation delete-stack --stack-name os-observability` (monitoring stack)
2. `aws cloudformation delete-stack --stack-name sagemaker-hyperpod` (cluster infrastructure)
3. `aws cloudformation delete-stack --stack-name sagemaker-vpc` (VPC and networking — delete last)

Wait for each stack to fully delete before proceeding to the next.
