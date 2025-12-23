---
title: "HyperPod CLI Commands Reference"
sidebar_position: 30
---

# HyperPod CLI Commands Reference

This comprehensive reference guide covers relevant CLI commands for managing Amazon SageMaker HyperPod clusters.



## AWS SageMaker CLI Commands

The [AWS SageMaker CLI](https://docs.aws.amazon.com/cli/latest/reference/sagemaker/) provides comprehensive cluster management capabilities. Please refer to here for general cluster & node management. This page is to provide usecase oriented examples of using the CLI.


### Node Management

:::note[Getting AWS Instance IDs from Node Names]

### Getting AWS Instance IDs from Node Names

When working with clusters, you typically know node names (like `ip-10-1-0-16`) but AWS APIs require instance IDs (like `i-0123456789abcdef0`). Here are several methods to map between them:

#### Method 1: List All Nodes with Mapping
```bash
aws sagemaker list-cluster-nodes \
    --cluster-name <cluster-name> \
    --region <region> \
    --query 'ClusterNodeSummaries[*].[NodeId,InstanceId]' \
    --output table
```

#### Method 2: Get Instance ID for Specific Node (SLURM)
```bash
SLURM_NODE="ip-10-1-0-16"
INSTANCE_ID=$(aws sagemaker list-cluster-nodes \
    --cluster-name <cluster-name> \
    --region <region> \
    --query "ClusterNodeSummaries[?NodeId=='${SLURM_NODE}'].InstanceId" \
    --output text)
echo "Node ${SLURM_NODE} has instance ID: ${INSTANCE_ID}"
```

#### Method 3: resource_config.json (SLURM)
Upon cluster creation, HyperPod generates a `resource_config.json` in the HyperPod cluster instances, specifically within `/opt/ml/resource_config.json`. `resource_config.json` contains HyperPod cluster resource information such as IP addresses, instance types, and ARNs.
:::


### Node Recovery Operations

#### Batch Reboot GPU Nodes
```bash
GPU_NODE_IDS=$(aws sagemaker list-cluster-nodes \
    --cluster-name <cluster-name> \
    --region <region> \
    --query 'ClusterNodeSummaries[?contains(InstanceType, `p4`) || contains(InstanceType, `p5`) || contains(InstanceType, `g4`) || contains(InstanceType, `g5`)].InstanceId' \
    --output text)


aws sagemaker batch-reboot-cluster-nodes \
    --cluster-name <cluster-name> \
    --node-ids $GPU_NODE_IDS \
    --region <region>
```
Performs a soft reboot of specified (GPU) nodes. Useful for recovering from transient issues.

#### Batch Replace GPU Nodes
```bash
GPU_NODE_IDS=$(aws sagemaker list-cluster-nodes \
    --cluster-name <cluster-name> \
    --region <region> \
    --query 'ClusterNodeSummaries[?contains(InstanceType, `p4`) || contains(InstanceType, `p5`) || contains(InstanceType, `g4`) || contains(InstanceType, `g5`)].InstanceId' \
    --output text)

aws sagemaker batch-replace-cluster-nodes \
    --cluster-name <cluster-name> \
    --node-ids $GPU_NODE_IDS \
    --region <region>
```
- **What will be lost on the node after replacement:** Local storage, temporary files, local checkpoints
- **Preserved**: Shared file systems (EFS, FSx), S3, persistent volumes

**Before replacing:** Save data to shared storage, checkpoint jobs, backup configs

---

## EKS-Specific Commands

### Manual Node Operations (Alternative to APIs)

#### Label Node for Replacement
```bash
kubectl label node <node-name> sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReplacement
```

#### Label Node for Reboot
```bash
kubectl label node <node-name> sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReboot
```

#### Quarantine a Node
```bash
kubectl cordon <node-name>
kubectl delete pods --all-namespaces --field-selector spec.nodeName=<node-name>
```

### Monitoring Commands

#### Watch Node Status
```bash
watch kubectl get nodes -L sagemaker.amazonaws.com/node-health-status
```

#### Get Node Labels
```bash
kubectl get nodes --show-labels
```

#### Check Pod Status
```bash
kubectl get pods -o wide
```

---

## Slurm-Specific Commands

### Manual Node Operations

#### Replace a Node
```bash
sudo scontrol update node=<node-name> state=down reason="Action:Replace"
```

#### Reboot a Node
```bash
sudo scontrol reboot <node-name>
```

#### Drain a Node
```bash
sudo scontrol update node=<node-name> state=drain reason="Maintenance"
```

#### Resume a Node
```bash
sudo scontrol update node=<node-name> state=resume
```

### Monitoring Commands

#### Check Node Status
```bash
sinfo
```

#### Check Job Queue
```bash
squeue
```

#### Check Node Details
```bash
scontrol show node <node-name>
```

#### Monitor Slurm Controller Logs
```bash
tail -f /var/log/slurm/slurmctld.log
```

### Job Management

#### Submit a Job with Auto-Resume
```bash
sbatch --auto-resume <job-script.sbatch>
```

#### Check Job Details
```bash
scontrol show job <job-id>
```

#### Cancel a Job
```bash
scancel <job-id>
```

---

## Common Use Cases

### 1. Manual Node Replacement (EKS)

```bash
# Method 1: Using AWS CLI
aws sagemaker batch-replace-cluster-nodes \
    --cluster-name my-cluster \
    --node-ids i-0123456789abcdef0 \
    --region us-east-1

# Method 2: Using kubectl
kubectl label node hyperpod-i-0123456789abcdef0 \
    sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReplacement
```

### 2. Manual Node Replacement (Slurm)

```bash
# Step 1: Get instance ID from Slurm node name
SLURM_NODE="ip-10-1-57-141"
INSTANCE_ID=$(aws sagemaker list-cluster-nodes \
    --cluster-name my-cluster \
    --region us-east-1 \
    --query "ClusterNodeSummaries[?NodeId=='${SLURM_NODE}'].InstanceId" \
    --output text)

# Step 2: Method 1 - Using AWS CLI
aws sagemaker batch-replace-cluster-nodes \
    --cluster-name my-cluster \
    --node-ids $INSTANCE_ID \
    --region us-east-1

# Step 2: Method 2 - Using Slurm
sudo scontrol update node=$SLURM_NODE state=down reason="Action:Replace"
```

### 3. Monitoring Cluster Health

```bash
# EKS
watch kubectl get nodes -L sagemaker.amazonaws.com/node-health-status

# Slurm
watch sinfo

# Both
aws sagemaker list-cluster-nodes --cluster-name my-cluster --region us-east-1
```

### 4. Scaling Operations

```bash
# Scale up instance group
aws sagemaker update-cluster \
    --cluster-name my-cluster \
    --instance-groups '[{
        "InstanceGroupName": "worker-group",
        "InstanceCount": 10,
        "InstanceType": "ml.p4d.24xlarge"
    }]' \
    --region us-east-1

# Scale down by deleting specific nodes
aws sagemaker batch-delete-cluster-nodes \
    --cluster-name my-cluster \
    --node-ids i-0123456789abcdef0 i-0123456789abcdef1 \
    --region us-east-1
```

---

## Best Practices

### Safety Considerations

1. **Test commands** in non-production environments first
2. **Monitor job status** during node operations
3. **Use appropriate timeouts** for long-running operations

### Performance Tips

1. **Batch operations** when possible (up to 25 nodes per API call)
2. **Use health checks** to verify node status before operations
3. **Monitor CloudWatch logs** for detailed error information
4. **Set appropriate retry policies** for transient failures

### Troubleshooting

1. **Check IAM permissions** if commands fail
2. **Verify cluster state** before performing operations
3. **Monitor replacement progress** in SageMaker Console
4. **Use describe commands** to get detailed error information

---

## Additional Resources

- [SageMaker HyperPod CLI GitHub Repository](https://github.com/aws/sagemaker-hyperpod-cli)
- [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [kubectl Installation Guide](https://kubernetes.io/docs/tasks/tools/)