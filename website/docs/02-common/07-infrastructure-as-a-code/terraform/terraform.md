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

	Start by reviewing the default configurations in the `terraform.tfvars` file and create a `custom.tfvars` file with your parameter overrides. 
	
	For example, the following `custom.tfvars` file would enable the creation of all new resources including a new EKS Cluster and a HyperPod instance group of 5 `ml.p5en.48xlarge` instances in `us-west-2` using a [training plan](https://docs.aws.amazon.com/sagemaker/latest/dg/reserve-capacity-with-training-plans.html):

	```bash
	cat > custom.tfvars << EOL 
	kubernetes_version = "1.33"
	eks_cluster_name = "my-eks-cluster"
	hyperpod_cluster_name = "my-hp-cluster"
	resource_name_prefix = "hp-eks-test"
	aws_region = "us-west-2"
	instance_groups = [
	  {
	    name = "accelerated-instance-group-1"
	    instance_type = "ml.p5en.48xlarge",
	    instance_count = 5,
	    availability_zone_id  = "usw2-az2",
	    ebs_volume_size_in_gb = 100,
	    threads_per_core = 2,
	    enable_stress_check = true,
	    enable_connectivity_check = true,
	    lifecycle_script = "on_create.sh"
	    training_plan_arn = arn:aws:sagemaker:us-west-2:123456789012:training-plan/training-plan-example
	  }
	]
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
### Using an Existing EKS Cluster with HyperPod
To use an existing EKS cluster, configure your `custom.tfvars` to use an existing EKS Cluster (referenced by name) along with an existing Security Group, VPC, and NAT Gateway (referenced by ID):

```bash
cat > custom.tfvars << EOL 
create_eks_module = false
existing_eks_cluster_name = "my-eks-cluster"
existing_security_group_id = "sg-1234567890abcdef0"
create_vpc_module = false
existing_vpc_id = "vpc-1234567890abcdef0"
existing_nat_gateway_id = "nat-1234567890abcdef0"
hyperpod_cluster_name = "my-hp-cluster"
resource_name_prefix = "hp-eks-test"
aws_region = "us-west-2"
instance_groups = [
  {
    name = "accelerated-instance-group-1"
    instance_type = "ml.p5en.48xlarge",
    instance_count = 5,
    availability_zone_id  = "usw2-az2",
    ebs_volume_size_in_gb = 100,
    threads_per_core = 2,
    enable_stress_check = true,
    enable_connectivity_check = true,
    lifecycle_script = "on_create.sh"
    training_plan_arn = arn:aws:sagemaker:us-west-2:123456789012:training-plan/training-plan-example
  }
]
EOL
```
### Enabling Optional Addons

Set the following parameters to `true` in your `custom.tfvars` file to enable optional addons for your HyperPod cluster (e.g. `create_task_governance_module = true`):
| Parameter | Usage |
|-----------|-------|
| `create_task_governance_module`    | Installs the [HyperPod task governance addon](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-governance.html) for  job queuing, prioritization, and scheduling on multi-team compute clusters |
| `create_hyperpod_training_operator_module`   | Installs the [HyperPod training operator addon](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-eks-operator.html) for intelligent fault recovery, hang job detection, and process-level management capabilities (required for [Checkpointless](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-eks-checkpointless.html) and [Elastic](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-eks-elastic-training.html) training)|
| `create_hyperpod_inference_operator_module`  | Installs the [HyperPod inference operator addon](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-model-deployment-setup.html) for deployment and management of machine learning inference endpoints |
| `create_observability_module` | Installs the [HyperPod Observability addon](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-addon-setup.html) to publish key metrics to Amazon Managed Service for Prometheus and displays them in Amazon Managed Grafana dashboards | 

### Advanced Observability Metrics
In addition to enabling the [HyperPod Observability addon](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-addon-setup.html) by setting `create_observability_module = true`, you can also configure the following metrics that you wish to collect on your cluster: 
| Parameter | Default | Options | Usage |
|-----------|---------|---------|-------|
| `training_metric_level` | `BASIC` | `BASIC, ADVANCED` | Task duration, type, fault data (Advanced: Event-based task performance), [Learn More Here](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-cluster-metrics.html#hyperpod-observability-training-metrics)
| `task_governance_metric_level` | `DISABLED` | `DISABLED, ADVANCED` | Team-level resource allocation, [Learn More Here](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-cluster-metrics.html#hyperpod-observability-task-governance-metrics)
| `scaling_metric_level` | `DISABLED` | `DISABLED, ADVANCED` | KEDA auto-scaling metrics, [Learn More Here](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-cluster-metrics.html#hyperpod-observability-scaling-metrics)
| `cluster_metric_level` | `BASIC` | `BASIC, ADVANCED` | Cluster health, instance count (Advanced: Detailed Kube-state cluster metrics), [Learn More Here](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-cluster-metrics.html#hyperpod-observability-cluster-health-metrics)
| `node_metric_level` | `BASIC` | `BASIC, ADVANCED` | CPU, disk, OS-level usage (Advanced: Full node exporter suite), [Learn More Here](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-cluster-metrics.html#hyperpod-observability-instance-metrics)
| `network_metric_level` | `DISABLED` | `DISABLED, ADVANCED` | Elastic Fabric Adapter metrics, [Learn More Here](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-cluster-metrics.html#hyperpod-observability-network-metrics)
| `accelerated_compute_metric_level` | `BASIC` | `BASIC, ADVANCED` | GPU utilization, temperature (Advanced: All NVIDIA GPU DCGM, Neuron metrics), [Learn More Here](https://docs.aws.amazon.com/sagemaker/latest/dg/hyperpod-observability-cluster-metrics.html#hyperpod-observability-accelerated-compute-metrics)
| `logging_enabled` | `false` | `true, false` | When enabled, this will automatically create the required log groups in Amazon CloudWatch and start recording all container and pod logs as log streams

### FSx for Lustre Module
By default, the FSx for Lustre module installs the Amazon FSx for Lustre Container Storage Interface (CSI) Driver, but does not dynamically provision a new filesystem. For existing filesystems, you can follow [these steps in the AI on SageMaker HyperPod Workshop](https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/getting-started/orchestrated-by-eks/Set%20up%20your%20shared%20file%20system#option-3-bring-your-own-fsx-static-provisioning) for static provisioning. If you wish to create a new filesystem using Terraform, add the parameter `create_new_fsx_filesystem = true` to your `custom.tfvars` file, and review the `fsx_storage_capacity` (default 1200 GiB) and `fsx_throughput` (default 250 MBps/TiB) parameters to ensure they are set according to your requirements. When `create_new_fsx_filesystem = true` the FSx for Lustre module will statically create a new filesystem along with a StorageClass, PersistentVolume, and PersistentVolumeClaim (PVC). By default the PVC will be mapped to the default namespace. If you wish to use another namespace, use the `fsx_pvc_namespace` parameter to specify it. By default, specifying a non-default namespace will trigger the creation of that namespace. If you are using an existing EKS cluster where the target namespace already exists, set `create_fsx_pvc_namespace = false` to skip creation.

### Amazon GuardDuty EKS Runtime Monitoring
If your target account has [Amazon GuardDuty EKS Runtime Monitoring](https://docs.aws.amazon.com/guardduty/latest/ug/runtime-monitoring.html) enabled, an interface VPC endpoint is automatically created to allow the security agent to deliver events to GuardDuty while event data remains within the AWS network. Because this VPC endpoint is not managed by Terraform, the associated Elastic Network Interfaces (ENIs) and Security Group that are automatically deployed by GuardDuty can block destruction when you are ready to clean up. To mitigate this, we've included an optional GuardDuty cleanup script [guardduty-cleanup.sh](https://github.com/aws-samples/awsome-distributed-training/blob/main/1.architectures/7.sagemaker-hyperpod-eks/terraform-modules/hyperpod-eks-tf/scripts/guardduty-cleanup.sh) that is invoked only at destruction time using a Terraform `null_resource`. This script finds the GuardDuty VPC endpoint associated with your HyperPod VPC and deletes it, waits for the associated ENIs to be cleaned up, then deletes the associated Security Group. To enable this script at plan and apply time, simply add the parameter `enable_guardduty_cleanup = true` to your `custom.tfvars` file. This script won't run when you issue a `terraform apply` command, but will run when you issue a `terraform destroy` command. 

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
# Before destroying resources, list state to exclude any resources you wish to retain from deletion:
terraform state list
terraform state rm < resource_to_preserve >

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