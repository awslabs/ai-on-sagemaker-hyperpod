---
title: Set up an Amazon S3 mountpoint
sidebar_position: 8
---

With the Mountpoint for Amazon S3 Container Storage Interface (CSI) driver, your Kubernetes applications can access Amazon S3 objects through a file system interface, achieving high aggregate throughput without changing any application code. Built on Mountpoint for Amazon S3, the CSI driver presents an Amazon S3 bucket as a volume that can be accessed by containers in Amazon EKS and self-managed Kubernetes clusters. This section shows you how to deploy the Mountpoint for Amazon S3 CSI driver to your Amazon EKS cluster.

:::alert{header="Performance best practice:"}
Make sure that your S3 bucket is located in the same Region (and Availability Zone for S3 Express One Zone) as your compute nodes. Accessing S3 bucket in a different Region or Availability Zone will result in reduced I/O performance and increased network costs.
:::

#### Considerations

1. The Mountpoint for Amazon S3 CSI driver supports only static provisioning. Dynamic provisioning, or creation of new buckets, isn't supported.


#### Setup Mountpoint for Amazon S3


1. Create an IAM OIDC identity provider for your cluster with the following command:
```bash 
eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve
```

2. Create an IAM policy

::alert[Replace DOC-EXAMPLE-BUCKET1 with your own Amazon S3 bucket name.]{header="Important" type="error"}


```bash
cat <<EOF> s3accesspolicy.json
{
   "Version": "2012-10-17",
   "Statement": [
        {
            "Sid": "MountpointFullBucketAccess",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::DOC-EXAMPLE-BUCKET1"
            ]
        },
        {
            "Sid": "MountpointFullObjectAccess",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::DOC-EXAMPLE-BUCKET1/*"
            ]
        }
   ]
}
EOF

aws iam create-policy \
    --policy-name S3MountpointAccessPolicy \
    --policy-document file://s3accesspolicy.json
```

3. Create an IAM role

The Mountpoint for Amazon S3 CSI driver requires Amazon S3 permissions to interact with your file system. This section shows how to create an IAM role to delegate these permissions. To create this role we will use eksctl. 


```bash
ROLE_NAME=SM_HP_S3_CSI_ROLE
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`S3MountpointAccessPolicy`]' | jq '.[0].Arn' |  tr -d '"')

eksctl create iamserviceaccount \
    --name s3-csi-driver-sa \
    --namespace kube-system \
    --cluster $EKS_CLUSTER_NAME \
    --attach-policy-arn $POLICY_ARN \
    --approve \
    --role-name $ROLE_NAME \
    --region $AWS_REGION \
    --role-only
```

4. Install the Mountpoint for Amazon S3 CSI driver

```bash
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME  --query 'Role.Arn' --output text)

eksctl create addon --name aws-mountpoint-s3-csi-driver --cluster $EKS_CLUSTER_NAME --service-account-role-arn $ROLE_ARN --force
```


#### Configure Mountpoint for Amazon S3

Create a persistent volume. Replace the bucket name with the actual bucket.

```bash
cat <<EOF> pv_s3.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1200Gi # ignored, required
  accessModes:
    - ReadWriteMany # supported options: ReadWriteMany / ReadOnlyMany
  mountOptions:
    - allow-delete
    - region $AWS_REGION
    - prefix /
  csi:
    driver: s3.csi.aws.com # required
    volumeHandle: s3-csi-driver-volume
    volumeAttributes:
      bucketName: DOC-EXAMPLE-BUCKET1
EOF

kubectl apply -f pv_s3.yaml
```

Create a persistent volume claim

```bash
cat <<EOF> pvc_s3.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-claim
spec:
  accessModes:
    - ReadWriteMany # supported options: ReadWriteMany / ReadOnlyMany
  storageClassName: "" # required for static provisioning
  resources:
    requests:
      storage: 1200Gi # ignored, required
  volumeName: s3-pv
EOF

kubectl apply -f pvc_s3.yaml
```

#### Mount s3 bucket to Pod

Below example shows how to mount the s3 bucket as a volume to container. 

```bash
apiVersion: v1
kind: Pod
metadata:
  name: s3-app
spec:
  containers:
    - name: app
      image: ubuntu
      command: ["/bin/sh"]
      args: ["-c", "echo 'Hello from the container!' >> /data/$(date -u).txt; tail -f /dev/null"]
      volumeMounts:
        - name: persistent-storage
          mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: s3-claim
```