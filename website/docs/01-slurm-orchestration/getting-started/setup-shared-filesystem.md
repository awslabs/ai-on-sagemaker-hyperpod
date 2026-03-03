---
title: Set up your shared file system
sidebar_position: 2
---

# Shared File System Setup for SageMaker HyperPod (Slurm)

## Why Shared File Systems Matter

A high-performance shared file system is **critical** for achieving optimal performance in distributed machine learning workloads on SageMaker HyperPod. Without proper shared storage, your training jobs will be severely bottlenecked by data I/O operations.

### Performance Impact

- **Data Loading Bottlenecks**: Without shared storage, each compute node must independently load training data, creating massive I/O overhead
- **Checkpoint Synchronization**: Model checkpoints and intermediate results need fast, consistent access across all nodes
- **Memory Efficiency**: Shared file systems enable efficient data caching and reduce memory pressure on individual nodes
- **Scaling Limitations**: Local storage approaches fail to scale beyond single-node training

### FSx for Lustre Benefits

Amazon FSx for Lustre is specifically designed for high-performance computing workloads and provides:

- **High Throughput**: Up to hundreds of GB/s of aggregate throughput
- **Low Latency**: Sub-millisecond latencies for small file operations  
- **POSIX Compliance**: Standard file system semantics that work with existing ML frameworks
- **S3 Integration**: Seamless data repository associations with Amazon S3
- **Elastic Scaling**: Storage capacity that can grow with your workload demands



## Setup Options

### Option 1: Auto-Provisioned (Console Quick Setup)

When you create a HyperPod cluster through the AWS Console using the **Quick Setup** path, FSx for Lustre is automatically provisioned and configured for you.

#### What Gets Created Automatically

The console automatically provisions:
- **FSx for Lustre file system** with optimal performance settings
- **Proper networking configuration** in the same VPC and subnet as your cluster
- **Security group rules** allowing NFS traffic between cluster nodes and FSx
- **Mount configuration** that automatically mounts FSx at `/fsx` on all cluster nodes
- **IAM permissions** for the cluster to access the file system

#### Verification Steps

After your cluster reaches `InService` status, verify FSx is properly mounted:

1. **SSH into your cluster** (see [SSH setup guide](./ssh-into-hyperpod.mdx))

2. **Check mounted file systems**:
   ```bash
   df -h | grep fsx
   ```
   
   You should see output similar to:
   ```
   10.1.71.197@tcp:/oyuutbev  1.2T  5.5G  1.2T   1% /fsx
   ```

3. **Test write access**:
   ```bash
   echo "Hello FSx" > /fsx/test.txt
   cat /fsx/test.txt
   rm /fsx/test.txt
   ```

4. **Verify performance** (optional):
   ```bash
   # Test write performance
   dd if=/dev/zero of=/fsx/testfile bs=1M count=1000
   
   # Test read performance  
   dd if=/fsx/testfile of=/dev/null bs=1M
   
   # Clean up
   rm /fsx/testfile
   ```

### Option 2: Manual Setup (CLI/SDK Users)

If you're creating your HyperPod cluster via CLI or SDK, or want more control over your FSx configuration, you can manually create and attach an FSx file system.

#### When to Use Manual Setup

- **Custom performance requirements**: Need specific throughput or storage configurations
- **Existing infrastructure**: Want to integrate with existing FSx file systems
- **Advanced networking**: Require custom VPC or subnet configurations
- **Cost optimization**: Need precise control over storage capacity and performance tiers

#### Step-by-Step FSx Creation

1. **Create the FSx file system**:
   ```bash
   # Set your configuration variables
   SUBNET_ID="subnet-xxxxxxxxx"  # Same subnet as your HyperPod cluster
   SECURITY_GROUP_ID="sg-xxxxxxxxx"  # Security group allowing NFS traffic
   
   # Create FSx file system
   aws fsx create-file-system \
     --file-system-type LUSTRE \
     --storage-capacity 1200 \
     --subnet-ids $SUBNET_ID \
     --security-group-ids $SECURITY_GROUP_ID \
     --lustre-configuration DeploymentType=PERSISTENT_2,PerUnitStorageThroughput=250,DataCompressionType=LZ4
   ```

2. **Wait for file system creation**:
   ```bash
   # Get the file system ID from the previous command output
   FSX_ID="fs-xxxxxxxxx"
   
   # Wait for AVAILABLE status
   aws fsx describe-file-systems --file-system-ids $FSX_ID --query 'FileSystems[0].Lifecycle'
   ```

3. **Get mount information**:
   ```bash
   # Get DNS name and mount name
   aws fsx describe-file-systems --file-system-ids $FSX_ID \
     --query 'FileSystems[0].[DNSName,LustreConfiguration.MountName]' --output table
   ```

#### Integration with HyperPod Cluster

To use your manually created FSx with HyperPod, you'll need to configure the cluster lifecycle scripts:

1. **Update lifecycle scripts** to mount your FSx file system
2. **Specify FSx parameters** in your cluster configuration
3. **Ensure proper IAM permissions** for FSx access

For detailed lifecycle script configuration, see the [HyperPod cluster setup documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-lifecycle-best-practices-slurm-slurm-setup-with-fsx.html).

### Option 3: Bring Your Own FSx

If you have an existing FSx for Lustre file system, you can integrate it with your HyperPod cluster.

#### Requirements and Considerations

**Network Requirements:**
- FSx file system must be in the **same VPC** as your HyperPod cluster
- FSx file system must be in the **same Availability Zone** as your cluster nodes
- Security groups must allow NFS traffic (port 988) between cluster and FSx

**Performance Considerations:**
- Ensure FSx performance tier matches your workload requirements
- Consider data locality - accessing FSx from different AZs reduces performance
- Verify sufficient throughput capacity for your cluster size

#### Integration Steps

1. **Verify network compatibility**:
   ```bash
   # Check your cluster's subnet and AZ
   aws sagemaker describe-cluster --cluster-name <your-cluster-name> \
     --query 'VpcConfig.Subnets'
   
   # Check your FSx file system's subnet and AZ
   aws fsx describe-file-systems --file-system-ids <your-fsx-id> \
     --query 'FileSystems[0].SubnetIds'
   ```

2. **Update security groups** if needed:
   ```bash
   # Allow NFS traffic from cluster security group to FSx
   aws ec2 authorize-security-group-ingress \
     --group-id <fsx-security-group-id> \
     --protocol tcp \
     --port 988 \
     --source-group <cluster-security-group-id>
   ```

3. **Configure cluster lifecycle scripts** to mount the existing FSx file system using [this documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-lifecycle-best-practices-slurm-slurm-setup-with-fsx.html).

## Using FSx in Slurm Jobs

### Mount Points and Paths

By default, FSx for Lustre is mounted at `/fsx` on all cluster nodes. This creates a shared namespace accessible from:
- **Head node**: `/fsx`
- **Compute nodes**: `/fsx` 
- **All Slurm jobs**: `/fsx`

### Best Practices for Data Access

#### Data Organization

```bash
# Recommended FSx directory structure
/fsx/
├── datasets/           # Training datasets
├── checkpoints/        # Model checkpoints  
├── outputs/           # Training outputs and logs
├── code/              # Shared training scripts
└── scratch/           # Temporary files
```

#### Performance Optimization

1. **Use appropriate I/O patterns**:
   ```bash
   # Good: Sequential reads of large files
   # Bad: Random access to many small files
   ```

2. **Leverage data caching**:
   ```bash
   # Pre-load datasets to FSx before training
   aws s3 sync s3://your-bucket/dataset /fsx/datasets/
   ```

3. **Optimize checkpoint frequency**:
   ```bash
   # Balance checkpoint frequency with I/O overhead
   # Save checkpoints to FSx, not local storage
   ```

#### Data Management

1. **Link FSx to S3** for data persistence:
   ```bash
   # Create data repository association
   aws fsx create-data-repository-association \
     --file-system-id $FSX_ID \
     --file-system-path /datasets \
     --data-repository-path s3://your-bucket/datasets
   ```

2. **Use FSx data lifecycle policies**:
   ```bash
   # Automatically sync data between FSx and S3
   # Configure import/export policies based on access patterns
   ```

## Troubleshooting

### Common Issues

**FSx not mounted**:
```bash
# Check if FSx service is running
systemctl status lustre-client

# Manually mount if needed (replace with your FSx details)
sudo mount -t lustre fs-xxxxx.fsx.region.amazonaws.com@tcp:/mountname /fsx
```

**Permission denied errors**:
```bash
# Check FSx permissions
ls -la /fsx/

# Fix ownership if needed
sudo chown -R ubuntu:ubuntu /fsx/
```

**Poor performance**:
```bash
# Check FSx throughput utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/FSx \
  --metric-name TotalIOTime \
  --dimensions Name=FileSystemId,Value=$FSX_ID
```

### Performance Monitoring

Monitor FSx performance through CloudWatch metrics:
- **TotalIOTime**: I/O utilization
- **DataReadBytes/DataWriteBytes**: Throughput metrics  
- **MetadataOperations**: File system metadata operations

## Next Steps

Once your shared file system is set up:
1. **Verify performance** with your specific workloads
2. **Configure data repository associations** with S3 if needed
3. **Set up monitoring and alerting** for FSx metrics
4. **Review the training blueprints** that leverage FSx for distributed training

For advanced FSx configuration and management, see:
- [Link FSx to S3](/docs/common/tips/link-fsx-to-S3)
- [Mount additional FSx filesystems](/docs/common/tips/mount-additional-fsx)