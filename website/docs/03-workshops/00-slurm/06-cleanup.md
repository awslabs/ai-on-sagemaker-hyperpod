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

:::note
**If running in AWS Workshop Studio:** The VPC and observability stacks are managed by the workshop event and will be cleaned up automatically when the event ends. You only need to delete the HyperPod cluster (above).

**If running self-paced in your own account:** Delete all resources you created, in this order:
1. Delete the observability stack: `aws cloudformation delete-stack --stack-name os-observability`
2. Delete the cluster infrastructure stack: `aws cloudformation delete-stack --stack-name sagemaker-hyperpod`
3. Delete the VPC stack (last): `aws cloudformation delete-stack --stack-name sagemaker-vpc`

Wait for each stack to fully delete before proceeding to the next.
:::
