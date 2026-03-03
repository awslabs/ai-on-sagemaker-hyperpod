---
title: "PyTorch Environment Validation"
sidebar_position: 1
---

# PyTorch Environment Validation on Slurm

This validation script runs a comprehensive PyTorch environment check to screen for NCCL, MPI, OpenMP, CUDA, and other critical components on your HyperPod cluster. The script executes once per instance and helps verify that your environment is properly configured for distributed training.

## Overview

The PyTorch environment validation performs the following checks:
- **CUDA availability and configuration**
- **PyTorch backend status** (CUDA, cuDNN, MKL, OpenMP)
- **Distributed training capabilities** (NCCL, MPI)
- **GPU driver and library versions**
- **Container runtime validation**

## Prerequisites

- Functional Slurm cluster on AWS
- Docker, [Pyxis](https://github.com/NVIDIA/pyxis) and [Enroot](https://github.com/NVIDIA/enroot) installed
- Shared directory mounted (typically `/fsx` or `/apps`)
- AWS Deep Learning Container access

## Get the Validation Scripts

The PyTorch validation scripts are available in the [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training/tree/main/4.validation_and_observability/1.pytorch-env-validation).

```bash
# Clone the repository
git clone https://github.com/aws-samples/awsome-distributed-training.git
cd awsome-distributed-training/4.validation_and_observability/1.pytorch-env-validation
```

Available files:
- [pytorch-screen.py](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/1.pytorch-env-validation/pytorch-screen.py): Main validation script
- [1.torch-screen.sbatch](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/1.pytorch-env-validation/1.torch-screen.sbatch): Slurm job script
- [0.pytorch-screen.Dockerfile](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/1.pytorch-env-validation/0.pytorch-screen.Dockerfile): Container build file

### Script Features

The `pytorch-screen.py` script provides comprehensive validation of:
- **PyTorch version and configuration**
- **CUDA availability and device detection**
- **cuDNN backend settings**
- **Distributed training capabilities** (NCCL, MPI)
- **Backend availability** (MKL, OpenMP, opt_einsum)
- **Environment variable validation**

## Slurm Implementation

### 1. Build the Validation Container

Use the provided Dockerfile from the awsome-distributed-training repository:

**Dockerfile**: [`0.pytorch-screen.Dockerfile`](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/1.pytorch-env-validation/0.pytorch-screen.Dockerfile)

Build and convert to Enroot format:

```bash
# Get the region
AWS_AZ=$(ec2-metadata --availability-zone | cut -d' ' -f2)
AWS_REGION=${AWS_AZ::-1}

# Authenticate with ECR
aws ecr get-login-password | docker login --username AWS \
   --password-stdin 763104351884.dkr.ecr.${AWS_REGION}.amazonaws.com/pytorch-training

# Build the container using the provided Dockerfile
docker build -t pytorch-validation -f 0.pytorch-screen.Dockerfile \
   --build-arg="AWS_REGION=${AWS_REGION}" .

# Convert to Enroot squash file
enroot import -o /fsx/pytorch-validation.sqsh dockerd://pytorch-validation:latest
```

### 2. Use the Provided Slurm Job Script

The repository includes a ready-to-use Slurm job script at [`1.torch-screen.sbatch`](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/1.pytorch-env-validation/1.torch-screen.sbatch).

Key configuration options in the script:
- **Node count**: Modify `#SBATCH -N 2` to change number of nodes
- **Container image**: Set `IMAGE` variable to your container path
- **Shared filesystem**: Configure `FSX_MOUNT` for your setup

### 3. Run the Validation

```bash
# Submit the job
sbatch pytorch-validation.sbatch

# Monitor the output
tail -f slurm-<job-id>.out
```

## Expected Output

The validation script will produce output similar to:

```
==================================================
 PyTorch Environment Validation
==================================================
PyTorch Version: 2.0.1+cu118
Python Version: 3.10.11

==================================================
 CUDA Configuration
==================================================
torch.cuda.is_available() = True
torch.version.cuda = 11.8
torch.backends.cuda.is_built() = True
CUDA Device Count: 8
  Device 0: NVIDIA H100 80GB HBM3
  Device 1: NVIDIA H100 80GB HBM3
  ...

==================================================
 Distributed Training
==================================================
torch.distributed.is_available() = True
torch.distributed.is_mpi_available() = True
torch.distributed.is_nccl_available() = True

==================================================
 Validation Complete
==================================================
Environment validation finished successfully!
```

## Troubleshooting

### Common Issues

1. **CUDA not available**
   - Verify NVIDIA drivers are installed
   - Check GPU resource allocation in job spec
   - Ensure container has GPU access

2. **NCCL not available**
   - Verify NCCL installation in container
   - Validate network configuration

3. **Container mount issues**
   - Verify Enroot/Pyxis installation
   - Check shared filesystem permissions
   - Ensure squash file is accessible

### Validation Checklist

- ✅ CUDA is available and detects all GPUs
- ✅ NCCL is available for distributed training
- ✅ MPI is available for multi-node communication
- ✅ EFA devices are accessible (if using EFA-enabled instances)
- ✅ Container can access shared storage
- ✅ Environment variables are properly set
