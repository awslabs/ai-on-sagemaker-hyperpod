---
title: Set up your shared file system
sidebar_position: 5
---

#### Install the Amazon FSx for Lustre CSI Driver

The [Amazon FSx for Lustre Container Storage Interface (CSI) driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver) uses [IAM roles for service accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) to authenticate AWS API calls. To use IRSA, an [IAM OpenID Connect (OIDC) provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) needs to be associated with the OIDC issuer URL that comes provisioned your EKS cluster. 


:::alert{header="Performance best practice:"}
Make sure that your file system is located in the same Region and Availability Zone as your compute nodes. Accessing a file system in a different Region or Availability Zone will result in reduced I/O performance and increased network costs.
:::


Create an IAM OIDC identity provider for your cluster with the following command:
```bash 
eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve
```

Create a service account with an IAM role mapped to it for use with the FSx for Lustre CSI driver:
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
Verify proper annotation of the service account with the IAM role ARN:
```bash
kubectl get sa fsx-csi-controller-sa -n kube-system -oyaml 
```

```
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::012345678910:role/FSXLCSI-sagemaker-hyperpod-eks-cluster-us-west-2
  creationTimestamp: "2025-06-05T15:17:19Z"
  labels:
    app.kubernetes.io/managed-by: eksctl
  name: fsx-csi-controller-sa
  namespace: kube-system
  resourceVersion: "43455"
  uid: 514c9567-7021-469f-b700-6f55e3e9e864
```
Deploy the FSx for Lustre CSI driver using Helm: 

```bash 
helm repo add aws-fsx-csi-driver https://kubernetes-sigs.github.io/aws-fsx-csi-driver

helm repo update

helm upgrade --install aws-fsx-csi-driver aws-fsx-csi-driver/aws-fsx-csi-driver\
  --namespace kube-system \
  --set controller.serviceAccount.create=false
```

Verify instillation of the FSx for Lustre CSI driver:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-fsx-csi-driver
```
---
The [Amazon FSx for Lustre CSI driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver) presents you with two options for provisioning a file system: 

**Dynamic Provisioning**: This option leverages Persistent Volume Claims (PVCs) in Kubernetes. You define a PVC with desired storage specifications. The CSI Driver automatically provisions the FSx file system for you based on the PVC request. This allows for easier scaling and eliminates the need to manually create file systems.  


**Static Provisioning**: In this method, you manually create the FSx file system before using the CSI Driver. You'll need to configure details like subnet ID and security groups for the file system. Then, you can use the Driver to mount this pre-created file system within your container as a volume.

#### Dynamic Provisioning

To dynamically provision an FSx for Lustre file system, start by creating a storage class that leverages the `fsx.csi.aws.com` provisioner: 

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
::::expand{header="Parameter Explaination" defaultExpanded=false}

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
::::

Verify the `fsx-sc` storage class was created:

```bash 
kubectl get sc fsx-sc -oyaml
```

Next, create a persistent volume claim (PVC) that uses the `fsx-claim` storage claim:

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
::::alert{header="Note"}
PVCs are namespaced Kubernetes resources, so be sure to change the namespace as needed before creation. 
::::
```bash 
kubectl apply -f pvc.yaml
```

This PVC will kick off the dynamic provisioning of an FSx for Lustre file system based on the specifications provided in the storage class. 

View the status of the PVC:
```bash 
kubectl describe pvc fsx-claim 
```
Check to see if the PVC is in a `Pending` or `Bound` state: 
```bash 
 kubectl get pvc fsx-claim  -n default  -ojson \
 | jq -r .status.phase
```
Ensure that the status is set to `Bound` before deploying any pods that reference the persistent volume claim. The status may remain in a `Pending` state ( ~10 mins) while the file system is being provisioned. 

Retrieve the associated FSx for Lustre volume ID:
```bash
kubectl get pv $(kubectl get pvc fsx-claim  -n default -ojson \
 | jq -r .spec.volumeName) -ojson \
 | jq -r .spec.csi.volumeHandle
```

#### Static Provisioning (Optional)

Alternatively, if you prefer to deploy a standalone FSx for Lustre file system using AWS CloudFormation, click the button below: 

:button[Deploy the FSx for Lustre File System Stack]{variant="primary" href="https://console.aws.amazon.com/cloudformation/home?#/stacks/quickcreate?templateURL=https://ws-assets-prod-iad-r-pdx-f3b3f9f1a7d6a3d0.s3.us-west-2.amazonaws.com/2433d39e-ccfe-4c00-9d3d-9917b729258e/fsx-lustre-stack.yaml&stackName=fsx-lustre-stack" external="true"}

For the Security Group ID and Subnet ID in the network options, use the IDs available from the environment variables - `$SECURITY_GROUP`, and `$PRIVATE_SUBNET_ID`.


#### To use an existing FSxL File system with the CSI driver follow the below steps 

:::::alert{header="Note:"}
Before using an existing file system with the CSI driver on your EKS HyperPod cluster, please ensure that your FSx file system is in the same subnet (and thus, same Availability Zone) as your HyperPod cluster nodes.

You can check the subnet of your HyperPod nodes by checking the `$PRIVATE_SUBNET_ID` environment variable set as part of this cluster creation process.

To check the subnet ID of your existing file system, run
```bash
# Replace fs-xxx with your file system id
aws fsx describe-file-systems --file-system-id fs-xxx --query 'FileSystems[0].SubnetIds[]' --output text
```
:::::

:::::alert{header="Note:"}
The following YAMLs require variables that are not in our env_vars. To retrieve the variables, you can find them in your AWS console in `FSx for Lustre` page, or you can run these commands:

FSx For Lustre ID:
``` bash
aws fsx describe-file-systems --region $AWS_REGION | jq -r '.FileSystems[0].FileSystemId'
```

FSx DNS Name:
``` bash
aws fsx describe-file-systems --region $AWS_REGION --file-system-id <fs-xxxx> --query 'FileSystems[0].DNSName' --output text
```

FSx Mount Name:
``` bash
aws fsx describe-file-systems --region $AWS_REGION --file-system-id <fs-xxxx> --query 'FileSystems[0].LustreConfiguration.MountName' --output text
```

:::::

1. Create a StorageClass that references your existing FSx file system. Replace the fileSystemId, subnetId and securityGroupIDs in the yaml file accordingly.

```bash
cat <<EOF> storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fsx-sc
provisioner: fsx.csi.aws.com
parameters:
  fileSystemId: fs-xxxx # Replace with your FSx file system ID
  subnetId: subnet-xxxx  # Replace with your subnet ID
  securityGroupIds: $SECURITY_GROUP_ID  # Replace with your security group ID
EOF

kubectl apply -f storageclass.yaml
```

2. Create a PersistentVolume (PV) that references your existing FSx volume. Replace the storage and volumeHandle parameters accordingly.

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
    volumeHandle: fs-xxxxx  # Replace with your FSx file system ID
    volumeAttributes:
      dnsname: fs-xxxxx.fsx.region.amazonaws.com  # Replace with your FSx file system DNS name
      mountname: abc123  # Replace with your FSx file system mountname
EOF

kubectl apply -f pv.yaml
```

3. Create a PersistentVolumeClaim (PVC) to use the existing FSx volume. Verify if the storage parameter value matches the PV size created above.

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


#### Mount the volume to container 

```bash
cat <<EOF> pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fsx-app
spec:
  containers:
  - name: app
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(date -u) >> /data/out.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: fsx-claim
EOF

kubectl apply -f pod.yaml

