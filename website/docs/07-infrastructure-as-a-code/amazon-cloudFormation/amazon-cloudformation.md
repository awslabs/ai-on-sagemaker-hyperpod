---
title: "CloudFormation Deployment"
sidebar_position: 2
---

# CloudFormation Deployment for SageMaker HyperPod

This guide covers deploying SageMaker HyperPod infrastructure using CloudFormation templates. CloudFormation templates are available for both EKS and Slurm orchestration types, providing Infrastructure as Code (IaC) solutions.

When using the [recommended in-console cluster creation](/docs/00-getting-started/orchestrated-by-eks/initial-cluster-setup.md) to deploy your HyperPod cluster, it will be using CloudFormation in the backend to deploy the resources. 

**These CloudFormation templates are hosted in [`sagemaker-hyperpod-cluster-setup`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/tree/main) GitHub Repository.** 

## EKS Orchestration

### Architecture Overview

The EKS CloudFormation deployment uses nested stacks to create a comprehensive HyperPod environment. Each stack is responsible for different infrastructure components.

### Quick Start - EKS

🚨 **Recommended**: Follow the official AWS documentation for [EKS orchestration](https://docs.aws.amazon.com/sagemaker/latest/dg/smcluster-getting-started-eks-console-create-cluster-cfn.html) for detailed instructions and latest best practices.

#### Deploy EKS HyperPod Cluster

```bash
# Deploy complete EKS-based HyperPod infrastructure
aws cloudformation create-stack \
  --stack-name hyperpod-eks-main-stack \
  --template-url https://aws-sagemaker-hyperpod-cluster-setup-us-west-2-prod.s3.us-west-2.amazonaws.com/templates/main-stack-eks-based-template.yaml \
  --parameters ParameterKey=ResourceNamePrefix,ParameterValue=my-hyperpod \
               ParameterKey=AvailabilityZoneIds,ParameterValue="usw2-az1,usw2-az2" \
               ParameterKey=HyperPodClusterName,ParameterValue=ml-cluster \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

**Important Parameters:**
- `AvailabilityZoneIds`: Must correspond to your target region and have capacity for your instance types
- `ResourceNamePrefix`: Use consistent naming across all resources
- `HyperPodClusterName`: Name for your HyperPod cluster
- `Stage`: Deployment stage (prod/dev) - affects which S3 bucket is used for templates


### EKS Nested Stacks

The main CloudFormation template from [`sagemaker-hyperpod-cluster-setup`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/tree/main/eks/cloudformation) repository includes these nested stacks:

#### 1. VPCStack - [`vpc-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/vpc-template.yaml)
Creates highly available VPC architecture across multiple Availability Zones.

**Resources Created:**
- VPC with Internet Gateway
- Public and Private Subnets across multiple AZs
- NAT Gateways for outbound connectivity
- Route Tables and associations

**Key Parameters:**
- `VpcCIDR`: VPC CIDR range
- `AvailabilityZoneIds`: List of AZ IDs for multi-AZ deployment
- `ResourceNamePrefix`: Consistent naming prefix

**Required if Disabled:**
- `VpcId` - Used by multiple other stacks
- `NatGatewayIds` - Used by PrivateSubnetStack

#### 2. PrivateSubnetStack - [`private-subnet-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/private-subnet-template.yaml)
Creates dedicated private subnets for SageMaker HyperPod cross-account ENIs.

**Resources Created:**
- Secondary CIDR Block for HyperPod
- Private Subnets in specified AZs
- Private Route Tables with NAT Gateway routing

**Key Parameters:**
- `AvailabilityZoneIds`: Target availability zones
- `NatGatewayIds`: NAT Gateways for outbound access

**Required if Disabled:**
- `PrivateSubnetIds` - Used by HyperPodClusterStack
- `PrivateRouteTableIds` - Used by S3EndpointStack

#### 3. SecurityGroupStack - [`security-group-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/security-group-template.yaml)
Configures security group with EFA and FSx communication rules optimized for HyperPod.

**Resources Created:**
- Security Group with HyperPod-optimized rules
- Intra-Security Group communication rules
- EFA communication rules (all ports within SG)
- FSx for Lustre Rules (TCP ports 988, 1018-1023)
- Outbound internet access

**Key Parameters:**
- `VpcId`: Target VPC for security group
- `SecurityGroupIds`: Additional security groups to reference

**Required if Disabled:**
- `SecurityGroupId` - Used by EKSClusterStack and HyperPodClusterStack

#### 4. EKSClusterStack - [`eks-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/eks-template.yaml)
Creates EKS cluster optimized for HyperPod workloads.

**Resources Created:**
- EKS Private Subnets (separate from HyperPod subnets)
- IAM Cluster Service Role
- EKS Cluster with latest Kubernetes version
- Essential EKS Add-ons:
  - VPC CNI (latest version)
  - kube-proxy
  - CoreDNS
  - EKS Pod Identity Agent
- EKS Access Entries for cluster management

**Key Parameters:**
- `KubernetesVersion`: EKS cluster version
- `EKSClusterName`: Name for the EKS cluster
- `SecurityGroupIds`: Security groups for cluster

**Required if Disabled:**
- `EKSClusterName` - Used by HelmChartStack and HyperPodClusterStack

#### 5. S3BucketStack - [`s3-bucket-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/s3-bucket-template.yaml)
Creates encrypted S3 bucket for lifecycle scripts and cluster artifacts.

**Resources Created:**
- S3 Bucket with server-side encryption
- Bucket policy for HyperPod access
- Versioning and lifecycle policies

**Key Parameters:**
- `ResourceNamePrefix`: Bucket naming prefix
- `S3BucketName`: Custom bucket name (optional)

**Required if Disabled:**
- `S3BucketName` - Used by LifeCycleScriptStack and HyperPodClusterStack

#### 6. S3EndpointStack - [`s3-endpoint-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/s3-endpoint-template.yaml)
Creates VPC endpoint for private S3 connectivity from HyperPod instances.

**Resources Created:**
- VPC Endpoint for S3 service
- Route table associations for private subnets
- Endpoint policy for secure access

**Key Parameters:**
- `VpcId`: Target VPC
- `PrivateRouteTableIds`: Route tables to associate

#### 7. LifeCycleScriptStack - [`lifecycle-script-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/lifecycle-script-template.yaml)
Deploys Lambda function to create and manage default lifecycle scripts.

**Resources Created:**
- AWS Lambda Function for script management
- IAM Role for Lambda execution
- [Default EKS Lifecycle Scripts](https://github.com/aws-samples/awsome-distributed-training/tree/main/1.architectures/7.sagemaker-hyperpod-eks/LifecycleScripts/base-config) uploaded to S3

**Key Parameters:**
- `S3BucketName`: Target bucket for lifecycle scripts
- `GithubRawUrl`: Source URL for lifecycle scripts
- `OnCreatePath`: Path to on_create.sh script

#### 8. SageMakerIAMRoleStack - [`sagemaker-iam-role-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/sagemaker-iam-role-template.yaml)
Creates IAM role with comprehensive permissions for HyperPod cluster operations.

**Resources Created:**
- SageMaker Execution Role
- Policies for HyperPod, EKS, and AWS service access
- Trust relationships for SageMaker service

**Key Parameters:**
- `ResourceNamePrefix`: Role naming prefix
- `SageMakerIAMRoleName`: Custom role name (optional)

**Required if Disabled:**
- `SageMakerIAMRoleName` - Used by HyperPodClusterStack

#### 9. HelmChartStack - [`helm-chart-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/helm-chart-template.yaml)
Automates installation of HyperPod dependency Helm charts on EKS cluster.

**Resources Created:**
- AWS Lambda Function for Helm chart deployment
- EKS Access Entry for Lambda function
- Kubernetes resources from [HyperPod Helm charts](https://github.com/aws/sagemaker-hyperpod-cli/tree/main/helm_chart):
  - Health monitoring agents
  - Training operators
  - Inference operators (optional)
  - Observability components

**Key Parameters:**
- `EKSClusterName`: Target EKS cluster
- `HelmRepoUrl`: Helm repository URL
- `HelmOperators`: List of operators to install
- `Namespace`: Kubernetes namespace for deployment

#### 10. HyperPodClusterStack - [`hyperpod-cluster-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/hyperpod-cluster-template.yaml)
Creates the SageMaker HyperPod cluster with flexible instance group configuration.

**Resources Created:**
- SageMaker HyperPod Cluster
- Multiple configurable instance groups (up to 20)
- Auto-scaling configuration
- Node recovery settings

**Key Parameters:**
- `HyperPodClusterName`: Cluster name
- `NodeRecovery`: Automatic or Manual
- `NodeProvisioningMode`: Continuous or OnDemand
- `AutoScalerType`: HyperPod native or Karpenter
- Instance Group Settings (1-20): Each with:
  - Instance type and count
  - EBS volume configuration
  - Lifecycle script settings
  - Custom AMI options

#### 11. FsxStack - [`fsx-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/fsx-template.yaml)
Creates high-performance FSx for Lustre file system for shared storage.

**Resources Created:**
- FSx for Lustre file system
- Mount targets in private subnets
- Security group rules for FSx access

**Key Parameters:**
- `StorageCapacity`: File system size in GiB
- `PerUnitStorageThroughput`: Performance tier
- `DeploymentType`: SCRATCH_1, SCRATCH_2, or PERSISTENT
- `DataCompressionType`: LZ4 compression option

#### 12. PrivateSubnetTagsStack - [`private-subnet-tagging-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/private-subnet-tagging-template.yaml)
Applies necessary tags to private subnets for HyperPod and EKS integration.

**Resources Created:**
- Lambda function for subnet tagging
- Tags for EKS cluster discovery
- Tags for HyperPod subnet identification

#### 13. InferenceOperatorMainStack - [`inference-operator-main-stack-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/eks/cloudformation/inference-operator-main-stack-template.yaml)
Deploys inference operator components for HyperPod inference workloads (optional).

**Resources Created:**
- Inference operator Helm charts
- TLS certificates for secure communication
- Service accounts and RBAC configurations
- IAM roles for inference operations

#### 14. ObservabilityCustomStack
Deploys comprehensive observability stack with Prometheus and Grafana integration (optional).

**Resources Created:**
- Amazon Managed Prometheus workspace
- Amazon Managed Grafana workspace
- CloudWatch integration
- Custom dashboards for HyperPod metrics

### Manual CloudFormation Deployment

The CloudFormation templates are automatically synced from AWS-managed S3 buckets to the [`sagemaker-hyperpod-cluster-setup`](https://github.com/aws/sagemaker-hyperpod-cluster-setup) repository. For custom deployments:

#### Using AWS-Hosted Templates (Recommended)

The templates reference AWS-managed S3 buckets by default:
- **Production**: `aws-sagemaker-hyperpod-cluster-setup-{region}-prod`
- **Development**: `aws-sagemaker-hyperpod-cluster-setup-{region}-dev`

Deploy directly using the main stack template:

```bash
# Deploy EKS-based HyperPod cluster
aws cloudformation create-stack \
  --stack-name hyperpod-eks-cluster \
  --template-url https://aws-sagemaker-hyperpod-cluster-setup-us-west-2-prod.s3.us-west-2.amazonaws.com/templates/main-stack-eks-based-template.yaml \
  --parameters ParameterKey=ResourceNamePrefix,ParameterValue=my-hyperpod \
               ParameterKey=AvailabilityZoneIds,ParameterValue="usw2-az1,usw2-az2" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

#### Using Custom S3 Bucket

To host templates in your own S3 bucket:

1. **Clone the Repository**
   ```bash
   git clone https://github.com/aws/sagemaker-hyperpod-cluster-setup.git
   cd sagemaker-hyperpod-cluster-setup
   ```

2. **Upload Templates to Your Bucket**
   ```bash
   BUCKET_NAME=<your-bucket-name>
   aws s3 cp eks/cloudformation/ s3://$BUCKET_NAME/templates/ --recursive
   aws s3 cp eks/cloudformation/resources/ s3://$BUCKET_NAME/resources/ --recursive
   ```

3. **Deploy with Custom Bucket**
   ```bash
   aws cloudformation create-stack \
     --stack-name hyperpod-eks-cluster \
     --template-body file://eks/cloudformation/main-stack-eks-based-template.yaml \
     --parameters ParameterKey=CustomBucketName,ParameterValue=$BUCKET_NAME \
                  ParameterKey=ResourceNamePrefix,ParameterValue=my-hyperpod \
     --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
   ```

## Slurm Orchestration

### Quick Start - Slurm

🚨 **Recommended**: Follow the official AWS documentation for [Slurm orchestration](https://docs.aws.amazon.com/sagemaker/latest/dg/smcluster-getting-started-slurm-console-create-cluster-cfn.html) for detailed instructions and latest best practices.

#### Deploy Slurm HyperPod Cluster

```bash
# Deploy complete Slurm-based HyperPod infrastructure
aws cloudformation create-stack \
  --stack-name hyperpod-slurm-main-stack \
  --template-url https://aws-sagemaker-hyperpod-cluster-setup-us-west-2-prod.s3.us-west-2.amazonaws.com/templates-slurm/main-stack-slurm-based-template.yaml \
  --parameters ParameterKey=ResourceNamePrefix,ParameterValue=my-hyperpod \
               ParameterKey=AvailabilityZoneIds,ParameterValue="usw2-az1,usw2-az2" \
               ParameterKey=HyperPodClusterName,ParameterValue=ml-cluster \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
```

### Slurm CloudFormation Templates

The Slurm deployment uses the main stack template from [`sagemaker-hyperpod-cluster-setup`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/tree/main/slurm/cloudformation) repository:

#### Main Stack - [`main-stack-slurm-based-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/main-stack-slurm-based-template.yaml)

The main Slurm stack includes these nested components:

#### 1. VPCStack - [`slurm-vpc-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/slurm-vpc-template.yaml)
Creates VPC infrastructure optimized for Slurm HyperPod clusters.

**Resources Created:**
- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- Route tables and security groups
- S3 and DynamoDB VPC endpoints

**Key Parameters:**
- `VpcCIDR`: VPC CIDR range
- `AvailabilityZoneIds`: Target availability zones
- `ResourceNamePrefix`: Consistent naming

#### 2. SecurityGroupStack - [`slurm-security-group-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/slurm-security-group-template.yaml)
Configures security groups for Slurm cluster communication.

**Resources Created:**
- Security group with Slurm-specific rules
- EFA communication rules
- FSx for Lustre access rules
- SSH and cluster communication ports

#### 3. S3BucketStack
Creates S3 bucket for Slurm lifecycle scripts and cluster artifacts.

**Resources Created:**
- Encrypted S3 bucket
- Bucket policies for HyperPod access
- Lifecycle script storage

#### 4. LifeCycleScriptStack - [`slurm-lifecycle-script-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/slurm-lifecycle-script-template.yaml)
Manages Slurm-specific lifecycle scripts.

**Resources Created:**
- Lambda function for script deployment
- [Slurm Lifecycle Scripts](https://github.com/aws-samples/awsome-distributed-training/tree/main/1.architectures/5.sagemaker-hyperpod/LifecycleScripts/base-config) uploaded to S3
- Slurm configuration files

#### 5. SageMakerIAMRoleStack - [`slurm-iam-role-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/slurm-iam-role-template.yaml)
Creates IAM role for Slurm HyperPod operations.

**Resources Created:**
- SageMaker execution role
- Policies for Slurm cluster management
- Trust relationships for HyperPod service

#### 6. FsxStack - [`slurm-fsx-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/slurm-fsx-template.yaml)
Creates FSx for Lustre file system for Slurm clusters.

**Resources Created:**
- High-performance FSx for Lustre file system
- Mount targets in private subnets
- Security group rules for FSx access

#### 7. HyperPodClusterStack - [`slurm-hyperpod-cluster-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/slurm-hyperpod-cluster-template.yaml)
Creates the Slurm-based HyperPod cluster with up to 20 configurable instance groups.

**Resources Created:**
- SageMaker HyperPod Cluster with Slurm orchestration
- Controller nodes (head nodes)
- Login nodes
- Compute nodes (worker nodes)
- Multiple instance group configurations

**Key Parameters:**
- `HyperPodClusterName`: Cluster name
- `NodeRecovery`: Automatic or Manual
- `InstanceGroupSettings1-20`: Up to 20 instance groups with:
  - Instance type and count
  - EBS volume configuration
  - Lifecycle script settings
  - Custom AMI options

#### 8. SSMStack - [`slurm-ssm-template.yaml`](https://github.com/aws/sagemaker-hyperpod-cluster-setup/blob/main/slurm/cloudformation/slurm-ssm-template.yaml)
Configures Systems Manager for cluster access and management.

**Resources Created:**
- SSM endpoints for private subnet access
- IAM roles for SSM connectivity
- Session Manager configuration

## Manual Deployment Steps

### Prerequisites

1. **IAM Role Creation**
   ```bash
   aws iam create-role \
       --role-name AmazonSagemakerExecutionRole \
       --assume-role-policy-document file://0.AmazonSageMakerClustersExecutionRoleTrustedEntities.json

   aws iam create-policy \
       --policy-name AmazonSagemakerExecutionPolicy \
       --policy-document file://1.AmazonSageMakerClustersExecutionRolePolicy.json

   POLICY=$(aws iam list-policies --query 'Policies[?PolicyName==`AmazonSagemakerExecutionPolicy`]' | jq '.[0].Arn' | tr -d '"')
   aws iam attach-role-policy \
       --role-name AmazonSagemakerExecutionRole \
       --policy-arn $POLICY
   ```

2. **S3 Bucket for Lifecycle Scripts**
   ```bash
   BUCKET="sagemaker-lifecycle-$(python3 -S -c 'import uuid; print(str(uuid.uuid4().hex)[:10])')"
   aws s3 mb s3://${BUCKET}
   ```

### Deployment Sequence

1. **Deploy VPC Stack** (if not using existing VPC)
2. **Deploy FSx Lustre Stack** (optional, for shared storage)
3. **Upload Lifecycle Scripts**
   ```bash
   aws s3 cp --recursive LifecycleScripts/base-config s3://${BUCKET}/LifecycleScripts/base-config
   ```
4. **Deploy HyperPod Cluster**

### Configuration Examples

#### Slurm Cluster Configuration
```json
[
  {
    "InstanceGroupName": "controller-machine",
    "InstanceType": "ml.c5.xlarge",
    "InstanceCount": 1,
    "LifeCycleConfig": {
      "SourceS3Uri": "s3://${BUCKET}/LifecycleScripts/base-config/",
      "OnCreate": "on_create.sh"
    },
    "ExecutionRole": "${ROLE}",
    "ThreadsPerCore": 1
  },
  {
    "InstanceGroupName": "compute-nodes",
    "InstanceType": "ml.trn1.32xlarge",
    "InstanceCount": 4,
    "LifeCycleConfig": {
      "SourceS3Uri": "s3://${BUCKET}/LifecycleScripts/base-config/",
      "OnCreate": "on_create.sh"
    },
    "ExecutionRole": "${ROLE}",
    "ThreadsPerCore": 1
  }
]
```

#### VPC Configuration
```json
{
  "SecurityGroupIds": ["$SECURITY_GROUP"],
  "Subnets": ["$SUBNET_ID"]
}
```

## Lifecycle Scripts

CloudFormation deployments automatically handle lifecycle scripts that:

### For Slurm
- Configure Slurm scheduler and accounting
- Mount FSx Lustre file system
- Install Docker, Enroot, and Pyxis
- Set up user accounts and POSIX permissions
- Configure EFA and networking

### For EKS
- Install HyperPod dependency Helm charts
- Configure Kubernetes resources
- Set up monitoring and logging
- Configure EFA device plugins


## Best Practices

1. **Parameter Validation**: Always validate parameters before deployment
2. **Resource Naming**: Use consistent naming conventions with prefixes
3. **Security**: Review security group rules and IAM policies
4. **Monitoring**: Deploy observability stacks for production workloads
5. **Backup**: Use S3 for lifecycle script and configuration backup

## Troubleshooting

### Common Issues

**Stack Creation Fails**: Check CloudWatch logs for detailed error messages
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/sagemaker/Clusters
```

**Resource Limits**: Verify service quotas for your instance types
```bash
aws service-quotas get-service-quota \
  --service-code sagemaker \
  --quota-code L-1194F6F1
```

**VPC Configuration**: Ensure subnets are in correct availability zones with capacity

### Getting Help

- Review CloudFormation events in the AWS Console
- Check [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training) for updates


## Clean Up

Delete stacks in reverse order of creation:

```bash
# Delete HyperPod cluster first
aws sagemaker delete-cluster --cluster-name ml-cluster

# Then delete CloudFormation stacks
aws cloudformation delete-stack --stack-name hyperpod-cluster-stack
aws cloudformation delete-stack --stack-name fsx-lustre-stack
aws cloudformation delete-stack --stack-name vpc-stack
```

The CloudFormation templates provide a robust, repeatable way to deploy SageMaker HyperPod infrastructure with AWS best practices built-in.