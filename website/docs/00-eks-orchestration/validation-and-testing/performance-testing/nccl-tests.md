---
title: "NCCL Performance Tests"
sidebar_position: 1
---

# NCCL Performance Tests on EKS

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

## Troubleshooting

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
