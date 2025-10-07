---
title: "Terraform Deployment"
sidebar_position: 1
---

# Terraform Deployment for SageMaker HyperPod

This guide covers deploying SageMaker HyperPod infrastructure using Terraform modules from the [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training). Terraform modules are available for both EKS and Slurm orchestration types.

## Architecture Overview

The Terraform modules provide Infrastructure as Code (IaC) for deploying complete SageMaker HyperPod environments including:

- **VPC with public and private subnets**
- **Security groups configured for EFA communication**
- **FSx for Lustre file system** (high-performance shared storage)
- **S3 bucket for lifecycle scripts**
- **IAM roles and policies**
- **SageMaker HyperPod cluster** with chosen orchestration

## EKS Orchestration

### Architecture Diagram

The EKS Terraform modules create a comprehensive infrastructure stack:

![HyperPod EKS Terraform Modules](https://github.com/aws-samples/awsome-distributed-training/raw/main/1.architectures/7.sagemaker-hyperpod-eks/terraform-modules/smhp_tf_modules.png)

### Quick Start - EKS

1. **Clone and Navigate**
   ```bash
   git clone https://github.com/aws-samples/awsome-distributed-training.git
   cd awsome-distributed-training/1.architectures/7.sagemaker-hyperpod-eks/terraform-modules/hyperpod-eks-tf
   ```

2. **Customize Configuration**

   Review the default configurations in `terraform.tfvars` and create a custom configuration:

   ```bash
   cat > custom.tfvars << EOL 
   kubernetes_version = "1.32"
   eks_cluster_name = "my-eks-cluster"
   hyperpod_cluster_name = "my-hp-cluster"
   resource_name_prefix = "hp-eks-test"
   aws_region = "us-west-2"
   availability_zone_id = "usw2-az2"
   instance_groups = {
       accelerated-instance-group-1 = {
           instance_type = "ml.p5en.48xlarge",
           instance_count = 5,
           ebs_volume_size_in_gb = 100,
           threads_per_core = 2,
           enable_stress_check = true,
           enable_connectivity_check = true,
           lifecycle_script = "on_create.sh"
       }
   }
   EOL
   ```

3. **Deploy Infrastructure**

   First, clone the HyperPod Helm charts repository:
   ```bash
   git clone https://github.com/aws/sagemaker-hyperpod-cli.git /tmp/helm-repo
   ```

   Initialize and deploy:
   ```bash
   terraform init
   terraform plan -var-file=custom.tfvars
   terraform apply -var-file=custom.tfvars
   ```

4. **Set Environment Variables**
   ```bash
   cd ..
   chmod +x terraform_outputs.sh
   ./terraform_outputs.sh
   source env_vars.sh
   ```

### Using Existing EKS Cluster

To use an existing EKS cluster, configure your `custom.tfvars`:

```hcl
create_eks_module = false
existing_eks_cluster_name = "my-eks-cluster"
existing_security_group_id = "sg-1234567890abcdef0"
create_vpc_module = false
existing_vpc_id = "vpc-1234567890abcdef0"
existing_nat_gateway_id = "nat-1234567890abcdef0"
hyperpod_cluster_name = "my-hp-cluster"
resource_name_prefix = "hp-eks-test"
aws_region = "us-west-2"
availability_zone_id = "usw2-az2"
instance_groups = {
    accelerated-instance-group-1 = {
        instance_type = "ml.p5en.48xlarge",
        instance_count = 5,
        ebs_volume_size_in_gb = 100,
        threads_per_core = 2,
        enable_stress_check = true,
        enable_connectivity_check = true,
        lifecycle_script = "on_create.sh"
    }
}
```

## Slurm Orchestration

### Quick Start - Slurm

1. **Clone and Navigate**
   ```bash
   git clone https://github.com/aws-samples/awsome-distributed-training.git
   cd awsome-distributed-training/1.architectures/5.sagemaker-hyperpod/terraform-modules/hyperpod-slurm-tf
   ```

2. **Customize Configuration**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific requirements
   ```

   Example configuration:
   ```hcl
   # terraform.tfvars
   resource_name_prefix = "hyperpod"
   aws_region = "us-west-2"
   availability_zone_id = "usw2-az2"

   hyperpod_cluster_name = "ml-cluster"

   instance_groups = {
     controller-machine = {
       instance_type = "ml.c5.2xlarge"
       instance_count = 1
       ebs_volume_size = 100
       threads_per_core = 1
       lifecycle_script = "on_create.sh"
     }
     login-nodes = {
       instance_type    = "ml.m5.4xlarge"
       instance_count   = 1
       ebs_volume_size  = 100
       threads_per_core = 1
       lifecycle_script = "on_create.sh"
     }
     compute-nodes = {
       instance_type = "ml.g5.4xlarge"
       instance_count = 2
       ebs_volume_size = 500
       threads_per_core = 1
       lifecycle_script = "on_create.sh"
     }
   }
   ```

3. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Extract Outputs**
   ```bash
   ./terraform_outputs.sh
   source env_vars.sh
   ```

### Slurm Modules

The Slurm Terraform deployment includes these modules:

- **vpc**: Creates VPC with public/private subnets, IGW, NAT Gateway
- **security_group**: EFA-enabled security group for HyperPod
- **fsx_lustre**: High-performance Lustre file system
- **s3_bucket**: Storage for lifecycle scripts
- **sagemaker_iam_role**: IAM role with required permissions
- **lifecycle_script**: Uploads and configures Slurm lifecycle scripts
- **hyperpod_cluster**: SageMaker HyperPod cluster with Slurm

## Reusing Existing Resources

Both EKS and Slurm modules support reusing existing infrastructure. Set the corresponding `create_*_module` to `false` and provide the existing resource ID:

```hcl
create_vpc_module = false
existing_vpc_id = "vpc-1234567890abcdef0"
existing_private_subnet_id = "subnet-1234567890abcdef0"
existing_security_group_id = "sg-1234567890abcdef0"
```

## Lifecycle Scripts

The Terraform modules automatically handle lifecycle scripts:

### For Slurm
- Uploads base Slurm configuration from `../../LifecycleScripts/base-config/`
- Configures Slurm scheduler
- Mounts FSx Lustre file system
- Installs Docker, Enroot, and Pyxis
- Sets up user accounts and permissions

### For EKS
- Deploys HyperPod dependency Helm charts
- Configures EKS cluster for HyperPod integration
- Sets up necessary Kubernetes resources

## Accessing Your Cluster

### Slurm Cluster Access

After deployment, use the provided helper script:

```bash
./easy-ssh.sh <cluster-name> <region>
```

Or manually:
```bash
aws ssm start-session --target sagemaker-cluster:${CLUSTER_ID}_${CONTROLLER_GROUP}-${INSTANCE_ID}
```

### EKS Cluster Access

Configure kubectl to access your EKS cluster:

```bash
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
kubectl get nodes
```

## Configuration Examples

### High-Performance Computing Setup

For large-scale training workloads:

```hcl
instance_groups = {
  controller-machine = {
    instance_type = "ml.c5.4xlarge"
    instance_count = 1
    ebs_volume_size = 200
    threads_per_core = 1
    lifecycle_script = "on_create.sh"
  }
  compute-nodes = {
    instance_type = "ml.p5.48xlarge"
    instance_count = 8
    ebs_volume_size = 1000
    threads_per_core = 2
    lifecycle_script = "on_create.sh"
  }
}
```

### Development Environment

For smaller development clusters:

```hcl
instance_groups = {
  controller-machine = {
    instance_type = "ml.c5.xlarge"
    instance_count = 1
    ebs_volume_size = 100
    threads_per_core = 1
    lifecycle_script = "on_create.sh"
  }
  compute-nodes = {
    instance_type = "ml.g5.xlarge"
    instance_count = 2
    ebs_volume_size = 200
    threads_per_core = 1
    lifecycle_script = "on_create.sh"
  }
}
```

## Monitoring and Validation

After deployment, validate your cluster:

```bash
# For Slurm clusters
sinfo
squeue

# For EKS clusters
kubectl get nodes
kubectl get pods -A
```

## Clean Up

To destroy the infrastructure:

```bash
# Validate the destroy plan first
terraform plan -destroy

# If using custom.tfvars
terraform plan -destroy -var-file=custom.tfvars

# Destroy resources
terraform destroy

# If using custom.tfvars
terraform destroy -var-file=custom.tfvars
```

## Best Practices

1. **Version Control**: Store your `terraform.tfvars` or `custom.tfvars` files in version control
2. **State Management**: Use remote state storage (S3 + DynamoDB) for production deployments
3. **Resource Tagging**: Use consistent tagging strategies via the `resource_name_prefix`
4. **Security**: Review IAM policies and security group rules before deployment
5. **Cost Optimization**: Choose appropriate instance types and counts for your workload

## Troubleshooting

### Common Issues

**Terraform Init Fails**: Ensure you have proper AWS credentials configured
```bash
aws configure list
```

**Resource Creation Fails**: Check availability zone capacity for your chosen instance types
```bash
aws ec2 describe-availability-zones --region us-west-2
```

**EKS Access Issues**: Verify your IAM permissions include EKS cluster access

**Slurm Issues**: Check lifecycle script logs in CloudWatch or on the instances

### Getting Help

- Review the [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training) for updates
- Check AWS documentation for [SageMaker HyperPod](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html)
- Validate your configuration with `terraform plan` before applying

The Terraform modules provide a robust, repeatable way to deploy SageMaker HyperPod infrastructure with best practices built-in.