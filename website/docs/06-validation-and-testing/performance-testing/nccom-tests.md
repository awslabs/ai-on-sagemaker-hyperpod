---
title: "NCCOM Tests (Trainium)"
sidebar_position: 3
---

# NCCOM Tests for Trainium Instances

[nccom-test](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/tools/neuron-sys-tools/nccom-test.html) is a benchmarking tool for evaluating the performance of Collective Communication operations on Trainium instances (trn1 and inf2). It provides a fast way to validate your Neuron environment before running complex distributed training workloads.

## Overview

NCCOM Tests provide:
- **Collective communication performance** validation for Trainium instances
- **Multi-node communication** testing across Neuron devices
- **Bandwidth and latency measurements** for different data sizes
- **Correctness verification** of collective operations
- **Environment sanity checks** before training workloads

### Supported Operations

- **All-Reduce** (`all_reduce` / `allr`)
- **All-Gather** (`all_gather` / `allg`) 
- **Reduce-Scatter** (`reduce_scatter` / `redsct`)
- **Send-Receive** (`sendrecv`)
- **All-to-All** (`alltoall`)

## Prerequisites

### For Slurm Clusters
- Trainium instances (trn1.32xlarge, trn1n.32xlarge)
- Neuron SDK installed and configured
- Shared filesystem for coordination
- EFA drivers for multi-node communication

### For EKS Clusters
- Trainium node groups configured
- Neuron device plugin deployed
- EFA device plugin deployed
- Neuron SDK container images

## Understanding NCCOM Output

### Output Metrics

| Column | Description |
|--------|-------------|
| **size (B)** | Data size in bytes for the operation |
| **count (elems)** | Number of elements processed |
| **type** | Data type (uint8, fp16, bf16, fp32, etc.) |
| **time (us)** | P50 duration in microseconds |
| **algbw (GB/s)** | Algorithm bandwidth (size/time) |
| **busbw (GB/s)** | Bus bandwidth (independent of rank count) |
| **Avg bus bandwidth** | Average bus bandwidth across all sizes |

### Performance Expectations

For trn1.32xlarge instances:
- **Single node**: ~400-500 GB/s bus bandwidth
- **Multi-node**: ~300-400 GB/s depending on operation
- **Latency**: < 100 microseconds for small messages

## Slurm Implementation

## Slurm Implementation

### Use the Provided Slurm Script

The repository includes a ready-to-use Slurm job script:

**[`slurm/nccom-tests.sbatch`](https://github.com/aws-samples/awsome-distributed-training/blob/main/micro-benchmarks/nccom-tests/slurm/nccom-tests.sbatch)**

This script provides:
- **Multi-node NCCOM testing** (default: 2 nodes)
- **Configurable collective operations** (all_reduce, all_gather, reduce_scatter, sendrecv, alltoall)
- **Automatic host discovery** and coordination
- **Configurable test parameters** (data sizes, iterations, data types)

### Key Configuration Options

Edit the script to customize:
- **`#SBATCH --nodes=2`**: Number of nodes to test
- **`CC_OPS=all_reduce`**: Collective operation to test
- **`--minbytes 8 --maxbytes 512KB`**: Data size range
- **`--datatype fp32`**: Data type for testing
- **`--iters 5`**: Number of test iterations

### Run the Tests

```bash
# Navigate to the NCCOM tests directory
cd awsome-distributed-training/micro-benchmarks/nccom-tests/slurm

# Run the provided test
sbatch nccom-tests.sbatch

# Monitor results
tail -f logs/nccom-all_reduce_perf_<job-id>.out
```

### Customize for Different Tests

To test different collective operations, modify the `CC_OPS` variable in the script:

```bash
# Edit the script to test different operations
sed -i 's/CC_OPS=all_reduce/CC_OPS=all_gather/' nccom-tests.sbatch
sbatch nccom-tests.sbatch

# Or test reduce_scatter
sed -i 's/CC_OPS=all_gather/CC_OPS=reduce_scatter/' nccom-tests.sbatch
sbatch nccom-tests.sbatch
```

## EKS Implementation

### No Pre-built Kubernetes Manifests

For EKS deployments, you'll need to create your own Job or MPIJob manifests based on the Slurm script configuration.

### Key Configuration for EKS

When creating Kubernetes manifests, use these settings from the Slurm script:
- **Container image**: Use Neuron-enabled PyTorch containers
- **Resource requests**: `aws.amazon.com/neuroncore: 32` and `vpc.amazonaws.com/efa: 8`
- **Environment variables**: `NEURON_RT_NUM_CORES=32`, `FI_PROVIDER=efa`
- **Command**: Use the same `nccom-test` command structure from the Slurm script

### Simple EKS Test

For a basic single-node test on EKS:

```bash
kubectl run nccom-test \
  --image=763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-training-neuronx:2.1.2-neuronx-py310-sdk2.20.0-ubuntu20.04 \
  --restart=Never \
  --rm -it \
  -- nccom-test all_reduce -r 32 -b 1M -e 64M -f 2 -n 20 -d fp32
```

## Sample Output and Analysis

### Expected Output Format

```
nccom-test all_reduce -r 32 -b 1M -e 32M -f 2 -n 20 -d fp32

size(B)    count(elems)  type    time(us)   algbw(GB/s)  busbw(GB/s)
1048576    262144        fp32    2156.2     0.49         15.11
2097152    524288        fp32    3891.4     0.54         16.74
4194304    1048576       fp32    7234.1     0.58         17.94
8388608    2097152       fp32    13567.8    0.62         19.22
16777216   4194304       fp32    25789.3    0.65         20.15
33554432   8388608       fp32    49234.7    0.68         21.08

Avg bus bandwidth: 18.37 GB/s
```

### Performance Analysis

1. **Good Performance Indicators**:
   - Bus bandwidth > 15 GB/s for single node
   - Bus bandwidth > 10 GB/s for multi-node
   - Consistent performance across data sizes
   - No errors or timeouts

2. **Performance Issues**:
   - Bus bandwidth < 10 GB/s
   - High variance in timing
   - Errors or failed operations

## Troubleshooting

### Common Issues

1. **Neuron Runtime Errors**:
```bash
# Check Neuron runtime status
neuron-ls
neuron-top

# Verify Neuron cores are available
echo $NEURON_RT_NUM_CORES
echo $NEURON_RT_VISIBLE_CORES
```

2. **Multi-Node Communication Issues**:
```bash
# Check EFA interfaces
fi_info -p efa

# Verify network connectivity
ping <other-node-ip>

# Check Neuron communication setup
echo $NEURON_RT_ROOT_COMM_ID
```

3. **Performance Issues**:
```bash
# Check for thermal throttling
neuron-monitor

# Verify EFA configuration
cat /sys/class/infiniband/*/device/uevent
```

### Optimization Tips

1. **Environment Variables**:
```bash
export NEURON_RT_NUM_CORES=32
export NEURON_RT_VISIBLE_CORES=0-31
export NEURON_FUSE_SOFTMAX=1
```

2. **Data Type Selection**:
   - Use `bf16` for training workloads
   - Use `fp32` for accuracy-critical operations
   - Use `fp16` for inference workloads

3. **Batch Size Optimization**:
   - Test different data sizes to find optimal performance
   - Larger sizes generally show better bandwidth utilization

## Testing Multiple Operations

To test different collective operations systematically, you can modify and resubmit the provided script:

```bash
# Test different operations
for op in all_reduce all_gather reduce_scatter alltoall; do
    # Copy and modify the script for each operation
    cp nccom-tests.sbatch nccom-${op}.sbatch
    sed -i "s/CC_OPS=all_reduce/CC_OPS=${op}/" nccom-${op}.sbatch
    sed -i "s/job-name=nccom-all_reduce_perf/job-name=nccom-${op}/" nccom-${op}.sbatch
    
    # Submit the job
    sbatch nccom-${op}.sbatch
done
```

