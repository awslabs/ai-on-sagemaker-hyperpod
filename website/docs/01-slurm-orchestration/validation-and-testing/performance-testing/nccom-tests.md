---
title: "NCCOM Tests (Trainium)"
sidebar_position: 3
---

# NCCOM Tests for Trainium on Slurm

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

- Trainium instances (trn1.32xlarge, trn1n.32xlarge)
- Neuron SDK installed and configured
- Shared filesystem for coordination
- EFA drivers for multi-node communication

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

### Testing Multiple Operations

To test different collective operations systematically:

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

### Sample Output

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
