---
title: "Installation and Usage Guide"
sidebar_position: 2
---

# HyperPod Training Operator Installation and Usage Guide

This guide covers the installation of the HyperPod training operator and provides examples for running distributed training jobs using examples from the [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training).

## Prerequisites

Before you use the HyperPod training operator, you must have completed the following prerequisites:


- Created a [HyperPod cluster with Amazon EKS orchestration](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-create-cluster.html).
- Installed the latest AMI on your HyperPod cluster. For more information, see [SageMaker HyperPod AMI releases](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-release-ami-eks.html) for Amazon EKS.
- Installed [cert-manager](https://cert-manager.io/docs/installation/).
- Set up the EKS Pod Identity Agent using the console. If you want to use the AWS CLI, use the following command:

``` bash
aws eks create-addon \
--cluster-name my-eks-cluster \
--addon-name eks-pod-identity-agent \
--region AWS Region
```

  

## Installation Methods

  

You can install the HyperPod training operator through three methods:

### SageMaker AI Console (Recommended)

The SageMaker AI console provides a one-click installation that automatically:
- Creates the IAM execution role
- Creates the pod identity association
- Installs the operator

1. Open the [Amazon SageMaker AI console](https://console.aws.amazon.com/sagemaker/)
2. Go to your cluster's details page
3. On the Dashboard tab, locate "Amazon SageMaker HyperPod training operator"
4. Choose **Install**

During installation, SageMaker AI creates an IAM execution role with permissions similar to the `AmazonSageMakerHyperPodTrainingOperatorAccess` managed policy.

### Amazon EKS Console

The EKS console installation is similar but doesn't automatically create the IAM execution role. You can choose to create a new role during the process with pre-populated information.

### AWS CLI
For programmatic installation with more customization options:

```bash
# Set up EKS Pod Identity Agent
aws eks create-addon \
--cluster-name my-eks-cluster \
--addon-name eks-pod-identity-agent \
--region <AWS_REGION>
```


### Validate Installation

Once installed, verify the HyperPod controller manager pod is running:

```bash
kubectl get pods -n aws-hyperpod
```

Expected output:
```
NAME                                                              READY   STATUS    RESTARTS   AGE
health-monitoring-agent-bj57k                                     1/1     Running   0          17d
health-monitoring-agent-plcvm                                     1/1     Running   0          17d
hp-training-operator-hp-training-controller-manager-775bdf47f2s   1/1     Running   0          2d21h
```

## Running Training Jobs

This example demonstrates how to run a HyperPod PytorchJob using the same FSDP example from the [awsome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training/tree/main/3.test_cases/pytorch/FSDP/kubernetes), but configured for the HyperPod Training Operator.

### 1. Clone the awsome-distributed-training Repository

```bash
git clone https://github.com/aws-samples/awsome-distributed-training.git
cd awsome-distributed-training/3.test_cases/pytorch/FSDP/kubernetes
```

### 2. Build and Push Docker Image

```bash
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
export AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/

# Build the container (note: this includes hyperpod-elastic-agent)
pushd ../
docker build -f Dockerfile ${DOCKER_NETWORK} -t ${REGISTRY}fsdp:pytorch2.7.1 .
popd

# Create registry if needed
REGISTRY_COUNT=$(aws ecr describe-repositories | grep \"fsdp\" | wc -l)
if [ "$REGISTRY_COUNT" == "0" ]; then
    aws ecr create-repository --repository-name fsdp
fi

# Login and push
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY
docker image push ${REGISTRY}fsdp:pytorch2.7.1
```

The [Dockerfile](https://github.com/aws-samples/awsome-distributed-training/blob/main/3.test_cases/pytorch/FSDP/Dockerfile) includes the HyperPod elastic agent installation:

```dockerfile
...
RUN pip install hyperpod-elastic-agent
...
```

### 3. Job Submission Methods

HyperPod PytorchJobs can be submitted via `kubectl` with a YAML manifest or via the [HyperPod CLI v3](https://github.com/aws/sagemaker-hyperpod-cli).

#### 3a. Job Submission via kubectl

The [llama3_1_8b-fsdp-hpto.yaml](https://github.com/aws-samples/awsome-distributed-training/blob/main/3.test_cases/pytorch/FSDP/kubernetes/llama3_1_8b-fsdp-hpto.yaml) file defines a HyperPod PytorchJob with robust error handling:

**Key Features:**
- **JobStart**: Fails if no "Loss:" appears in logs within first 4 minutes (240s)
- **JobHangingDetection**: Fails if gap between "Loss:" logs exceeds 10 minutes (600s)
- **Retry Policy**: 3 process restarts before full job restart, maximum 10 total retries

**For auto-resume from checkpoint**, add FSx for Lustre volumes and modify checkpoint paths:

```yaml
volumes:
  - name: fsx-storage
    persistentVolumeClaim:
      claimName: fsx-claim

volumeMounts:
  - name: fsx-storage
    mountPath: /fsx

# Update command args:
- '--checkpoint_dir=/fsx/checkpoints'
- '--resume_from_checkpoint=/fsx/checkpoints'
```

**Submit the job:**
```bash
envsubst < llama3_1_8b-fsdp-hpto.yaml | kubectl apply -f -
```

### 4. Monitor Training Jobs

**Install kubetail for log monitoring:**
```bash
curl -sL https://raw.githubusercontent.com/aws-samples/aws-do-eks/refs/heads/main/Container-Root/eks/ops/setup/install-kubetail.sh | sudo bash
```

**View logs:**
```bash
kubetail llama3
```

**Describe the HyperPodPytorchJob:**
```bash
kubectl describe hyperpodpytorchjob llama3-1-8b-fsdp
```

### 5. Testing Resiliency

Emulate an instance failure to test the operator's recovery capabilities:

```bash
export NODE=$(kubectl get nodes | awk 'NR>1 {print $1}' | shuf -n 1)
kubectl label node $NODE \
  sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReboot \
  --overwrite=true
```

Check the job status:
```bash
kubectl describe hyperpodpytorchjob
```

Expected output showing fault remediation:
```
Status:
  Conditions:
    Last Transition Time:  2025-08-04T22:06:18Z
    Status:                True
    Type:                  Created
    Last Transition Time:  2025-08-04T22:08:37Z
    Status:                True
    Type:                  PodsRunning
    Last Transition Time:  2025-08-04T22:08:44Z
    Message:               The fault of reason NodeFault was remediated in 94283 milliseconds.
    Reason:                Running
    Status:                True
    Type:                  Running
  Restart Count:           1
Events:
  Type     Reason     Age    From                             Message
  ----     ------     ----   ----                             -------
  Warning  NodeFault  117s   hyperpod-pytorch-job-controller  Found unhealthy node hyperpod-i-03d315d8cef22bd25
  Normal   Running    23s    hyperpod-pytorch-job-controller  The fault of reason NodeFault was remediated in 94283 milliseconds.
```

## Log Monitoring Configuration Parameters

The following table describes all possible log monitoring configurations:

| Parameter | Description |
|:---|:---|
| `jobMaxRetryCount` | Maximum number of restarts at the process level |
| `restartPolicy: numRestartBeforeFullJobRestart` | Maximum number of restarts at the process level before the operator restarts at the job level |
| `restartPolicy: evalPeriodSeconds` | The period of evaluating the restart limit in seconds |
| `restartPolicy: maxFullJobRestarts` | Maximum number of full job restarts before the job fails |
| `cleanPodPolicy` | Specifies the pods that the operator should clean. Accepted values are All, OnlyComplete, and None |
| `logMonitoringConfiguration` | The log monitoring rules for slow and hanging job detection |
| `expectedRecurringFrequencyInSeconds` | Time interval between two consecutive LogPattern matches after which the rule evaluates to HANGING |
| `expectedStartCutOffInSeconds` | Time to first LogPattern match after which the rule evaluates to HANGING |
| `logPattern` | Regular expression that identifies log lines that the rule applies to when the rule is active |
| `metricEvaluationDataPoints` | Number of consecutive times a rule must evaluate to SLOW before marking a job as SLOW |
| `metricThreshold` | Threshold for value extracted by LogPattern with a capturing group |
| `operator` | The inequality to apply to the monitoring configuration. Accepted values are gt, gteq, lt, lteq, and eq |
| `stopPattern` | Regular expression to identify the log line at which to deactivate the rule |

## Advanced Configuration Examples

### Testing Custom Log Monitoring

To test custom log monitoring configurations, modify your job's `logMonitoringConfiguration`:

```yaml
logMonitoringConfiguration:
  - name: JobStart
    logPattern: '.*Loss:.*'
    expectedStartCutOffInSeconds: 1  # Change from 240 to 1 for testing
```

This will trigger a `LogStateHanging_JobStart` error if training doesn't start within 1 second, allowing you to test the monitoring system.

### HyperPod Elastic Agent Arguments

The HyperPod elastic agent supports all PyTorch ElasticAgent arguments plus additional ones:

| Argument | Description | Default |
|----------|-------------|---------|
| `--shutdown-signal` | Signal to send to workers for shutdown | "SIGKILL" |
| `--shutdown-timeout` | Timeout between SIGTERM and SIGKILL | 30 |
| `--server-host` | Agent server address | "0.0.0.0" |
| `--server-port` | Agent server port | 8080 |
| `--server-log-level` | Agent server log level | "info" |
| `--server-shutdown-timeout` | Server shutdown timeout | 300 |
| `--pre-train-script` | Path to pre-training script | None |
| `--pre-train-args` | Arguments for pre-training script | None |
| `--post-train-script` | Path to post-training script | None |
| `--post-train-args` | Arguments for post-training script | None |

## Troubleshooting

### Installation Issues

**Incompatible HyperPod AMI**: Update to the latest version using the UpdateClusterSoftware API.

**Incompatible Task Governance Version**: Ensure HyperPod task governance is version v1.3.0-eksbuild.1 or higher.

**Missing Permissions**: Verify IAM permissions are correctly set up for the EKS Pod Identity Agent.

### Job Execution Issues

**Jobs Not Starting**: Check that the HyperPod elastic agent is properly installed in your training image.

**Log Monitoring Not Working**: Ensure training logs are emitted to `sys.stdout` and saved at `/tmp/hyperpod/`.

The key advantage of the HyperPod Training Operator is that jobs are restarted at the process level within container pods, rather than affecting all pods. This provides surgical recovery that keeps training running smoothly with minimal disruption.