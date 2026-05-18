---
title: IAM, OIDC & Storage Drivers
sidebar_position: 4
---

# IAM, OIDC & Storage Drivers

This section configures the IAM OIDC provider, creates the Kubecost IAM policy and IRSA service account; and EBS CSI Driver required for the deployment.

## Configure IAM OIDC Provider

```bash
export OIDC_ISSUER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION \
    --query "cluster.identity.oidc.issuer" --output text)
export OIDC_ID=$(echo $OIDC_ISSUER | sed 's|https://||')

if aws iam list-open-id-connect-providers | grep -q $OIDC_ID; then
    echo "✅ OIDC provider exists"
else
    eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $AWS_REGION --approve
    echo "✅ OIDC provider created"
fi
```

## Create IAM Policies & Service Account

### Create IAM Policy

```bash
cat > kubecost-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AthenaAccess",
            "Effect": "Allow",
            "Action": [
                "athena:GetDatabase", "athena:GetDataCatalog", "athena:GetTableMetadata",
                "athena:GetQueryExecution", "athena:GetQueryResults", "athena:GetWorkGroup",
                "athena:StartQueryExecution", "athena:StopQueryExecution",
                "athena:ListQueryExecutions", "athena:ListDatabases",
                "athena:ListTableMetadata", "athena:ListWorkGroups"
            ],
            "Resource": ["*"]
        },
        {
            "Sid": "GlueCatalog",
            "Effect": "Allow",
            "Action": [
                "glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables",
                "glue:GetPartition", "glue:GetPartitions", "glue:BatchGetPartition"
            ],
            "Resource": [
                "arn:aws:glue:*:*:catalog",
                "arn:aws:glue:*:*:database/${ATHENA_DATABASE}",
                "arn:aws:glue:*:*:table/${ATHENA_DATABASE}/*"
            ]
        },
        {
            "Sid": "S3AthenaResults",
            "Effect": "Allow",
            "Action": ["s3:GetBucketLocation","s3:GetObject","s3:ListBucket","s3:PutObject",
                        "s3:ListBucketMultipartUploads","s3:ListMultipartUploadParts","s3:AbortMultipartUpload"],
            "Resource": ["arn:aws:s3:::${ATHENA_RESULTS_BUCKET}","arn:aws:s3:::${ATHENA_RESULTS_BUCKET}/*"]
        },
        {
            "Sid": "S3CURBucket",
            "Effect": "Allow",
            "Action": ["s3:Get*","s3:List*"],
            "Resource": ["arn:aws:s3:::${CUR_BUCKET_NAME}","arn:aws:s3:::${CUR_BUCKET_NAME}/*"]
        },
        {
            "Sid": "CostExplorer",
            "Effect": "Allow",
            "Action": ["ce:GetCostAndUsage","ce:GetCostForecast","ce:GetReservationCoverage",
                        "ce:GetReservationUtilization","ce:GetSavingsPlansCoverage",
                        "ce:GetSavingsPlansUtilization","ce:GetTags"],
            "Resource": "*"
        },
        {
            "Sid": "EC2Describe",
            "Effect": "Allow",
            "Action": ["ec2:DescribeInstances","ec2:DescribeVolumes","ec2:DescribeRegions"],
            "Resource": "*"
        },
        {
            "Sid": "PricingAPI",
            "Effect": "Allow",
            "Action": ["pricing:GetProducts","pricing:DescribeServices","pricing:GetAttributeValues"],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy --policy-name KubecostAthenaCURPolicy \
    --policy-document file://kubecost-policy.json 2>/dev/null || echo "Policy already exists"

export KUBECOST_POLICY_ARN=$(aws iam list-policies \
    --query 'Policies[?PolicyName==`KubecostAthenaCURPolicy`].Arn' --output text)
echo "Policy: $KUBECOST_POLICY_ARN"
```

:::warning Production hardening
The Athena, CostExplorer, EC2Describe, and PricingAPI statements use `Resource: "*"`. These are read-only actions so the blast radius is limited, but for production use consider scoping Athena resources to your specific workgroup ARN:
```json
"Resource": ["arn:aws:athena:${CUR_REGION}:${AWS_ACCOUNT_ID}:workgroup/${ATHENA_WORKGROUP}"]
```
:::

### Create Service Account with IRSA

```bash
eksctl create iamserviceaccount \
    --name kubecost-serviceaccount \
    --namespace kubecost \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION \
    --attach-policy-arn $KUBECOST_POLICY_ARN \
    --approve --override-existing-serviceaccounts

sleep 30

# Verify
export KUBECOST_ROLE_ARN=$(kubectl get sa kubecost-serviceaccount -n kubecost \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
echo "IRSA Role: $KUBECOST_ROLE_ARN"
```

## Install Amazon EBS CSI Driver

### Create IAM Role

```bash
eksctl create iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system \
    --cluster $CLUSTER_NAME --region $AWS_REGION \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve --role-only --role-name EBS_CSI_DriverRole_${CLUSTER_NAME}

export EBS_CSI_ROLE_ARN=$(aws iam get-role --role-name EBS_CSI_DriverRole_${CLUSTER_NAME} --query 'Role.Arn' --output text)
```

### Add HyperPod EBS Permissions

```bash
cat > ebs-hyperpod-policy.json <<'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {"Effect":"Allow","Action":["ec2:CreateSnapshot","ec2:AttachVolume","ec2:DetachVolume","ec2:ModifyVolume","ec2:DescribeAvailabilityZones","ec2:DescribeInstances","ec2:DescribeSnapshots","ec2:DescribeTags","ec2:DescribeVolumes","ec2:DescribeVolumesModifications"],"Resource":"*"},
        {"Effect":"Allow","Action":["ec2:CreateTags"],"Resource":["arn:aws:ec2:*:*:volume/*","arn:aws:ec2:*:*:snapshot/*"],"Condition":{"StringEquals":{"ec2:CreateAction":["CreateVolume","CreateSnapshot"]}}},
        {"Effect":"Allow","Action":["ec2:DeleteTags"],"Resource":["arn:aws:ec2:*:*:volume/*","arn:aws:ec2:*:*:snapshot/*"]},
        {"Effect":"Allow","Action":["ec2:CreateVolume"],"Resource":"*"},
        {"Effect":"Allow","Action":["ec2:DeleteVolume"],"Resource":"*","Condition":{"StringLike":{"ec2:ResourceTag/ebs.csi.aws.com/cluster":"true"}}},
        {"Sid":"HyperPod","Effect":"Allow","Action":["sagemaker:AttachClusterNodeVolume","sagemaker:DetachClusterNodeVolume"],"Resource":"arn:aws:sagemaker:*:*:cluster/*"},
        {"Effect":"Allow","Action":["eks:DescribeCluster"],"Resource":"*"}
    ]
}
EOF

aws iam put-role-policy --role-name EBS_CSI_DriverRole_${CLUSTER_NAME} \
    --policy-name HyperPodEBSPolicy --policy-document file://ebs-hyperpod-policy.json
```

### Install Driver & Configure Storage

```bash
aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver \
    --region $AWS_REGION 2>/dev/null || \
eksctl create addon --name aws-ebs-csi-driver --cluster $CLUSTER_NAME \
    --region $AWS_REGION --service-account-role-arn $EBS_CSI_ROLE_ARN --force

aws eks wait addon-active --cluster-name $CLUSTER_NAME \
    --addon-name aws-ebs-csi-driver --region $AWS_REGION

# Set default storage class
kubectl patch storageclass gp2 \
    -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || \
kubectl patch storageclass gp3 \
    -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null

echo "✅ EBS CSI Driver installed"
```
