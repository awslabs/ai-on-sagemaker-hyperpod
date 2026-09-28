---
title: "GPU Stress Testing"
sidebar_position: 2
---

# GPU Stress Testing and Validation

GPU stress testing validates hardware stability, thermal management, and performance consistency by putting GPUs under sustained computational load. This guide focuses on "burning" GPUs to test their limits and detect potential hardware issues.

## Overview

GPU stress testing provides:
- **Hardware stability validation** under sustained load
- **Thermal throttling detection** and mitigation
- **Memory error detection** and validation
- **Power delivery validation** under peak loads
- **Performance consistency** verification across all GPUs

## Prerequisites

### NVIDIA GPU Testing
- NVIDIA GPUs (P4d, P5, P6e instances)
- NVIDIA drivers and CUDA toolkit
- DCGM (Data Center GPU Manager) - pre-installed on HyperPod
- Administrative access for hardware monitoring


## NVIDIA GPU Stress Testing

### 1. DCGM Diagnostic Tests

DCGM provides comprehensive GPU diagnostics and stress testing capabilities:

```bash
# Initialize DCGM and discover GPUs
dcgmi discovery -l

# Create a group for testing (optional)
dcgmi group -c stress_test_group
dcgmi group -g 1 -a 0,1,2,3,4,5,6,7  # Add all GPUs to group

# Run different levels of diagnostics
dcgmi diag -g 1 -r 1  # Level 1 (quick)
dcgmi diag -g 1 -r 2  # Level 2 (medium stress)  
dcgmi diag -g 1 -r 3  # Level 3 (intensive)

# Monitor GPU health
dcgmi health -g 1 -c
```

### 2. GPU Burn Tool

GPU Burn is a simple, effective tool for maximizing GPU usage using the [gpu-burn repository](https://github.com/wilicc/gpu-burn):

```bash
# Install GPU Burn
git clone https://github.com/wilicc/gpu-burn.git
cd gpu-burn
make

# Run stress test for different durations
./gpu_burn 60    # 1 minute test
./gpu_burn 300   # 5 minute test
./gpu_burn 1800  # 30 minute test

# Run on specific GPUs
CUDA_VISIBLE_DEVICES=0,1 ./gpu_burn 300
```


## Monitoring During Stress Tests

### Real-time GPU Monitoring

```bash
# Monitor GPU metrics continuously
watch -n 1 nvidia-smi

# Monitor with detailed metrics and logging
nvidia-smi --query-gpu=timestamp,name,temperature.gpu,power.draw,memory.used,memory.total,utilization.gpu \
           --format=csv -l 1 > gpu_stress_log.csv

# Monitor for thermal throttling
watch -n 1 'nvidia-smi --query-gpu=temperature.gpu,power.draw --format=csv,noheader,nounits | awk -F, "{if(\$1>85) print \"WARNING: GPU temp \"\$1\"°C\"}"'
```

### DCGM Monitoring

```bash
# Start DCGM daemon (if not running)
sudo nv-hostengine

# Monitor GPU health continuously
dcgmi health -c

# Monitor detailed metrics
dcgmi dmon -e 1001,1002,1003,1004,1005,1006 -c 100
```


## Stress Test Analysis

### Temperature Analysis

```bash
# Extract temperature statistics from nvidia-smi CSV
awk -F',' 'NR>1 {sum+=$3; if($3>max) max=$3; if(min=="" || $3<min) min=$3} END {print "Temp - Min:"min"°C, Max:"max"°C, Avg:"sum/(NR-1)"°C"}' gpu_stress_log.csv

# Check for thermal throttling events
awk -F',' 'NR>1 && $3>85 {print "WARNING: High temperature "$3"°C at "$1}' gpu_stress_log.csv
```

### Power Analysis

```bash
# Extract power statistics
awk -F',' 'NR>1 {sum+=$4; if($4>max) max=$4; if(min=="" || $4<min) min=$4} END {print "Power - Min:"min"W, Max:"max"W, Avg:"sum/(NR-1)"W"}' gpu_stress_log.csv
```

## Best Practices

### 1. Pre-Stress Checklist
- ✅ Verify cooling systems are operational
- ✅ Check power delivery capacity
- ✅ Ensure monitoring tools are configured
- ✅ Set up temperature alerts
- ✅ Plan for graceful shutdown procedures

### 2. During Stress Testing
- Monitor temperatures continuously (keep below 85°C)
- Watch for power throttling
- Check for memory errors
- Validate performance consistency
- Be ready to stop tests if temperatures spike

### 3. Post-Stress Analysis
- Review thermal profiles for hot spots
- Check for hardware errors in logs
- Validate all GPUs performed consistently
- Document any issues found
- Plan remediation for problematic hardware

## Troubleshooting

### High Temperatures
```bash
# Check cooling system status
sensors  # If available
nvidia-smi --query-gpu=temperature.gpu --format=csv

# Reduce stress test intensity
./gpu_burn 60  # Shorter duration
```

### Memory Errors
```bash
# Check for GPU memory errors
nvidia-smi --query-gpu=memory.ecc.errors.corrected.total,memory.ecc.errors.uncorrected.total --format=csv

# Run DCGM memory test
dcgmi diag -r 2  # Includes memory tests
```

### Performance Inconsistencies
```bash
# Check GPU clocks
nvidia-smi --query-gpu=clocks.gr,clocks.mem --format=csv

# Monitor for throttling
nvidia-smi --query-gpu=clocks_throttle_reasons.active --format=csv
```

## Next Steps

After successful GPU stress testing:
1. Document baseline thermal and performance characteristics
2. Set up continuous monitoring and alerting
3. Establish regular stress testing schedules
4. Create procedures for handling hardware failures
5. Proceed with confidence to production workloads