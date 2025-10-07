---
title: "NCCL Performance Tests"
sidebar_position: 1
---

# NCCL Performance Tests

The [NCCL Tests](https://github.com/NVIDIA/nccl-tests) are a comprehensive testing suite that evaluates network performance between GPU instances using the NVIDIA Collective Communication Library. This is essential for validating cluster performance and troubleshooting issues before starting distributed training workloads.

## Overview

NCCL Tests provide:
- **Network bandwidth validation** between GPU instances
- **Latency measurements** for different collective operations
- **Scalability testing** across multiple nodes
- **Performance baseline establishment** for your cluster
- **Hardware issue detection** through systematic testing

### Performance Expectations

Network performance varies by instance type:
- **p4d.24xlarge**: 400 Gbps network bandwidth
- **p5.48xlarge**: 3200 Gbps network bandwidth  
- **p6e.48xlarge**: 3200 Gbps network bandwidth
- **trn1.32xlarge**: 800 Gbps network bandwidth

## Prerequisites

### For Slurm Clusters
- Functional Slurm cluster with GPU nodes
- Docker, [Pyxis](https://github.com/NVIDIA/pyxis) and [Enroot](https://github.com/NVIDIA/enroot) installed
- Shared filesystem mounted (typically `/fsx`)
- EFA drivers and AWS OFI NCCL installed

### For EKS Clusters
- Functional EKS cluster with GPU nodes
- NVIDIA device plugin deployed
- EFA device plugin deployed  
- Kubeflow MPI operator deployed
- Container registry access (ECR)

## Container and Script Preparation

### Get NCCL Tests from Repository

The NCCL tests are available in the [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training/tree/main/micro-benchmarks/nccl-tests).

```bash
# Clone the repository
git clone https://github.com/aws-samples/awsome-distributed-training.git
cd awsome-distributed-training/micro-benchmarks/nccl-tests

# Available resources:
# - nccl-tests.Dockerfile: Container build file
# - slurm/: Slurm job scripts
# - kubernetes/: Kubernetes manifests
# - README.md: Detailed instructions
```

### Container Build Configuration

The repository includes a comprehensive [NCCL-TESTS Dockerfile](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/nccl-tests.Dockerfile) with configurable versions:

| Variable | Default | Description |
|----------|---------|-------------|
| `GDRCOPY_VERSION` | v2.5.1 | GDRCopy version |
| `EFA_INSTALLER_VERSION` | 1.43.2 | EFA installer version |
| `AWS_OFI_NCCL_VERSION` | v1.16.3 | AWS OFI NCCL version |
| `NCCL_VERSION` | v2.27.7-1 | NCCL version |
| `NCCL_TESTS_VERSION` | v2.16.9 | NCCL Tests version |

## Slurm Implementation

### 1. Build and Prepare Container

```bash
# Build container
docker build -t nccl-tests:${TAG} -f nccl-tests.Dockerfile \
    --build-arg="EFA_INSTALLER_VERSION=${EFA_INSTALLER_VERSION}" \
    --build-arg="AWS_OFI_NCCL_VERSION=${AWS_OFI_NCCL_VERSION}" \
    --build-arg="NCCL_VERSION=${NCCL_VERSION}" \
    --build-arg="NCCL_TESTS_VERSION=${NCCL_TESTS_VERSION}" \
    .

# Convert to Enroot format
enroot import -o /fsx/nccl-tests.sqsh dockerd://nccl-tests:${TAG}
```

### 2. Use Provided Slurm Job Scripts

The repository includes ready-to-use Slurm job scripts:

- **[`slurm/nccl-tests-container.sbatch`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/slurm/nccl-tests-container.sbatch)**: NCCL test using container
- **[`slurm/nccl-tests-ami.sbatch`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/slurm/nccl-tests-ami.sbatch)**: Uses pre-installed NCCL from Deep Learning AMI

For advanced topology-aware testing:
- **[`slurm/topology-aware-nccl-tests/`](https://github.com/aws-samples/awsome-distributed-training/tree/main/micro-benchmarks/nccl-tests/slurm/topology-aware-nccl-tests)**: Advanced topology-aware NCCL tests with CSV export and automated submission scripts

Key configuration options:
- **Node count**: Modify `#SBATCH -N` parameter
- **Container image**: Set `IMAGE` variable path (for container version)
- **Test parameters**: Adjust `-b`, `-e`, `-f` flags for data size range

### 3. Advanced Topology-Aware Testing

For comprehensive testing with topology awareness and result analysis, use the topology-aware scripts:

- **[`submit_nccl_test_container.sh`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/slurm/topology-aware-nccl-tests/submit_nccl_test_container.sh)**: Automated submission script for container-based tests
- **[`submit_nccl_test_ami.sh`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/slurm/topology-aware-nccl-tests/submit_nccl_test_ami.sh)**: Automated submission script for AMI-based tests
- **[`process_nccl_results.sh`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/slurm/topology-aware-nccl-tests/process_nccl_results.sh)**: Results processing and CSV export

### 4. Run Tests

```bash
# Navigate to the NCCL tests directory
cd awsome-distributed-training/micro-benchmarks/nccl-tests/slurm

# Basic container test
sbatch nccl-tests-container.sbatch

# Basic AMI test  
sbatch nccl-tests-ami.sbatch

# Advanced topology-aware testing
cd topology-aware-nccl-tests
./submit_nccl_test_container.sh  # Follow prompts for configuration
```

## EKS Implementation

### 1. Build and Push Container

```bash
# Create ECR repository
ECR_REPOSITORY_NAME="nccl-tests"
aws ecr create-repository --repository-name ${ECR_REPOSITORY_NAME}

# Get repository URI
REPO_URI=$(aws ecr describe-repositories --query "repositories[?repositoryName=='${ECR_REPOSITORY_NAME}'].repositoryUri" --output text)
ECR_URI=${REPO_URI%"/${ECR_REPOSITORY_NAME}"}

# Build and push
docker build -t ${REPO_URI}:${TAG} -f nccl-tests.Dockerfile .
aws ecr get-login-password | docker login --username AWS --password-stdin ${ECR_URI}
docker push ${REPO_URI}:${TAG}
```

### 2. Use Provided Kubernetes Manifests

The repository includes a ready-to-use Kubernetes manifest at [`kubernetes/nccl-tests.yaml`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/kubernetes/nccl-tests.yaml).

Key configuration parameters to adjust:
- **`slotsPerWorker`**: Number of GPUs per node
- **`replicas`**: Number of worker nodes
- **`image`**: Container image URI
- **`nvidia.com/gpu`**: GPU resource requests
- **`vpc.amazonaws.com/efa`**: EFA adapter count
- **`node.kubernetes.io/instance-type`**: Target instance type

### 3. Deploy and Monitor

```bash
# Apply the MPIJob
kubectl apply -f nccl-tests-mpijob.yaml

# Monitor job progress
kubectl get mpijobs -w

# View logs
kubectl logs -f $(kubectl get pods -l job-name=nccl-tests -o name | grep launcher)

# Clean up
kubectl delete mpijob nccl-tests
```

## Understanding Results

### Sample Output Analysis

```
# NCCL Test Results
#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)       
     1048576        262144     float     sum      -1   4607.6  233.04  436.95      0   4565.6  235.18  440.96      0
     2147483648     536870912     float     sum      -1   9197.5  233.49  437.79      0   9195.2  233.54  437.89      0
```

### Key Metrics

- **algbw (Algorithm Bandwidth)**: Data size / time
- **busbw (Bus Bandwidth)**: Reflects inter-GPU communication speed
- **time**: Time to complete the operation in microseconds

### Performance Benchmarks

| Instance Type | Expected Bus Bandwidth | Typical algbw (2GB) |
|---------------|----------------------|-------------------|
| p4d.24xlarge  | ~300 GB/s           | ~200 GB/s        |
| p5.48xlarge   | ~400+ GB/s          | ~230+ GB/s       |
| p6e.48xlarge  | ~400+ GB/s          | ~250+ GB/s       |

## Troubleshooting and Diagnostics

### Bad Node Detection

1. **Run pairwise tests**:
```bash
# Test specific node pairs
sbatch -w node1,node2 nccl-tests.sbatch
sbatch -w node1,node3 nccl-tests.sbatch
```

2. **Check for failed jobs**:
```bash
sacct --format "JobID,JobName,State,ExitCode,NodeList"
```

3. **Isolate problematic nodes**:
```bash
# Test suspected bad node against known good node
sbatch -w suspected-bad-node,known-good-node nccl-tests.sbatch
```

### Common Issues and Solutions

1. **Low bandwidth performance**:
   - Check EFA interface configuration
   - Verify NCCL environment variables
   - Ensure proper GPU-EFA affinity

2. **Test failures or hangs**:
   - Check NCCL_DEBUG output for errors
   - Verify network connectivity between nodes
   - Check for hardware issues

3. **Inconsistent results**:
   - Run multiple iterations
   - Check for thermal throttling
   - Verify consistent cluster configuration

### Performance Optimization

1. **NCCL Environment Variables**:
```bash
export NCCL_TREE_THRESHOLD=0
export NCCL_ALGO=Ring,Tree
export NCCL_PROTO=Simple
```

2. **EFA Optimization**:
```bash
export FI_EFA_USE_DEVICE_RDMA=1
export FI_EFA_FORK_SAFE=1
```

3. **GPU Affinity**:
```bash
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
```

## Result Analysis and Processing

The repository includes tools for analyzing NCCL test results:

- **[`nccl_to_csv.py`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/nccl_to_csv.py)**: Convert NCCL test output to CSV format
- **[`process_nccl_results.sh`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccl-tests/slurm/topology-aware-nccl-tests/process_nccl_results.sh)**: Comprehensive result processing script

### Usage Example

```bash
# Run NCCL test and process results
sbatch nccl-tests-container.sbatch

# Convert output to CSV (after job completes)
python3 nccl_to_csv.py slurm-<job-id>.out > nccl_results.csv

# For topology-aware tests, use the automated processing
cd topology-aware-nccl-tests
./process_nccl_results.sh
```

## Next Steps

After successful NCCL testing:
1. Proceed to [GPU stress testing](./gpu-stress-testing.md)
2. Run [Trainium NCCOM tests](./nccom-tests.md) if using Trainium instances
3. Set up [continuous monitoring](../../04-add-ons/Observability/Observability.md) for ongoing performancelidation
4. Begin distributed training workloads with EKS or SLURM with confidence