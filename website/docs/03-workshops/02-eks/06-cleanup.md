---
title: Mission Complete & Cleanup
sidebar_position: 7
---

# Mission Complete

## 🏆 Congratulations!

You've completed Project Helix and demonstrated the complete ML pipeline on SageMaker HyperPod:

- ✅ **Training** (ESM2 distributed training with FSDP)
- ✅ **Resiliency** (150-second surgical recovery)
- ✅ **Inference** (production deployment via JumpStart)

Total time: ~1 hour.

## Bonus: Task Governance

If you haven't already, try the [Task Governance bonus module](./05-task-governance/01-overview.md) to see how HyperPod handles multi-team resource sharing, priority-based preemption, and compute lending/borrowing.

The world needs new antibiotics. You just showed how AI infrastructure can help deliver them. 🧬

Thank you for attending our workshop! Hope you were able to learn something today.

## 🧹 Cleanup

:::important
Running the workshop in your own account incurs cost for as long as the cluster, file system and endpoints exist. Work through the steps below in order.
:::

### 1. Delete workshop workloads

If you launched the `fsx-pod` helper to browse the dataset and checkpoints on FSx, delete it now to keep your cluster tidy:

```bash
kubectl delete pod fsx-pod
```

This pod doesn't consume GPU, but it's good practice to clean up resources you no longer need.

Delete any remaining training jobs, inference deployments and task governance example jobs:

```bash
kubectl delete hyperpodpytorchjob hpto-job -n default --ignore-not-found
kubectl delete jumpstartmodel --all -n default
kubectl delete inferenceendpointconfig --all -n default
```

:::warning
Deleting a `JumpStartModel` or `InferenceEndpointConfig` is what tears down the SageMaker endpoint and its load balancer. Deleting the endpoint in the Studio UI alone leaves the Kubernetes custom resource — and the GPU reservation — in place.
:::

Confirm no GPUs remain in use and no endpoints remain:

```bash
kubectl describe nodes | grep -E '^Name:|nvidia.com/gpu'
aws sagemaker list-endpoints --output table
```

### 2. Delete the task governance policies

If you created the cluster policy and compute quotas:

```bash
aws sagemaker list-compute-quotas
aws sagemaker delete-compute-quota --compute-quota-id <compute-quota-id>

aws sagemaker list-cluster-scheduler-configs
aws sagemaker delete-cluster-scheduler-config --cluster-scheduler-config-id <cluster-scheduler-config-id>
```

### 3. Scale down or delete the HyperPod cluster

To stop paying for GPU capacity while keeping the cluster, scale the accelerated instance group to `0` from the [SageMaker HyperPod console](https://console.aws.amazon.com/sagemaker/home?%2Fcluster-management#/cluster-management).

To delete the cluster entirely:

```bash
aws sagemaker delete-cluster --cluster-name <your-cluster-name>
```

See the [delete-cluster CLI reference](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-cli-command-delete-cluster.html) for details.

:::warning
Cluster deletion can take a few minutes. **DO NOT** proceed to deleting the supporting infrastructure (EKS cluster, FSx for Lustre file system, VPC) until the HyperPod cluster has completely finished deleting.
:::

### 4. Delete the supporting infrastructure

Once the HyperPod cluster is gone, delete the remaining resources — in this order:

1. The FSx for Lustre file system and any data repository association
2. The Amazon EKS cluster
3. The S3 bucket contents and bucket
4. The SageMaker Studio Code Editor space and domain
5. The VPC, subnet and security group (delete last)

If you deployed these with CloudFormation, delete the stacks in reverse order of creation and wait for each stack to fully delete before proceeding to the next.

## What's Next?

- [Workshop Assets & ESM2 Training Code](https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-sagemaker-hyperpod)
- [SageMaker HyperPod](https://aws.amazon.com/sagemaker/ai/hyperpod/)
- [SageMaker HyperPod Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html)
- Complete workshops for both [Slurm](../00-slurm/00-overview.md) and EKS
- [Distributed Training Samples](https://github.com/awslabs/awsome-distributed-ai/tree/main)
- [Distributed Inference Samples](https://github.com/aws-samples/awsome-inference/)
