---
title: Set up your shared file system
sidebar_position: 6
---

# Shared File System Setup for SageMaker HyperPod (EKS)

## Why Shared File Systems Matter

A high-performance shared file system is **critical** for achieving optimal performance in distributed machine learning workloads on SageMaker HyperPod. Without proper shared storage, your training jobs will be severely bottlenecked by data I/O operations.

### Performance Impact

- **Data Loading Bottlenecks**: Without shared storage, each pod must independently load training data, creating massive I/O overhead
- **Checkpoint Synchronization**: Model checkpoints and intermediate results need fast, consistent access across all pods
- **Memory Efficiency**: Shared file systems enable efficient data caching and reduce memory pressure on individual pods
- **Scaling Limitations**: Local storage approaches fail to scale beyond single-pod training

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
- **FSx CSI driver installation** for Kubernetes integration
- **Storage classes and persistent volumes** ready for use in pods
- **IAM permissions** for the cluster to access the file system

#### Verification Steps

After your cluster reaches `InService` status, verify FSx is properly configured:

1. **Check FSx CSI driver installation**:
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-fsx-csi-driver
   ```

2. **Verify storage class**:
   ```bash
   kubectl get storageclass | grep fsx
   ```

3. **Test with a sample pod**:
   ```bash
   cat <<EOF | kubectl apply -f -
   apiVersion: v1
   kind: Pod
   metadata:
     name: fsx-test
   spec:
     containers:
     - name: test
       image: ubuntu
       command: ["/bin/sh", "-c", "echo 'Hello FSx' > /data/test.txt && cat /data/test.txt && sleep 3600"]
       volumeMounts:
       - name: fsx-storage
         mountPath: /data
     volumes:
     - name: fsx-storage
       persistentVolumeClaim:
         claimName: fsx-claim
   EOF
   ```

### Option 2: Manual Setup (Dynamic Provisioning)

If you're creating your HyperPod cluster via CLI/SDK or want more control over your FSx configuration, you can manually set up dynamic provisioning.

#### When to Use Manual Setup

- **Custom performance requirements**: Need specific throughput or storage configurations
- **Advanced networking**: Require custom VPC or subnet configurations
- **Cost optimization**: Need precise control over storage capacity and performance tiers
- **Integration requirements**: Want to integrate with existing Kubernetes storage workflows

#### Install the Amazon FSx for Lustre CSI Driver

The [Amazon FSx for Lustre Container Storage Interface (CSI) driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver) uses [IAM roles for service accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) to authenticate AWS API calls.


:::info Performance Best Practice
Make sure that your file system is located in the same Region and Availability Zone as your compute nodes. Accessing a file system in a different Region or Availability Zone will result in reduced I/O performance and increased network costs.
:::

#### Step-by-Step Setup

1. **Create an IAM OIDC identity provider** for your cluster:
   ```bash 
   eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve
   ```

2. **Create a service account** with an IAM role for the FSx CSI driver:
   ```bash 
   eksctl create iamserviceaccount \
     --name fsx-csi-controller-sa \
     --namespace kube-system \
     --cluster $EKS_CLUSTER_NAME \
     --attach-policy-arn arn:aws:iam::aws:policy/AmazonFSxFullAccess \
     --approve \
     --role-name FSXLCSI-${EKS_CLUSTER_NAME}-${AWS_REGION} \
     --region $AWS_REGION
   ```

3. **Verify the service account** annotation:
   ```bash
   kubectl get sa fsx-csi-controller-sa -n kube-system -oyaml 
   ```

4. **Deploy the FSx CSI driver** using Helm:
   ```bash 
   helm repo add aws-fsx-csi-driver https://kubernetes-sigs.github.io/aws-fsx-csi-driver
   helm repo update
   
   helm upgrade --install aws-fsx-csi-driver aws-fsx-csi-driver/aws-fsx-csi-driver \
     --namespace kube-system \
     --set controller.serviceAccount.create=false
   ```

5. **Verify CSI driver installation**:
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-fsx-csi-driver
```
---
The [Amazon FSx for Lustre CSI driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver) presents you with two options for provisioning a file system: 

#### Create Dynamic Provisioning Resources

Dynamic provisioning leverages Persistent Volume Claims (PVCs) in Kubernetes. You define a PVC with desired storage specifications, and the CSI Driver automatically provisions the FSx file system based on the PVC request.

1. **Create a storage class** that leverages the `fsx.csi.aws.com` provisioner: 

```bash 
cat <<EOF> storageclass.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: fsx-sc
provisioner: fsx.csi.aws.com
parameters:
  subnetId: $PRIVATE_SUBNET_ID
  securityGroupIds: $SECURITY_GROUP_ID
  deploymentType: PERSISTENT_2
  automaticBackupRetentionDays: "0"
  copyTagsToBackups: "true"
  perUnitStorageThroughput: "250"
  dataCompressionType: "LZ4"
  fileSystemTypeVersion: "2.15"
mountOptions:
  - flock
EOF
```
   ```bash 
   kubectl apply -f storageclass.yaml
   ```
<details>
<summary>Parameter Explanation</summary>

- **privateSubnetId** - The subnet ID that the FSx for Lustre filesystem should be created inside. Using the `$PRIVATE_SUBNET_ID` environment variable, we are referencing the same private subnet that was used for HyperPod cluster creation. 

- **securityGroupIds** - A list of security group IDs that should be attached to the filesystem. Using the `$SECURITY_GROUP` environment variable, we are referencing the same security group that was use for HyperPod cluster creation.

- **deploymentType**: `PERSISTENT_2` is the latest generation of Persistent deployment type, and is best-suited for use cases that require longer-term storage, and have latency-sensitive workloads that require the highest levels of IOPS and throughput. For more information see [Deployment options for FSx for Lustre file systems](https://docs.aws.amazon.com/fsx/latest/LustreGuide/using-fsx-lustre.html). 
- **automaticBackupRetentionDays**: The number of days to retain automatic backups. Setting this value to 0 disables the creation of automatic backups. If you set this parameter to a non-zero value, you can also specify the preferred time to take daily backups using the dailyAutomaticBackupStartTime parameter. 
- **copyTagsToBackups**: If this value is true, all tags for the file system are copied to all automatic and user-initiated backups. 
- **perUnitStorageThroughput**: For `PERSISTENT_2` deployments, you can specify the storage throughput in MBps per TiB of storage capacity. 
- **dataCompressionType**: FSx for Lustre supports data compression via the LZ4 algorithm, which is optimized to deliver high levels of compression without adversely impacting file system performance. For more information see [Lustre data compression](https://docs.aws.amazon.com/fsx/latest/LustreGuide/data-compression.html).
- **fileSystemTypeVersion**: This sets the Lustre version for the FSx for Lustre file system that will be created. 
- **mountOptions**: A list of mount options for the file system. The `flock` option mounts your file system with file lock enabled. 

You can find more information about storage class parameters in the [aws-fsx-csi-driver GitHub repository](https://github.com/kubernetes-sigs/aws-fsx-csi-driver/tree/master/examples/kubernetes/dynamic_provisioning#dynamic-provisioning-example)

</details>


2. **Verify the storage class** was created:
   ```bash 
   kubectl get sc fsx-sc -oyaml
   ```

3. **Create a persistent volume claim (PVC)**:

```bash 
cat <<EOF> pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fsx-claim
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: fsx-sc
  resources:
    requests:
      storage: 1200Gi
EOF
   ```

   :::info
   PVCs are namespaced Kubernetes resources, so be sure to change the namespace as needed before creation.
   :::

4. **Apply the PVC**:
   ```bash 
   kubectl apply -f pvc.yaml
   ```

5. **Monitor PVC status**:
   ```bash 
   kubectl get pvc fsx-claim -n default -w
   ```
   
   Wait for the status to change from `Pending` to `Bound` (~10 minutes while FSx is provisioned).

6. **Retrieve the FSx volume ID** (optional):
   ```bash
   kubectl get pv $(kubectl get pvc fsx-claim -n default -ojson | jq -r .spec.volumeName) -ojson | jq -r .spec.csi.volumeHandle
   ```

### Option 3: Bring Your Own FSx (Static Provisioning)

If you have an existing FSx for Lustre file system, you can integrate it with your HyperPod cluster using static provisioning.

#### Requirements and Considerations

**Network Requirements:**
- FSx file system must be in the **same VPC** as your HyperPod cluster
- FSx file system must be in the **same Availability Zone** as your cluster nodes  
- Security groups must allow NFS traffic between cluster and FSx

**Performance Considerations:**
- Ensure FSx performance tier matches your workload requirements
- Consider data locality - accessing FSx from different AZs reduces performance
- Verify sufficient throughput capacity for your cluster size

#### Integration Steps 

> **Note:**
> Before using an existing file system with the CSI driver on your EKS HyperPod cluster, please ensure that your FSx file system is in the same subnet (and thus, same Availability Zone) as your HyperPod cluster nodes.
>
> You can check the subnet of your HyperPod nodes by checking the `$PRIVATE_SUBNET_ID` environment variable set as part of this cluster creation process.
>
> To check the subnet ID of your existing file system, run
> ```bash
> # Replace fs-xxx with your file system id
> aws fsx describe-file-systems --file-system-id fs-xxx --query 'FileSystems[0].SubnetIds[]' --output text
> ```

> **Note:**
> The following YAMLs require variables that are not in our env_vars. To retrieve the variables, you can find them in your AWS console in `FSx for Lustre` page, or you can run these commands:
>
> FSx For Lustre ID:
> ``` bash
> aws fsx describe-file-systems --region $AWS_REGION | jq -r '.FileSystems[0].FileSystemId'
> ```
>
> FSx DNS Name:
> ``` bash
> aws fsx describe-file-systems --region $AWS_REGION --file-system-id <fs-xxxx> --query 'FileSystems[0].DNSName' --output text
> ```
>
> FSx Mount Name:
> ``` bash
> aws fsx describe-file-systems --region $AWS_REGION --file-system-id <fs-xxxx> --query 'FileSystems[0].LustreConfiguration.MountName' --output text
> ```

1. **Verify network compatibility**:
   ```bash
   # Check your cluster's subnet and AZ
   aws eks describe-cluster --name $EKS_CLUSTER_NAME --query 'cluster.resourcesVpcConfig.subnetIds'
   
   # Check your FSx file system's subnet and AZ  
   aws fsx describe-file-systems --file-system-ids <your-fsx-id> --query 'FileSystems[0].SubnetIds'
   ```

2. **Get FSx file system details**:
   ```bash
   # Get FSx ID, DNS name, and mount name
   FSX_ID="fs-xxxxx"  # Replace with your FSx ID
   
   aws fsx describe-file-systems --file-system-ids $FSX_ID \
     --query 'FileSystems[0].[FileSystemId,DNSName,LustreConfiguration.MountName]' --output table
   ```

3. **Create a StorageClass** for your existing FSx:
   ```bash
   cat <<EOF> storageclass.yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: fsx-sc
   provisioner: fsx.csi.aws.com
   parameters:
     fileSystemId: $FSX_ID
     subnetId: $PRIVATE_SUBNET_ID
     securityGroupIds: $SECURITY_GROUP_ID
   EOF
   
   kubectl apply -f storageclass.yaml
   ```

4. **Create a PersistentVolume (PV)**:
   ```bash
   cat <<EOF> pv.yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: fsx-pv
   spec:
     capacity:
       storage: 1200Gi  # Adjust based on your FSx volume size
     volumeMode: Filesystem
     accessModes:
       - ReadWriteMany
     persistentVolumeReclaimPolicy: Retain
     storageClassName: fsx-sc
     csi:
       driver: fsx.csi.aws.com
       volumeHandle: $FSX_ID
       volumeAttributes:
         dnsname: <fsx-dns-name>  # Replace with your FSx DNS name
         mountname: <fsx-mount-name>  # Replace with your FSx mount name
   EOF
   
   kubectl apply -f pv.yaml
   ```

5. **Create a PersistentVolumeClaim (PVC)**:
   ```bash
   cat <<EOF> pvc.yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: fsx-claim
   spec:
     accessModes:
       - ReadWriteMany
     storageClassName: fsx-sc
     resources:
       requests:
         storage: 1200Gi  # Should match the PV size
   EOF
   
   kubectl apply -f pvc.yaml
   ```


## Using FSx in EKS Jobs

### Mount Points and Paths

FSx for Lustre is accessed through Kubernetes Persistent Volume Claims (PVCs) and can be mounted at any path within your pods. The common pattern is to mount FSx volumes at `/data`, `/fsx`, or application-specific paths.


### Best Practices for Data Access

#### Data Organization

Organize your FSx data structure for optimal access patterns:

```bash
# Recommended FSx directory structure when mounted in pods
/data/
├── datasets/           # Training datasets
├── checkpoints/        # Model checkpoints  
├── outputs/           # Training outputs and logs
├── code/              # Shared training scripts
└── scratch/           # Temporary files
```

#### Performance Optimization

1. **Use ReadWriteMany access mode** for shared access across multiple pods:
   ```yaml
   accessModes:
     - ReadWriteMany
   ```

2. **Leverage data caching** by pre-loading datasets:
   ```bash
   # Pre-load datasets to FSx before training
   kubectl run data-loader --image=amazon/aws-cli \
     --command -- aws s3 sync s3://your-bucket/dataset /data/datasets
   ```

3. **Optimize checkpoint frequency** to balance performance with fault tolerance:
   ```python
   # Save checkpoints to FSx, not local storage
   torch.save(model.state_dict(), '/data/checkpoints/model_epoch_{}.pth'.format(epoch))
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

2. **Use init containers** for data preparation:
   ```yaml
   initContainers:
   - name: data-prep
     image: amazon/aws-cli
     command: ['aws', 's3', 'sync', 's3://bucket/data', '/data']
     volumeMounts:
     - name: fsx-storage
       mountPath: /data
   ```

## Troubleshooting

### Common Issues

**PVC stuck in Pending state**:
```bash
# Check PVC events
kubectl describe pvc fsx-claim

# Check storage class
kubectl get storageclass fsx-sc -o yaml

# Verify CSI driver pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-fsx-csi-driver
```

**Pod mount failures**:
```bash
# Check pod events
kubectl describe pod <pod-name>

# Verify PVC is bound
kubectl get pvc fsx-claim

# Check FSx file system status
aws fsx describe-file-systems --file-system-ids <fsx-id>
```

**Performance issues**:
```bash
# Monitor FSx metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/FSx \
  --metric-name TotalIOTime \
  --dimensions Name=FileSystemId,Value=$FSX_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Performance Monitoring

Monitor FSx performance through CloudWatch metrics:
- **TotalIOTime**: I/O utilization percentage
- **DataReadBytes/DataWriteBytes**: Throughput metrics
- **MetadataOperations**: File system metadata operations

## Next Steps

Once your shared file system is set up:
1. **Test with sample workloads** to verify performance
2. **Configure data repository associations** with S3 if needed
3. **Set up monitoring and alerting** for FSx metrics
4. **Review the training blueprints** that leverage FSx for distributed training

For advanced FSx configuration and management, see:
- [Link FSx to S3](../../08-Tips/Common/12-link-fsx-to-S3.md)
- [Mount additional FSx filesystems](../../08-Tips/Common/13-mount-additional-fsx.md)

