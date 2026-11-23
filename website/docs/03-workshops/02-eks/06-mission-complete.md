---
title: Mission Complete
sidebar_position: 7
---

# Mission complete

## 🏆 Congratulations!

You've completed Project Helix and demonstrated the complete ML pipeline on SageMaker HyperPod:

- ✅ Training (ESM2 distributed training with FSDP)
- ✅ Resiliency (150-second surgical recovery)
- ✅ Inference (production deployment via JumpStart)

Total time: about 1 hour.

## Bonus: task governance

If you haven't already, try the [task governance bonus module](./05-task-governance/01-overview.md) to see how HyperPod handles multi-team resource sharing, priority-based preemption, and compute lending/borrowing.

The world needs new antibiotics. You just showed how AI infrastructure can help deliver them. 🧬

Thank you for attending our workshop! We hope you were able to learn something today.

## 🧹 Cleanup

If you launched the `fsx-pod` helper to browse the dataset and checkpoints on FSx, delete it now to keep your cluster tidy:

```bash
kubectl delete pod fsx-pod
```

This pod doesn't consume GPU, but it's good practice to clean up resources you no longer need.

## What's next?

- [Workshop assets and ESM2 training code](https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-sagemaker-hyperpod)
- [SageMaker HyperPod](https://aws.amazon.com/sagemaker/ai/hyperpod/)
- [SageMaker HyperPod documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html)
- [Complete workshops for both Slurm and EKS](https://awslabs.github.io/ai-on-sagemaker-hyperpod/)
- [Distributed training samples](https://github.com/awslabs/awsome-distributed-ai/tree/main)
- [Distributed inference samples](https://github.com/aws-samples/awsome-inference/)
