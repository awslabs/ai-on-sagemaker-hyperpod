---
title: "Resiliency Overview"
sidebar_position: 1
---

# SageMaker HyperPod Resiliency Overview

:::info Orchestrator-Specific Guides
For testing and validating resiliency on your cluster, see:
- [Testing Resiliency with HyperPod EKS](/docs/eks-orchestration/validation-and-testing/resiliency/eks-resiliency)
- [Testing Resiliency with HyperPod Slurm](/docs/slurm-orchestration/validation-and-testing/resiliency/slurm-resiliency)
:::

SageMaker HyperPod is built for [resilient training](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpos-resiliency.html) with comprehensive health monitoring and automatic recovery capabilities. This section provides an overview of the resiliency features that apply to both HyperPod EKS and HyperPod Slurm orchestrators.

## Health Monitoring Agent

SageMaker HyperPod health-monitoring agent (HMA) continuously monitors the health status of each GPU-based or Trainium-based instance. When it detects any instance or GPU failures, the agent marks the instance as unhealthy.

The SageMaker HyperPod HMA performs the same health checks for both EKS and Slurm orchestrators, providing consistent monitoring across different orchestration platforms.

### Health Checks Performed by HMA

The SageMaker HyperPod health-monitoring agent performs comprehensive health checks across different hardware components:

#### NVIDIA GPUs
- **DCGM policy violation notifications**: Monitors all GPU-related policies from [NVIDIA DCGM](https://docs.nvidia.com/datacenter/dcgm/latest/user-guide/index.html#automate-gpu-management-policies)
- **NVIDIA SMI errors**: Parses output from [nvidia-smi](https://developer.nvidia.com/nvidia-system-management-interface) to determine GPU health
- **XID errors**: Monitors kernel logs for [XID messages](https://docs.nvidia.com/deploy/xid-errors/index.html) indicating hardware malfunctions
- **GPU Count validation**: Verifies expected GPU count matches actual count (e.g., 8 GPUs in ml.p5.48xlarge). Reboots node if mismatch detected
- **Various EC2 platform log errors**: Monitors Amazon EC2 generated logs for issues

#### AWS Trainium
- **Neuron monitor errors**: Checks output from AWS Neuron monitor for issues
- **Neuron node problem detector**: Uses outputs from the Neuron node problem detector for comprehensive health assessment
- **Neuron Device Count validation**: Verifies actual neuron device count matches expected count for instance type. Reboots node if mismatch detected
- **EC2 platform log monitoring**: Monitors Amazon EC2 generated logs for Trainium-specific issues

### Health Monitoring Agent Logs

The SageMaker HyperPod health-monitoring agent runs continuously on all HyperPod clusters and publishes detected health events to CloudWatch under the cluster log group `/aws/sagemaker/Clusters/`.

Detection logs are created as separate log streams named `SagemakerHealthMonitoringAgent` for each node. You can query these logs using CloudWatch Log Insights:

```sql
fields @timestamp, @message 
| filter @message like /HealthMonitoringAgentDetectionEvent/
```

Example output:
```json
{
  "level": "info",
  "ts": "2024-08-21T18:35:35Z",
  "msg": "NPD caught event: %v",
  "details": {
    "severity": "warn",
    "timestamp": "2024-08-22T20:59:29Z",
    "reason": "XidHardwareFailure",
    "message": "Node condition NvidiaErrorReboot is now: True, reason: XidHardwareFailure, message: \"NVRM: Xid (PCI:0000:b9:00): 71, pid=<unknown>, name=<unknown>, NVLink: fatal error detected on link 6\""
  },
  "HealthMonitoringAgentDetectionEvent": "HealthEvent"
}
```

## Basic Health Checks

SageMaker HyperPod performs orchestrator-agnostic basic health checks during cluster creation and updates. These checks monitor:

| **Health Check** | **Instance Type** | **Description** |
|------------------|-------------------|-----------------|
| DCGM policies | NVIDIA GPUs | Continuous monitoring of GPU-related policies from NVIDIA DCGM |
| NVIDIA SMI | NVIDIA GPUs | Parsing nvidia-smi output to determine GPU health |
| XID | NVIDIA GPUs | Monitoring kernel logs for XID messages indicating hardware malfunctions |
| Neuron sysfs | Trainium/Inferentia | Reading counters from Neuron sysfs propagated by the Neuron driver |
| EFA | All | Connectivity tests using all available EFA cards within the instance |
| DCGM Diagnostic | NVIDIA GPUs | DCGM diagnostics level 2 to exercise GPUs under pressure |
| CPU stress | All | Linux stress tool running multiple threads for 100% CPU utilization and I/O operations |

## Deep Health Checks

SageMaker HyperPod performs deep health checks during cluster creation and updates to ensure reliability and stability by thoroughly testing underlying hardware and infrastructure components.

### Instance-Level Deep Health Checks

| **Category** | **Utility Name** | **Instance Type** | **Description** |
|--------------|-------------------|-------------------|-----------------|
| Accelerator | GPU/NVLink count | GPU | Verifies GPU/NVLink counts |
| Accelerator | DCGM diagnostics level 4 | GPU | Assesses GPU health with DCGM diagnostics including memory tests |
| Accelerator | Neuron sysfs | Trainium | Determines Neuron device health by reading counters from Neuron sysfs |
| Accelerator | Neuron hardware check | Trainium | Runs training workload to test hardware functionality |
| Accelerator | NCCOM local test | Trainium | Evaluates collective communication performance on single Trainium nodes |
| Network | EFA | GPU and Trainium | Runs latency and bandwidth benchmarking on attached EFA devices |

### Cluster-Level Deep Health Checks

| **Category** | **Utility Name** | **Instance Type** | **Description** |
|--------------|-------------------|-------------------|-----------------|
| Accelerator | NCCL test | GPU | Verifies collective communication performance on multiple NVIDIA GPUs |
| Accelerator | NCCOM cluster test | Trainium | Verifies collective communication performance on multiple Trainium nodes |

### Deep Health Check Logs

#### Cluster-Level Logs
Stored in CloudWatch log group: `/aws/sagemaker/Clusters/<cluster_name>/<cluster_id>`
Log streams: `DeepHealthCheckResults/<log_stream_id>`

Example failure log:
```json
{
  "level": "error",
  "ts": "2024-06-18T21:15:22Z",
  "msg": "Encountered FaultyInstance. Replace the Instance. Region: us-west-2, InstanceType: p4d.24xlarge. ERROR:Bandwidth has less than threshold: Expected minimum threshold :80,NCCL Test output Bw: 30"
}
```

#### Instance-Level Logs
Stored locally at: `/var/log/aws/clusters/sagemaker-deep-health-check.log`

Access via SSH:
```bash
cat /var/log/aws/clusters/sagemaker-deep-health-check.log
```

Example outputs:

**Hardware Stress Test:**
```
2024-08-20T21:53:58Z info Executing Hardware stress check with command: stress-ng, and args: [--cpu 32 --vm 2 --hdd 1 --fork 8 --switch 4 --timeout 60 --metrics]
2024-08-20T21:54:58Z info stress-ng success
2024-08-20T21:54:58Z info GpuPci Count check success
```

**DCGM Stress Test:**
```
2024-08-20T22:25:02Z info DCGM diagnostic health summary: dcgmCheckLevel: 0 dcgmVersion: 3.3.7 gpuDriverVersion: 535.183.01, gpuDeviceIds: [2237] replacementRequired: false rebootRequired:false
```

**EFA Loopback Test:**
```
2024-08-20T22:26:28Z info EFA Loopback check passed for device: rdmap0s29 . Output summary is MaxBw: 58.590000, AvgBw: 32.420000, MaxTypicalLat: 30.870000, MinTypicalLat: 20.080000, AvgLat: 21.630000
```

## Automatic Node Recovery

During cluster creation or update, administrators can select node recovery options:

- **Automatic (Recommended)**: SageMaker HyperPod automatically reboots or replaces faulty nodes
- **None**: Health monitoring agent labels instances when faults are detected but does not initiate automatic recovery actions (not recommended)

Automatic node recovery is triggered by:
- Health-monitoring agent detections
- Basic health check failures  
- Deep health check failures