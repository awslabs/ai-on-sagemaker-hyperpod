---
title: "NCCL Performance Tests"
sidebar_position: 1
---

# NCCL Performance Tests on Slurm

The [NCCL Tests](https://github.com/NVIDIA/nccl-tests) are a comprehensive testing suite that evaluates network performance between GPU instances using the NVIDIA Collective Communication Library. This is essential for validating cluster performance and troubleshooting issues before starting distributed training workloads.

## Overview

NCCL Tests provide:
- **Network bandwidth validation** between GPU instances
- **Latency measurements** for different collective operations
- **Scalability testing** across multiple nodes
- **Performance baseline establishment** for your cluster
- **Hardware issue detection** through systematic testing

### Network performance specifications

Network performance varies by instance type. Some examples include: 
- **p4d.24xlarge**: 400 Gbps network bandwidth
- **p5.48xlarge**: 3200 Gbps network bandwidth  
- **p6e.48xlarge**: 3200 Gbps network bandwidth
- **trn1.32xlarge**: 800 Gbps network bandwidth

You can find more details on the [Amazon EC2 documentation](https://docs.aws.amazon.com/ec2/latest/instancetypes/ac.html). And you can check which EFA version your instance type have [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types).

## Prerequisites

- Functional Slurm cluster with GPU nodes
- Docker, [Pyxis](https://github.com/NVIDIA/pyxis) and [Enroot](https://github.com/NVIDIA/enroot) installed
- Shared filesystem mounted (typically `/fsx`)
- EFA drivers and AWS OFI NCCL installed

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
| `EFA_INSTALLER_VERSION` | 1.47.0 | EFA installer version |
| `AWS_OFI_NCCL_VERSION` | efa-installer | AWS OFI NCCL version - included with the EFA Installer|
| `NCCL_VERSION` | v2.29.2-1 | NCCL version |
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

The average bus bandwidth output, shown at the end of the test, is an average bus bandwidth of all message sizes. This is a misleading metric as some message sizes might perform better or worse than others. You must understand your workload message size pattern and focus on the performance of that specific one. For most of HPC and AIML workloads, message sizes of 8G and 16G are the ones that matters.

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
sbatch -N 2 --array=0-7 nccl-tests.sbatch
```
the above command will submit 4 jobs and each job will run nccl-tests on 2 nodes (pair-wise). You can change `--array=` if you want to test on a different number of nodes (ex: `--array=0-63` to test on 64 nodes pair-wise.

2. **Check for failed jobs**:
```bash
sacct --format "JobID,JobName,State,ExitCode,NodeList"
```

3. **Check for delta in performance**:
First, let's create a bash script that will help us grep a specific message size and find the bus_bandwidth value:
```bash
cat >> validate_performance.sh << EOF
#!/bin/bash
#
# check_nccl_busbw.sh - Analyze NCCL test results for busbw outliers
#
# Greps the out-of-place busbw column for a specific message size across
# multiple NCCL test output files, computes the mean, and flags any result
# that deviates more than a given threshold (default 5%) from the mean.
#
# Usage:
#   ./check_nccl_busbw.sh /path/to/logs/*.out
#   ./check_nccl_busbw.sh -s 8589934592 -t 0.10 /path/to/logs/*.out
#
# Options:
#   -s MSG_SIZE   Message size in bytes to check (default: 17179869184)
#   -t THRESHOLD  Deviation threshold as a fraction (default: 0.05 = 5%)
#
set -euo pipefail
MSG_SIZE="17179869184"
THRESHOLD="0.05"
while getopts "s:t:h" opt; do
    case $opt in
        s) MSG_SIZE="$OPTARG" ;;
        t) THRESHOLD="$OPTARG" ;;
        h|*) echo "Usage: $0 [-s msg_size] [-t threshold] <files...>"; exit 0 ;;
    esac
done
shift $((OPTIND - 1))
if [ $# -eq 0 ]; then
    echo "Error: No files specified."
    echo "Usage: $0 [-s msg_size] [-t threshold] <files...>"
    exit 1
fi
FILES=("$@")
declare -a result_files=()
declare -a result_busbw=()
declare -a result_hosts=()
for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "Warning: File not found: $f (skipping)"
        continue
    fi
    # Extract out-of-place busbw (column 8) for the target message size
    busbw=$(grep -E "^ *${MSG_SIZE} " "$f" 2>/dev/null | awk '{print $8}')
    if [ -z "$busbw" ]; then
        echo "Warning: Message size ${MSG_SIZE} not found in $f (skipping)"
        continue
    fi
    # Extract hostname lines from the top of the file
    # (matches pattern like "p5en-dy-gpu-1: i-022b2b0f40726512e")
     hosts=$(head -10 "$f" 2>/dev/null | grep -oE 'i-[0-9a-f]+' || true)
    result_files+=("$f")
    result_busbw+=("$busbw")
    result_hosts+=("$hosts")
done
count=${#result_busbw[@]}
if [ "$count" -eq 0 ]; then
    echo "Error: No valid results found for message size ${MSG_SIZE}."
    exit 1
fi
# Compute mean
mean=$(printf '%s\n' "${result_busbw[@]}" | awk '{sum += $1} END {printf "%.4f", sum / NR}')
# Compute standard deviation
stddev=$(printf '%s\n' "${result_busbw[@]}" | awk -v mean="$mean" '{
    diff = $1 - mean; sumsq += diff * diff
} END { printf "%.4f", sqrt(sumsq / NR) }')
# Header
echo "============================================================"
echo "  NCCL All-Reduce busbw Analysis (out-of-place)"
echo "============================================================"
echo "Message size : ${MSG_SIZE} bytes"
echo "Files        : ${count}"
echo "Mean busbw   : ${mean} GB/s"
echo "Std dev      : ${stddev} GB/s"
echo "Threshold    : +/- $(awk "BEGIN {printf \"%.1f\", ${THRESHOLD} * 100}")% from mean"
echo "============================================================"
echo ""
outlier_count=0
for i in "${!result_busbw[@]}"; do
    deviation=$(awk "BEGIN {printf \"%.6f\", (${result_busbw[$i]} - $mean) / $mean}")
    abs_dev=$(awk "BEGIN {d = ${result_busbw[$i]} - $mean; printf \"%.6f\", (d < 0 ? -d : d) / $mean}")
    is_outlier=$(awk "BEGIN {print ($abs_dev > $THRESHOLD) ? 1 : 0}")
    if [ "$is_outlier" -eq 1 ]; then
        status="** OUTLIER **"
        outlier_count=$((outlier_count + 1))
    else
        status="OK"
    fi
    pct_dev=$(awk "BEGIN {printf \"%+.2f\", ${deviation} * 100}")
    echo "--- File: ${result_files[$i]}"
    echo "    busbw: ${result_busbw[$i]} GB/s  |  deviation: ${pct_dev}%  |  ${status}"
    echo "    Nodes:"
    if [ -n "${result_hosts[$i]}" ]; then
        echo "${result_hosts[$i]}" | sed 's/^/        /'
    else
        echo "        (no hostname info found)"
    fi
    echo ""
done
# Summary
echo "============================================================"
if [ "$outlier_count" -gt 0 ]; then
    echo "  RESULT: ${outlier_count} outlier(s) detected out of ${count} files"
else
    echo "  RESULT: All ${count} results within $(awk "BEGIN {printf \"%.0f\", ${THRESHOLD} * 100}")% tolerance"
fi
echo "============================================================"

EOF
```
Then you can run it `bash validate_performance.sh`. The output should be similar to this one:
```
Message size: 17179869184
Files analyzed: 8
Mean busbw: 365.2 GB/s
Threshold: +/- 0.05 (5%)
---
result_node1.txt    busbw=362.05    dev=-0.0086   OK
result_node2.txt    busbw=367.36    dev=0.0059    OK
result_node3.txt    busbw=310.00    dev=-0.1512   OUTLIER
...
```
Write down which files shows the outlier numbers so you can find the problematic nodes. They will be shown at the top 2 lines of that filename.

4. **Isolate problematic nodes**:
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
