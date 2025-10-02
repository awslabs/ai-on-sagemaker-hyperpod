---
title: "EFA and Network Stack Validation"
sidebar_position: 2
---

# EFA and Network Stack Validation

This validation script checks the versions and configuration of the Elastic Fabric Adapter (EFA) network stack, including EFA installer, libfabric, AWS OFI NCCL, NCCL, and CUDA components. This is essential for ensuring optimal network performance in distributed training workloads.

## Overview

The EFA validation performs the following checks:
- **EFA installer version verification**
- **Libfabric version and configuration**
- **AWS OFI NCCL plugin version**
- **NCCL library version**
- **NVIDIA driver and CUDA versions**
- **Network interface configuration**

## Prerequisites

### For All Clusters
- EFA-enabled instance types (p4d, p5, trn1, etc.)
- EFA drivers installed on nodes
- Python 3 with `prettytable` package

### For Slurm Clusters
- Access to compute nodes via `srun`
- Shared filesystem for script distribution

### For EKS Clusters
- EFA device plugin deployed
- Nodes with EFA interfaces configured

## EFA Version Validation Script

The EFA validation script is available in the [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training/blob/main/4.validation_and_observability/efa-versions.py).

### Download and Setup

```bash
# Clone the repository
git clone https://github.com/aws-samples/awsome-distributed-training.git
cd awsome-distributed-training/4.validation_and_observability

# Install dependencies
pip install prettytable

# Make script executable
chmod +x efa-versions.py
```

### Script Features

The `efa-versions.py` script provides:
- **EFA installer version detection**
- **Libfabric version checking**
- **NCCL version identification**
- **AWS OFI NCCL plugin validation**
- **NVIDIA driver and CUDA version reporting**
- **Container vs local version comparison**
- **Detailed EFA interface configuration**

## Usage Examples

### Slurm Implementation

1. **Install dependencies and run validation**:

```bash
# Install Python dependencies
pip install prettytable

# Copy script to shared filesystem
cp efa-versions.py /fsx/

# Run on all compute nodes
srun python3 /fsx/efa-versions.py --detailed

# Run with container comparison
srun python3 /fsx/efa-versions.py -c your-training-container:latest
```

2. **Create Slurm job for systematic validation**:

```bash
#!/bin/bash
#SBATCH -N 2
#SBATCH --job-name=efa-validation
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive

echo "EFA Validation Report - $(date)"
echo "Cluster: $(hostname)"

# Run EFA validation
srun python3 /fsx/efa-versions.py --detailed

# Test EFA connectivity
echo -e "\nTesting EFA connectivity..."
srun fi_info -p efa -t FI_EP_RDM

# Check EFA bandwidth
echo -e "\nEFA Interface Details..."
srun ibv_devinfo
```

### EKS Implementation

1. **Create validation job**:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: efa-validation
spec:
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        node.kubernetes.io/instance-type: "p5.48xlarge"
      containers:
      - name: efa-validator
        image: ubuntu:22.04
        command: ["/bin/bash"]
        args:
        - -c
        - |
          apt-get update && apt-get install -y python3 python3-pip
          pip3 install prettytable
          python3 /scripts/efa-versions.py --detailed
        resources:
          limits:
            vpc.amazonaws.com/efa: 32
          requests:
            vpc.amazonaws.com/efa: 32
        volumeMounts:
        - name: efa-script
          mountPath: /scripts
      volumes:
      - name: efa-script
        configMap:
          name: efa-validation-script
```

2. **Deploy and run**:

```bash
# Create ConfigMap with script
kubectl create configmap efa-validation-script --from-file=efa-versions.py

# Apply job
kubectl apply -f efa-validation-job.yaml

# Check results
kubectl logs -l job-name=efa-validation
```

## Expected Output

```
EFA and Network Stack Validation
==================================================
+---------------+----------------+
| Component     | Version        |
+---------------+----------------+
| EFA Installer | 1.31.0         |
| Libfabric     | 1.18.2         |
| NCCL          | 2.20.3         |
| AWS OFI NCCL  | 1.8.1-aws      |
| NVIDIA Driver | 535.183.01     |
| CUDA          | 12.1.105       |
+---------------+----------------+

============================================================
 EFA Configuration Check
============================================================
EFA Interfaces Found: 32
  Interface 0: rdmap0s29-rdm
  Interface 1: rdmap1s29-rdm
  ...
InfiniBand devices: rdma_cm, uverbs0, uverbs1, ...
EFA kernel module: Loaded
```

## Version Compatibility Matrix

| EFA Installer | AWS OFI NCCL | NCCL    | Recommended Use Case |
|---------------|--------------|---------|---------------------|
| 1.31.0        | v1.8.1-aws   | 2.20.3  | Latest features     |
| 1.30.0        | v1.7.3-aws   | 2.18.5  | Stable production   |
| 1.29.1        | v1.7.2-aws   | 2.18.3  | Legacy support      |

## Troubleshooting

### Common Issues

1. **EFA interfaces not found**
   ```bash
   # Check if EFA is enabled on instance type
   curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | \
   xargs -I {} curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/{}/interface-type
   ```

2. **AWS OFI NCCL not found**
   ```bash
   # Check installation path
   find /opt -name "*ofi*" -type d 2>/dev/null
   find /usr -name "*nccl-net*" 2>/dev/null
   ```

3. **Version mismatches**
   - Ensure container and host have compatible versions
   - Check for multiple NCCL installations
   - Verify EFA installer completed successfully

### Validation Checklist

- ✅ EFA installer version matches expected
- ✅ Libfabric is properly installed and configured
- ✅ AWS OFI NCCL plugin is available
- ✅ NCCL version is compatible with PyTorch
- ✅ EFA interfaces are detected and accessible
- ✅ NVIDIA drivers are up to date

## Performance Recommendations

Based on validation results:

1. **For P5 instances**: Use EFA installer 1.31.0+ with AWS OFI NCCL v1.8.1+
2. **For P4d instances**: EFA installer 1.29.1+ is sufficient
3. **For Trainium**: Ensure Neuron SDK compatibility with EFA versions

