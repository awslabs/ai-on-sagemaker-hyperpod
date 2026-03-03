---
title : Troubleshooting Guide
sidebar_position : 0
---

# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with your HyperPod cluster.

## Quick Reference Table

| Issue Category | Orchestrator | Subject (Symptom) | Reason | Resolution | Link to Details |
|----------------|--------------|-------------------|--------|------------|-----------------|
| **Deployment** | Common | CloudFormation deployment failed, need detailed error | Nested stack structure hides root cause errors | Navigate through nested stacks to find failed resource | [Details](#finding-detailed-cloudformation-error-messages) |
| **Deployment** | Common | Cluster creation fails with capacity error | Insufficient capacity, wrong availability zone | Use Flexible Training Plans or reserved capacity, verify AZ matches reservation | [Details](#cluster-creation-failing-with-capacity-error) |
| **Deployment** | Common | Cluster creation fails with lifecycle script error | Script syntax errors, missing dependencies, S3 access issues | Review CloudWatch logs, verify S3 access, check script syntax | [Details](#cluster-creation-failed-with-lifecycle-script-execution-error) |
| **Deployment** | Common | EFA health checks did not run successfully | Missing security group self-referencing rule | Add outbound rule allowing all traffic to the security group itself | [Details](#efa-health-checks-did-not-run-successfully) |
| **Deployment** | EKS | Cluster is InService but not seeing instances | Continuous Provisioning mode behavior, instance creation failures | Check cluster events for instance creation status and errors | [Details](#cluster-is-inservice-status-but-not-seeing-instances) |
| **Deployment** | EKS | Cannot access EKS cluster with kubectl | IAM identity not configured in EKS access entries | Add IAM identity to access entries, associate access policy | [Details](#cannot-access-eks-cluster-with-kubectl) |
| **Deployment** | Common | SSM session not starting or getting error | SSM plugin not installed, wrong target format, incorrect region | Install SSM plugin, use HyperPod target format, verify region | [Details](#ssm-session-not-starting-or-getting-error) |
| **Node Management** | Slurm | Node not responding / Slurm says node is "down" | Network issues, slurmd daemon stopped, resource exhaustion | Check connectivity, verify slurmd status, check memory/disk | [Details](#node-not-responding--slurm-says-node-is-down) |
| **Node Management** | Slurm | Node shows "Node unexpectedly rebooted" | Node rebooted without Slurm being notified, slurmd not running | Resume node after verifying it's healthy, check slurmd status | [Details](#node-unexpectedly-rebooted) |
| **Node Management** | Slurm | Jobs stuck in PENDING/COMPLETING, nodes in wrong state | Controller cache issues, stale state, communication problems | Restart slurmctld to re-sync state | [Details](#jobs-stuck-in-pendingcompleting-nodes-in-wrong-state) |
| **Node Management** | Common | Node replacement not happening automatically | Auto-recovery disabled, capacity unavailable, quota limits | Check auto-recovery settings, verify capacity, review quotas | [Details](#node-replacement-not-happening-automatically) |
| **Node Management** | Common | Node replacement not happening even after manual trigger | Wrong command syntax, cluster state, IAM permissions, capacity issues | Verify command syntax, check cluster state, review IAM permissions | [Details](#node-replacement-not-happening-even-after-manual-trigger) |
| **Performance** | Common | NCCL timeouts | Network congestion, EFA issues, insufficient timeout value | Increase NCCL_TIMEOUT, verify EFA, check network connectivity | [Details](#nccl-timeouts) |
| **Performance** | Common | Uneven NCCL performance across nodes | Network topology differences, degraded EFA, instance variations | Check EFA bandwidth, verify instance types, use placement groups | [Details](#uneven-nccl-performance-depending-on-the-set-of-nodes) |
| **Performance** | Common | Poor filesystem performance | Insufficient throughput, wrong volume type, I/O bottleneck | Check filesystem metrics, increase throughput, optimize I/O operations | [Details](#poor-filesystem-performance) |
| **Memory** | Common | "Cannot allocate memory" at os.fork() | Insufficient shared memory, huge pages not configured for EFA | Set FI_EFA_USE_HUGE_PAGE=0, increase --shm-size, reduce num_workers | [Details](#cannot-allocate-memory-error-at-osfork) |
| **GPU** | Common | Suspecting GPU failure | Hardware failure, ECC errors, thermal throttling | Run nvidia-smi diagnostics, check ECC errors, drain node | [Details](#suspecting-gpu-failure) |
| **GPU** | Common | EFA/NCCL/CUDA/driver version mismatch | Incompatible versions, host/container mismatch | Check version compatibility, rebuild containers with matching versions | [Details](#efancclcudanvidia-driver-version-mismatch) |
| **Storage** | Common | Root volume exhausted, need to expand | Root volume limited to 100GB, cannot be expanded | Use secondary EBS (/opt/sagemaker), NVMe (/opt/dlami/nvme), FSx, or S3 | [Details](#root-volume-exhausted---how-to-expand-storage) |
| **Utilities** | Slurm | Need to find instance ID from node name | Node names use IP format, AWS operations need instance ID | Query resource_config.json or use HyperPod APIs | [Details](#how-to-identify-instance-id-from-slurm-node-name) |

## Troubleshooting Details

### Deployment Issues

#### Finding Detailed CloudFormation Error Messages

**Orchestrator**: Common (Slurm, EKS)

**Issue**: HyperPod cluster deployment via management console fails, but error message is not detailed enough to identify root cause

**Background**:
When you deploy a HyperPod cluster using the HyperPod management console, it creates a CloudFormation stack behind the scenes. This stack uses nested stacks to organize resources. The most relevant error message for the root cause is often buried in the nested stacks at the individual AWS resource level, not at the top-level stack.

**Resolution Steps**:

1. **Navigate to CloudFormation console**:
   - Go to https://console.aws.amazon.com/cloudformation
   - Ensure you're in the correct region where the cluster was being deployed

2. **Find the HyperPod stack**:
   - Look for a stack with a name related to your cluster
   - The stack status will show as "CREATE_FAILED" or "ROLLBACK_COMPLETE"

3. **Check the Events tab**:
   - Click on the failed stack
   - Go to the "Events" tab
   - Look for events with status "CREATE_FAILED"
   - Note: The error at this level may be generic like "Embedded stack failed"

4. **Navigate to nested stacks**:
   - In the "Resources" tab, look for resources of type "AWS::CloudFormation::Stack"
   - These are nested stacks
   - Click on the Physical ID (stack name) of any nested stack that shows "CREATE_FAILED" status
   - This will open the nested stack in a new view

5. **Drill down through nested stacks**:
   - Repeat step 4 for each level of nesting
   - Continue drilling down until you find a stack with no nested stacks, only AWS resources
   - Look for the specific resource that failed (not another nested stack)

6. **Find the failed resource**:
   - In the deepest nested stack, go to the "Events" tab
   - Look for the specific AWS resource that failed (e.g., AWS::SageMaker::Cluster, AWS::IAM::Role, AWS::Lambda::Function)
   - The "Status reason" column will show the detailed error message
   - This is typically the most useful error message for troubleshooting

7. **Common resource types and their errors**:
   - **AWS::SageMaker::Cluster**: Capacity errors, subnet issues, security group problems, lifecycle script failures
   - **AWS::IAM::Role**: Permission errors, trust relationship issues
   - **AWS::Lambda::Function**: Execution errors, timeout issues
   - **AWS::EC2::VPC**: CIDR conflicts, quota limits
   - **Custom::Resource**: Lambda-backed custom resource errors (check Lambda logs)

**Tips**:

- **Use the search/filter**: In the Events tab, you can filter by "Failed" status to quickly find errors
- **Check timestamps**: Look at the most recent failed events
- **Multiple failures**: If multiple resources failed, start with the earliest failure - later failures may be cascading effects
- **Custom resources**: If a Custom::Resource fails, check the associated Lambda function's CloudWatch logs for detailed error messages
- **Copy error messages**: Copy the full error message for searching documentation or contacting support

---

#### Cluster Creation Failing with Capacity Error

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Cluster creation fails with insufficient capacity error

**Common Error Messages**:
- "Insufficient capacity"
- "We currently do not have sufficient capacity in the Availability Zone you requested"
- "Cannot provision requested instances"

**Background**:
Depending on the instance type, region, and availability zone you choose, it can be challenging to allocate requested capacity on-demand, especially for large instance types (p4d, p5, etc.). Additionally, on-demand instances are not necessarily allocated in close proximity, which can impact network performance for distributed training workloads.

**Capacity Reservation Options**:

HyperPod supports three options for securing compute capacity:

**1. On-Demand Instances**
- **Best for**: Small instance types, short-term usage, experimental workloads
- **Pros**: No upfront commitment, immediate availability for common instance types
- **Cons**: 
  - Not guaranteed for large instance types
  - Instances may not be in close proximity (suboptimal network topology)
  - Not recommended for production workloads
  - Higher cost compared to reserved options

**2. Flexible Training Plans**
- **Best for**: Medium to large workloads with predictable schedules
- **How it works**: 
  - Query available capacity by instance type, instance count, and desired schedule
  - Self-service purchase at discounted prices
  - Capacity duration up to 180 days
- **Pros**: 
  - Guaranteed capacity for the reserved period
  - Discounted pricing compared to on-demand
  - Better network topology (instances allocated together)
- **Cons**: Requires planning ahead and commitment

**3. Reserved Capacity via AWS Account Team**
- **Best for**: Large-scale, long-term capacity needs
- **How it works**: Contact your AWS account team to reserve capacity
- **Pros**: 
  - Best option for large or long-term capacity reservations
  - Guaranteed capacity and optimal placement
  - Customized solutions for specific requirements
- **Cons**: Requires engagement with account team and longer lead time

**Resolution Steps**:

1. **If using On-Demand and facing capacity errors**:
   - Consider switching to Flexible Training Plans for guaranteed capacity
   - Try different availability zones within your region
   - Consider smaller instance types or fewer instances
   - Contact your AWS account team for capacity reservation options

2. **If using Flexible Training Plans or Reserved Capacity and still facing errors**:
   - **Verify TrainingPlanArn is specified**: For Flexible Training Plans, ensure you specified the TrainingPlanArn field in your cluster configuration with the ARN of the purchased training plan
   - **Verify the availability zone**: Ensure your instance group configuration specifies the correct availability zone where capacity was reserved
   - Verify the subnet ID corresponds to the availability zone where capacity was reserved
   - Contact your AWS account team to confirm the reservation details

---

#### Cluster Creation Failed with Lifecycle Script Execution Error

**Orchestrator**: Common (Slurm, EKS)

**Issue**: HyperPod cluster creation fails during lifecycle script execution

**Common Causes**:
- Syntax errors in lifecycle scripts
- Missing dependencies or packages
- S3 access issues for script retrieval
- Insufficient permissions for script operations
- Network connectivity problems

**Resolution Steps**:
1. Check CloudWatch logs for the cluster creation process:
   - **Log Group**: `/aws/sagemaker/Clusters/<cluster-name>/<cluster-id>`
     - Example: `/aws/sagemaker/Clusters/k8-3/gyazigf6kqq9`
   - **Log Stream**: `LifecycleConfig/<node-group-name>/<instance-id>`
     - Example: `LifecycleConfig/group-g5-8x/i-0df4aefe56f4ef3bc`
   - Look for error messages, stack traces, or failed commands in the logs
2. If logs are not available or empty, verify IAM permissions:
   - Check if the IAM execution role has CloudWatch Logs write permissions
   - Verify the IAM role has permissions to access the S3 bucket where lifecycle scripts are stored:
     - S3 read permissions (s3:GetObject, s3:ListBucket)
     - Confirm the S3 path is correct in cluster configuration
     - Check bucket permissions and IAM role policies
   - Ensure the S3 bucket policy allows the IAM role to read objects
3. Check for updated versions of default lifecycle scripts:
   - The lifecycle script version you're using may have known issues that have been fixed
   - Compare your scripts with the latest versions:
     - **HyperPod EKS**: https://github.com/aws-samples/awsome-distributed-training/tree/main/1.architectures/7.sagemaker-hyperpod-eks/LifecycleScripts/base-config
     - **HyperPod Slurm**: https://github.com/aws-samples/awsome-distributed-training/tree/main/1.architectures/5.sagemaker-hyperpod/LifecycleScripts/base-config
   - Review the commit history for bug fixes and improvements
   - Update to the latest version if available
4. Review script syntax and test locally if possible
5. Verify the script uses Linux line endings (LF, not CRLF):
   - Scripts created on Windows may have CRLF line endings which cause execution failures on Linux
   - Convert to LF using: `dos2unix script.sh` or your text editor's line ending conversion
   - Check line endings: `file script.sh` (should show "ASCII text" not "ASCII text, with CRLF line terminators")
6. Ensure script has proper shebang (e.g., `#!/bin/bash`)

---

#### EFA Health Checks Did Not Run Successfully

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Cluster creation fails with error "EFA health checks did not run successfully. Ensure that your VPC and security groups are properly configured before attempting to create a new cluster."

**Common Cause**:
- Security group is missing a self-referencing outbound rule that allows nodes to communicate with each other via EFA

**Resolution Steps**:
1. Identify the security group used for the HyperPod cluster
2. Add the required outbound rules to the security group:
   - **Rule 1 - Intra-SG Communication (Required for EFA)**:
     - Type: All traffic
     - Protocol: All (-1)
     - Destination: The security group itself (self-referencing)
     - Description: Allow traffic within the security group
   
   - **Rule 2 - Internet Access**:
     - Type: All traffic
     - Protocol: All (-1)
     - Destination: 0.0.0.0/0
     - Description: Allow traffic to internet (for AWS API calls, package downloads, etc.)

3. Verify the security group has the following inbound rules:
   - **Intra-SG Communication**:
     - Type: All traffic
     - Protocol: All (-1)
     - Source: The security group itself (self-referencing)

4. Ensure all nodes in the cluster use the same security group
5. After fixing the security group, retry cluster creation

**Reference Configuration**:
See the CloudFormation template at `eks/cloudformation/security-group-template.yaml` for the complete security group setup used by HyperPod.

**Prevention**:
- Always include self-referencing rules (both inbound and outbound) when creating security groups for HyperPod clusters
- Use the provided CloudFormation templates which include proper security group configuration
- Test security group configuration before cluster creation

---

#### Cluster is InService Status but Not Seeing Instances

**Orchestrator**: EKS

**Issue**: Cluster shows "InService" status but instances are not visible or not being created

**Common Cause**:
This is expected behavior when using Continuous Provisioning mode (available for HyperPod EKS only). In this mode:
- The cluster transitions to "InService" status before all instances are created
- Instance creation happens asynchronously after the cluster becomes InService
- Instance creation failures are not reported as cluster or instance group creation failures

**Note**: Continuous Provisioning mode and cluster events are available for HyperPod EKS only. These features are not yet available for HyperPod Slurm as of January 2026.

**Resolution Steps**:
1. Check cluster events for instance creation status:
   - **Via Management Console**: Navigate to https://console.aws.amazon.com/sagemaker/home#/cluster-management → Select your cluster → Events tab
   - **Via AWS CLI**:
     ```bash
     aws sagemaker list-cluster-events --cluster-name <cluster-name>
     ```
   - Look for events related to instance creation, provisioning status, and any error messages
2. Verify the cluster provisioning mode:
   ```bash
   aws sagemaker describe-cluster --cluster-name <cluster-name>
   ```
   Look for the provisioning configuration to confirm if Continuous Provisioning is enabled
3. Check HyperPod cluster node status:
   - **Via AWS CLI**:
     ```bash
     aws sagemaker list-cluster-nodes --cluster-name <cluster-name>
     ```
   - **Via Management Console**: Navigate to https://console.aws.amazon.com/sagemaker/home#/cluster-management → Select your cluster → View node details
   - Look for node health status, instance state, and creation timestamps
4. Review CloudWatch logs for instance creation attempts:
   - Log Group: `/aws/sagemaker/Clusters/<cluster-name>/<cluster-id>`
   - Check for recent log streams from lifecycle scripts: `LifecycleConfig/<node-group-name>/<instance-id>`
   - Look for errors during instance provisioning or lifecycle script execution
5. If instances are failing to create, check for common issues:
   - Insufficient capacity in the selected availability zones
   - Lifecycle script errors (see [Cluster Creation Failed with Lifecycle Script Execution Error](#cluster-creation-failed-with-lifecycle-script-execution-error))
   - IAM permission issues
   - Service quotas or limits

**Understanding Continuous Provisioning Mode**:
- Allows the cluster to become operational even if some instances fail to provision
- Provides faster cluster availability for partial deployments
- Requires monitoring cluster events and node status to track instance creation progress
- Failed instances can be replaced individually without affecting the overall cluster status

---

#### Cannot Access EKS Cluster with kubectl

**Orchestrator**: EKS

**Issue**: Unable to access HyperPod EKS cluster using kubectl, receiving authentication or authorization errors

**Common Error Messages**:
- "couldn't get current server API group list: the server has asked for the client to provide credentials"

**Common Cause**:
When using EKS's "IAM access entries" for access control, the IAM identity (user or role) you are using must be correctly configured in the access entries. If your IAM identity is not added or misconfigured, kubectl commands will fail with authentication or authorization errors.

**Resolution Steps**:

1. **Verify your current IAM identity**:
   ```bash
   aws sts get-caller-identity
   ```
   Note the ARN of the identity you're using (user or role)

2. **Configure access entries via EKS Console**:
   - Navigate to https://console.aws.amazon.com/eks/clusters
   - Select your HyperPod EKS cluster
   - Go to the "Access" tab
   - Under "IAM access entries", check if your IAM identity is listed
   - If not present, click "Create access entry":
     - Enter your IAM principal ARN
     - Select access policy (e.g., AmazonEKSClusterAdminPolicy for full access)
     - Choose access scope (cluster-wide recommended)
     - Click "Create"
   - If already present, verify the configuration:
     - Check that the access policies are correctly associated (e.g., AmazonEKSClusterAdminPolicy for full access)
     - Verify the namespace configuration if using namespace-scoped access

3. **Update kubeconfig** (if not already configured):
   ```bash
   aws eks update-kubeconfig \
     --name <cluster-name> \
     --region <region>
   ```

4. **Test access**:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

**Note**: 
- Access entries are the recommended method for managing EKS cluster access
- Ensure the IAM identity has the necessary EKS permissions in IAM policies
- Changes to access entries may take a few moments to propagate

---

#### SSM Session Not Starting or Getting Error

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Unable to start SSM session to HyperPod cluster nodes or receiving errors

**Common Causes**:
- SSM plugin not installed on development machine
- Incorrect SSM target name format
- Wrong AWS region configuration

**Resolution Steps**:
1. Install the AWS Systems Manager Session Manager plugin on your development machine:
   - Follow the official installation guide: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
   - Verify installation: `session-manager-plugin --version`

2. Use the correct HyperPod-specific SSM target name format:
   - **Standard format**: `sagemaker-cluster:<cluster-name>_<instance-group-name>-<instance-id>`
   - **Example**: `sagemaker-cluster:my-cluster_worker-group-i-0abc123def456789`
   - **Command**:
     ```bash
     aws ssm start-session --target sagemaker-cluster:<cluster-name>_<instance-group-name>-<instance-id>
     ```
   - **Note**: Do NOT use the EC2 instance ID directly (e.g., `i-0abc123def456789`) - you must use the HyperPod target format

3. Verify the AWS region is correctly configured:
   - Check your AWS CLI profile's default region:
     ```bash
     aws configure get region
     ```
   - Or set the region explicitly using environment variables:
     ```bash
     export AWS_REGION=us-west-2
     export AWS_DEFAULT_REGION=us-west-2
     ```
   - Or specify region in the command:
     ```bash
     aws ssm start-session --target <target> --region us-west-2
     ```
   - Ensure the region matches where your HyperPod cluster is deployed

4. Verify IAM permissions for SSM access:
   - Your IAM user/role needs the following permissions:
     - `ssm:StartSession`
     - `sagemaker:DescribeCluster`
     - `sagemaker:ListClusterNodes`
   - The cluster nodes must have the SSM agent running and proper IAM role attached

5. Check if the instance is running and accessible:
   ```bash
   aws sagemaker list-cluster-nodes --cluster-name <cluster-name>
   ```
   Verify the instance status is "Running" or "InService"

6. Test connectivity with verbose output:
   ```bash
   aws ssm start-session --target <target> --debug
   ```
   Review the debug output for specific error messages

**Common Error Messages**:
- "Target is not connected": Instance may be stopped, SSM agent not running, network connectivity issues, or incorrect target name format
- "Access denied": Verify IAM permissions for both your user and the instance role

**SSH over SSM**:

**Important**: Before using SSH, you must add your SSH public key to the `~/.ssh/authorized_keys` file on the target node.

You can configure SSH to use SSM by adding entries to your SSH config file (`~/.ssh/config`):
```
Host my-cluster-controller
  HostName sagemaker-cluster:abcdfe1234_controller-i-0abc123def456789
  User ubuntu
  IdentityFile ~/keys/my-key.pem
  ProxyCommand aws --profile default --region us-west-2 ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p
```

Then connect simply with:
```bash
ssh my-cluster-controller
```

**Helpful Tool**:
For easier SSM session management with HyperPod clusters, consider using the `hyperpod_ssm` tool:
- Repository: https://github.com/shimomut/sagemaker-solutions/tree/main/hyperpod_ssm
- Simplifies SSM target name construction and session management
- Provides convenient commands for listing nodes and starting sessions
- Handles the HyperPod-specific target format automatically

---

### Node Management Issues

#### Node Not Responding / Slurm Says Node is "Down"

**Orchestrator**: Slurm

**Issue**: Slurm node becomes unresponsive or shows as "down"

**Resolution Steps**:
1. Check node status: `sinfo -N -l` or `scontrol show node <node-name>`
2. If node shows "down" status, check the reason message:
   ```bash
   sinfo -o "%N %T %30E"
   ```
   This will display the node name, state, and reason for the current state
3. Check HyperPod cluster node status:
   - **Via AWS CLI**:
     ```bash
     aws sagemaker list-cluster-nodes --cluster-name <cluster-name>
     ```
   - **Via Management Console**: Navigate to https://console.aws.amazon.com/sagemaker/home#/cluster-management → Select your cluster → View node details
   - Look for node health status, instance state, and any error messages
4. Test connectivity to the node using multiple methods to identify what's working:
   - **PING**: `ping <node-ip-or-hostname>`
   - **Cross-node SSH**: From another node, try `ssh <node-ip-or-hostname>`
   - **SSM Session**: See [SSM Session Not Starting or Getting Error](#ssm-session-not-starting-or-getting-error) for the correct HyperPod target format
   - **Slurm srun**: `srun -w <node-name> hostname`
   
   By testing these variations, you can determine which communication paths are functional
5. If you can access the node, check system logs: `sudo journalctl -xe`
6. Verify slurmd daemon is running: `sudo systemctl status slurmd`
7. Check for out-of-memory or disk space issues: `free -h` and `df -h`
8. If disk space is full, identify what is consuming space:
   ```bash
   # Check disk usage by filesystem
   df -h
   
   # Find large directories
   sudo du -h --max-depth=1 / | sort -hr | head -20
   
   # Check common locations for large files
   sudo du -sh /var/log/* | sort -hr
   sudo du -sh /tmp/* | sort -hr
   sudo du -sh /home/*/* | sort -hr
   ```
9. Clean up disk space if needed:
   - Delete old log files: `sudo rm -f /var/log/*.log.* /var/log/*/*.gz`
   - Clear temporary files: `sudo rm -rf /tmp/*`
   - Clean package manager cache: `sudo apt-get clean` (Slurm) or `sudo yum clean all` (EKS)
   - Remove old container images if using Docker: `docker system prune -a`
10. Restart slurmd if needed: `sudo systemctl restart slurmd`
11. If node remains down, set it back to idle: `scontrol update nodename=<node-name> state=resume`
12. If none of the above steps resolve the issue, reboot the instance:
   ```bash
   aws sagemaker batch-reboot-cluster-nodes \
     --cluster-name <cluster-name> \
     --node-ids <instance-id>
   ```
13. If rebooting doesn't help, replace the node:
   ```bash
   aws sagemaker batch-replace-cluster-nodes \
     --cluster-name <cluster-name> \
     --node-ids <instance-id>
   ```

---

#### Node Unexpectedly Rebooted

**Orchestrator**: Slurm

**Issue**: Slurm node shows as "down" with reason "Node unexpectedly rebooted"

**Common Symptoms**:
- Node appears as "down" in `sinfo` output
- Reason message shows "Node unexpectedly rebooted"
- Node is actually running and accessible, but Slurm won't schedule jobs on it

**Common Causes**:
- Node was rebooted (manually or automatically) without notifying Slurm
- slurmd daemon stopped or crashed during reboot
- slurmd failed to start after reboot
- Network interruption during reboot prevented slurmd from re-registering with slurmctld

**Diagnostic Steps**:

1. **Check node status and reason**:
   ```bash
   sinfo -N -l
   scontrol show node <node-name>
   ```
   Look for "Reason=Node unexpectedly rebooted"

2. **Verify node is actually running**:
   ```bash
   # Try to ping the node
   ping <node-ip>
   
   # Try to SSH to the node
   ssh <node-name>
   ```

3. **Check if slurmd is running on the node**:
   ```bash
   # On the affected node
   sudo systemctl status slurmd
   ```

4. **Check slurmd logs for errors**:
   ```bash
   # On the affected node
   sudo journalctl -u slurmd -n 100
   ```

**Resolution Steps**:

1. **If slurmd is not running, start it**:
   ```bash
   # On the affected node
   sudo systemctl start slurmd
   sudo systemctl status slurmd
   ```

2. **Resume the node in Slurm**:
   ```bash
   # On the head node
   scontrol update nodename=<node-name> state=resume
   ```

3. **Verify node is back to idle state**:
   ```bash
   sinfo -N -l | grep <node-name>
   ```
   The node should now show as "idle" or "alloc" instead of "down"

4. **If node still shows as down, check for other issues**:
   ```bash
   # Check if node can communicate with controller
   scontrol ping
   
   # Check node configuration
   scontrol show node <node-name>
   ```

**Prevention**:

To avoid this issue in the future:
- Ensure slurmd is configured to start automatically on boot:
  ```bash
  sudo systemctl enable slurmd
  ```
- When rebooting nodes intentionally, drain them first:
  ```bash
  scontrol update nodename=<node-name> state=drain reason="Planned reboot"
  # Reboot the node
  # After reboot, resume the node
  scontrol update nodename=<node-name> state=resume
  ```
- Use HyperPod's batch-reboot-cluster-nodes command for managed reboots:
  ```bash
  aws sagemaker batch-reboot-cluster-nodes \
    --cluster-name <cluster-name> \
    --node-ids <instance-id>
  ```

**Note**: 
- This is a protective mechanism in Slurm to prevent scheduling jobs on nodes that may have lost state during an unexpected reboot
- Always verify the node is healthy before resuming it
- If the node continues to have issues, consider replacing it instead of resuming

---

#### Jobs Stuck in PENDING/COMPLETING, Nodes in Wrong State

**Orchestrator**: Slurm

**Issue**: Jobs stuck in PENDING or COMPLETING state, nodes showing incorrect states, or Slurm controller not responding properly

**Background**:
The slurmctld (Slurm Central Control Daemon) manages job scheduling, resource allocation, and communication with compute nodes. By design, slurmctld saves state to disk and restores it upon restart, allowing maintenance without losing pending or running jobs. Restarting slurmctld is a common fix for various controller-related issues.

**When to Restart slurmctld**:

**1. Job Scheduling and Resource Allocation Issues**
- **Jobs stuck in PENDING with REASON=RESOURCES**: Jobs remain queued despite available nodes. Restart forces queue re-evaluation
- **GRES (GPU/EFA) miscalculation**: Resources not released back to pool after job completion, causing future jobs to hang
- **Jobs stuck in COMPLETING state**: Jobs remain in COMPLETING indefinitely, especially after instance replacements. The controller "memorizes" the COMPLETING state and continues waiting even after node replacement

**2. Node State Problems**
- **Nodes stuck in "Unknown" or "Down" state**: Nodes returned from reboot but controller still thinks they're unavailable
- **Compute node communication failures**: slurmctld stops responding to `scontrol ping` or nodes can't communicate with head node
- **Node configuration changes**: After adding new nodes or changing processor counts

**3. Configuration Changes**
- **Applying slurm.conf changes**: After updating topology.conf or slurm.conf files, especially TCP listening settings or node additions/removals
- **After reconfiguration commands**: Following `scontrol reconfigure`, particularly for topology updates after node relaunches

**4. Controller Unresponsiveness**
- **slurmctld hangs or deadlocks**: Daemon becomes overwhelmed or unresponsive
- **Plugin/database issues**: Lost connection to slurmdbd or invalid RPC errors
- **Race conditions**: Specific version bugs causing daemon malfunction

**How to Restart**:

1. **Standard restart**:
   ```bash
   sudo systemctl restart slurmctld
   ```

2. **Verify service status**:
   ```bash
   sudo systemctl status slurmctld
   ```

3. **Check logs for issues**:
   ```bash
   sudo journalctl -u slurmctld -n 100
   ```

4. **If controller is completely hung** (kill and restart):
   ```bash
   sudo systemctl stop slurmctld
   sudo pkill -9 slurmctld  # If stop doesn't work
   sudo systemctl start slurmctld
   ```

**Important Notes**:

- **State preservation**: By default, slurmctld restarts with state preservation - running jobs continue
- **Clean start** (use with caution): If state file is corrupted, use `slurmctld -c` to purge all running jobs and node states
- **Verify after restart**: Check that nodes are in expected states and jobs are running properly:
  ```bash
  sinfo
  squeue
  scontrol show config | grep StateSaveLocation
  ```

**What Gets Preserved**:
- Running jobs continue execution
- Pending jobs remain in queue
- Node states are restored from saved state
- Job history and accounting data

**What Gets Reset**:
- Controller memory cache
- Stale communication channels
- Hung internal processes
- Resource allocation calculations

---

#### Node Replacement Not Happening Automatically

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Failed nodes are not being automatically replaced by HyperPod

**Resolution Steps**:
1. Check HyperPod cluster auto-recovery settings in SageMaker console or via CLI:
   ```bash
   aws sagemaker describe-cluster --cluster-name <cluster-name>
   ```
   Look for the auto-recovery configuration
2. Verify cluster is not in a failed state that prevents recovery
3. Check cluster events for auto-recovery information:
   - **Via Management Console**: Navigate to https://console.aws.amazon.com/sagemaker/home#/cluster-management → Select your cluster → Events tab
   - **Via AWS CLI**:
     ```bash
     aws sagemaker list-cluster-events --cluster-name <cluster-name>
     ```
   - Look for events related to node health, replacement attempts, and any failures
   - **Note**: Cluster events are available for HyperPod EKS. For HyperPod Slurm, this feature is not yet available as of January 2026
4. Check if HyperPod's health monitoring agent detected an issue and triggered resiliency actions:
   - **Check CloudWatch Logs for health monitoring agent**:
     - Log Group: `/aws/sagemaker/Clusters/<cluster-name>/<cluster-id>`
     - Log Stream: `SagemakerHealthMonitoringAgent/<node-group-name>/<instance-id>`
     - Example: `SagemakerHealthMonitoringAgent/group-g5-8x/i-0aa017cbf6c240f3f`
     - Look for detected issues and triggered actions
   - **For HyperPod Slurm**: Check if the node reason message indicates a resiliency action:
     ```bash
     sinfo -o "%N %T %30E"
     ```
     The reason message must be exactly "Action:Reboot" or "Action:Replace" for auto-recovery to trigger
   - **For HyperPod EKS**: Check node labels for resiliency actions:
     ```bash
     kubectl get nodes --show-labels
     kubectl describe node <node-name>
     ```
     Look for the following labels indicating resiliency actions have been triggered:
     - `sagemaker.amazonaws.com/node-health-status: UnschedulablePendingReplacement` - Node is marked for replacement
     - `sagemaker.amazonaws.com/node-health-status: UnschedulablePendingReboot` - Node is marked for reboot
     
     See: https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-resiliency-node-labels.html
5. Review CloudWatch logs for auto-recovery attempts:
   - Log Group: `/aws/sagemaker/Clusters/<cluster-name>/<cluster-id>`
   - Check for recent log streams from lifecycle scripts: `LifecycleConfig/<node-group-name>/<instance-id>`
   - If lifecycle script fails during auto-recovery, the new instance cannot be created and auto-recovery will fail
   - Look for error messages in the lifecycle script logs that might prevent successful node replacement
6. Confirm capacity is available for replacement instances in the selected availability zones
7. If you need to immediately recover from the failed instance, trigger manual reboot or replacement:
   - **Manual reboot**:
     ```bash
     aws sagemaker batch-reboot-cluster-nodes \
       --cluster-name <cluster-name> \
       --node-ids <instance-id>
     ```
   - **Manual replacement**:
     ```bash
     aws sagemaker batch-replace-cluster-nodes \
       --cluster-name <cluster-name> \
       --node-ids <instance-id>
     ```

---

#### Node Replacement Not Happening Even After Manual Trigger

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Manual node replacement command fails or doesn't complete

**Resolution Steps**:
1. Use the recommended batch commands instead of legacy methods:
   - **Recommended**: Use `batch-replace-cluster-nodes` or `batch-reboot-cluster-nodes` commands
   - **Legacy methods** (not recommended): Setting node status in Slurm or node labels in Kubernetes
   - The new batch commands provide clear success/failure messages indicating whether the service accepted the request
2. Check HyperPod cluster node status:
   - **Via AWS CLI**:
     ```bash
     aws sagemaker list-cluster-nodes --cluster-name <cluster-name>
     ```
   - **Via Management Console**: Navigate to https://console.aws.amazon.com/sagemaker/home#/cluster-management → Select your cluster → View node details
   - Look for node health status, instance state, and any error messages
3. Check cluster events for replacement information:
   - **Via Management Console**: Navigate to https://console.aws.amazon.com/sagemaker/home#/cluster-management → Select your cluster → Events tab
   - **Via AWS CLI**:
     ```bash
     aws sagemaker list-cluster-events --cluster-name <cluster-name>
     ```
   - Look for events related to the replacement request, node status changes, and any error messages
   - **Note**: Cluster events are available for HyperPod EKS. For HyperPod Slurm, this feature is not yet available as of January 2026
4. Verify the replacement command syntax:
   ```bash
   aws sagemaker batch-replace-cluster-nodes \
     --cluster-name <cluster-name> \
     --node-ids <instance-id>
   ```
5. Check the command output for error messages
6. Verify the instance ID is correct and belongs to the cluster:
   ```bash
   aws sagemaker list-cluster-nodes --cluster-name <cluster-name>
   ```
7. Ensure the cluster is in a state that allows node replacement (not in "Creating" or "Deleting" state)
8. Review CloudWatch logs for replacement attempts:
   - Log Group: `/aws/sagemaker/Clusters/<cluster-name>/<cluster-id>`
   - Check for recent log streams from lifecycle scripts: `LifecycleConfig/<node-group-name>/<instance-id>`
   - If lifecycle script fails during replacement, the new instance cannot be created and replacement will fail
   - Look for error messages in the lifecycle script logs that might prevent successful node replacement
9. Verify capacity is available for the instance type in the target availability zone

---

### GPU and Accelerator Issues

#### Suspecting GPU Failure

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Training jobs fail or produce incorrect results, GPU errors in logs

**Common Symptoms**:
- CUDA errors in application logs
- Training produces NaN or incorrect results
- GPU memory errors or allocation failures
- System crashes during GPU-intensive operations
- High temperatures or thermal throttling

**Diagnostic Steps**:
1. Check GPU status: `nvidia-smi -q` and look for errors
2. Check for ECC errors: `nvidia-smi -q | grep -A 5 "ECC Errors"`
3. Monitor temperature and power: `nvidia-smi dmon -s pucvmet`
4. Run DCGM diagnostic tests for comprehensive validation
5. Run GPU burn tests to stress test under sustained load
6. Monitor for thermal throttling and memory errors during stress tests

**Resolution Steps**:
1. Document baseline thermal and performance characteristics
2. If GPU shows errors or high temperatures, drain the node from scheduler
3. Analyze temperature, power draw, and performance consistency
4. Document GPU serial number, error details, and test results
5. Contact AWS Support for hardware replacement
6. Replace the node once new hardware is available

**Detailed Guides**:
- [GPU Stress Testing](./validation-and-testing/performance-testing/gpu-stress-testing)

---

#### EFA/NCCL/CUDA/Nvidia Driver Version Mismatch

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Training fails with EFA or NCCL errors, performance degradation

**Common Symptoms**:
- NCCL initialization failures
- EFA device not found errors
- CUDA device not initialized
- Unexpected performance drops
- Segmentation faults during distributed training
- Training works on host but fails in container, or vice versa

**Common Causes**:
- Incompatible versions between CUDA, NCCL, EFA, and drivers
- CUDA driver and nvcc compiler version mismatch
- Mismatch between host and container environments
- Missing or incorrectly mounted EFA libraries in containers
- Different PyTorch/TensorFlow versions between host and container

**Diagnostic Steps**:
1. Run PyTorch environment validation to check CUDA, NCCL, MPI availability
2. Run EFA validation script to check EFA installer, libfabric, AWS OFI NCCL versions
3. Check CUDA driver vs compiler version: `nvidia-smi` vs `nvcc --version`
4. Verify NVLink status and topology: `nvidia-smi nvlink --status`
5. Compare versions between host and container environments
6. Check if EFA interfaces are found and properly configured

**Resolution Steps**:
1. Ensure CUDA driver and nvcc compiler versions match
2. Check version compatibility documentation:
   - EFA installer (including libnccl-ofi) and NCCL compatibility: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-changelog.html
   - NVIDIA driver and CUDA toolkit compatibility: https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/
3. Verify version compatibility using the EFA compatibility matrix
4. For containers: mount EFA libraries and devices properly
5. Verify LD_LIBRARY_PATH includes EFA and CUDA libraries
6. Initialize CUDA devices if needed (may require reboot)
7. Match PyTorch/TensorFlow versions between host and container
8. Rebuild containers with compatible versions from the compatibility matrix

**Detailed Guides**:
- [PyTorch Environment Validation](/docs/eks-orchestration/validation-and-testing/environment-validation/pytorch-environment-validation)
- [EFA and Network Stack Validation](/docs/eks-orchestration/validation-and-testing/environment-validation/efa-validation)
- [Troubleshoot NCCL and CUDA](./validation-and-testing/nccl-cuda-validation/Troubleshoot%20NCCL%20and%20CUDA)

---

### Performance Issues

#### NCCL Timeouts

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Distributed training fails with NCCL timeout errors

**Common Error Messages**:
- "NCCL timeout in call to..."
- "NCCL communicator was aborted"
- "Net/IB : Got completion with error"

**Diagnostic Steps**:
1. Enable NCCL debug logging: `export NCCL_DEBUG=INFO`
2. Verify EFA adapters are working: `fi_info -p efa`
3. Run pairwise NCCL tests between nodes to identify problematic connections
4. Check for security group restrictions blocking inter-node traffic
5. Monitor for test failures or hangs that indicate network issues

**Resolution Steps**:
1. Increase NCCL timeout if needed: `export NCCL_TIMEOUT=3600`
2. Verify EFA is being used: `export FI_EFA_USE_DEVICE_RDMA=1`
3. Check and fix security group rules to allow all traffic between nodes
4. Isolate and drain problematic nodes showing low bandwidth
5. Reduce batch size or adjust parallelism if memory pressure exists

**Detailed Guides**:
- [NCCL Performance Tests](/docs/eks-orchestration/validation-and-testing/performance-testing/nccl-tests)
- [Troubleshoot NCCL and CUDA](./validation-and-testing/nccl-cuda-validation/Troubleshoot%20NCCL%20and%20CUDA)

---

#### Uneven NCCL Performance Depending on the Set of Nodes

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Training performance varies significantly based on which nodes are allocated

**Common Causes**:
- Network topology differences between nodes
- Degraded EFA performance on some nodes
- Mixed instance types or generations
- CPU frequency scaling differences

**Diagnostic Steps**:
1. Check network topology: `nvidia-smi topo -m`
2. Verify EFA configuration on all nodes: `fi_info -p efa`
3. Run pairwise NCCL bandwidth tests to identify slow node pairs
4. Check for mixed instance types or generations
5. Monitor for inconsistent results across multiple test runs

**Resolution Steps**:
1. Run comprehensive NCCL all-reduce tests across all nodes
2. Use topology-aware testing scripts to systematically identify bad nodes
3. Check failed jobs and isolate problematic nodes
4. Configure EFA optimization settings and GPU affinity
5. Drain underperforming nodes and use placement groups for consistency

**Detailed Guides**:
- [NCCL Performance Tests](/docs/eks-orchestration/validation-and-testing/performance-testing/nccl-tests)

---

#### Poor Filesystem Performance

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Slow I/O operations, training bottlenecked by data loading, checkpoint saving, or loading executables and scripts

**Resolution Steps**:

1. **Check performance metrics on CloudWatch**:
   - Navigate to CloudWatch console and select your filesystem
   - Monitor key metrics: IOPS, throughput, data read/write bytes
   - Look for metrics hitting their limits or showing sustained high usage

2. **Check provisioned performance configuration**:
   - **FSx for Lustre**: Review throughput per TiB setting
   - **FSx for OpenZFS**: Check provisioned IOPS and throughput
   - **EBS volumes**: Verify volume type (gp3, io2) and provisioned IOPS/throughput
   - Compare current configuration against your workload requirements

3. **Investigate bottlenecks**:
   - If metrics show bottlenecks, identify what operations are causing high I/O:
     - Check which processes or jobs are performing heavy I/O
     - Review application logs for I/O patterns
     - Use filesystem-specific monitoring tools
   - Determine if the bottleneck is legitimate workload demand or inefficient I/O patterns

4. **Consider upgrading provisioned performance**:
   - If workload legitimately needs more performance, increase:
     - FSx for Lustre: Increase storage capacity (throughput scales with size)
     - FSx for OpenZFS: Increase provisioned IOPS/throughput
     - EBS: Upgrade volume type or increase provisioned IOPS/throughput

5. **Understand filesystem performance characteristics**:
   - AWS offers multiple filesystem options with different characteristics:
     - **FSx for Lustre**: High-performance parallel filesystem, best for large sequential I/O
     - **FSx for OpenZFS**: Good for mixed workloads, supports snapshots and cloning
     - **EBS**: Block storage, good for single-instance workloads
     - **Instance store (NVMe)**: Highest performance but non-persistent
   - Choose the filesystem that matches your I/O patterns

6. **Consider switching filesystem type**:
   - For HyperPod Slurm: The default lifecycle script offers an option to use FSx for OpenZFS instead of Lustre for home directories
   - Evaluate if a different filesystem type better suits your workload:
     - Small random I/O → Consider OpenZFS
     - Large sequential I/O → Lustre is optimal
     - Temporary high-performance data → Use NVMe instance storage

### Memory Issues

#### "Cannot Allocate Memory" Error at os.fork()

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Training fails with "OSError: [Errno 12] Cannot allocate memory" during `os.fork()` operations

**Common Symptoms**:
- PyTorch DataLoader with multiple workers fails when forking processes
- Error occurs specifically at `os.fork()` call
- "Failed to register memory" errors during EFA initialization
- Segmentation faults during NCCL operations
- Training crashes when using EFA with multi-process data loading

**Common Causes**:
- Insufficient shared memory (/dev/shm) for forked processes
- Huge pages not configured properly, causing EFA memory registration to fail during fork
- Too many DataLoader workers attempting to fork
- Large memory footprint in parent process before fork

**Resolution Steps**:
1. Set `FI_EFA_USE_HUGE_PAGE=0` environment variable:
   ```bash
   export FI_EFA_USE_HUGE_PAGE=0
   ```
   Add to job script, container environment, or `/etc/environment` for persistent setting
2. Increase shared memory size for containers:
   ```bash
   # For Docker containers
   docker run --shm-size=8g ...
   
   # For Kubernetes pods, add to pod spec:
   volumes:
   - name: dshm
     emptyDir:
       medium: Memory
       sizeLimit: 8Gi
   ```
3. Reduce number of DataLoader workers: `num_workers=4` instead of higher values
4. Reduce batch size to lower memory pressure
5. Use `persistent_workers=True` to avoid recreating workers
6. Set `pin_memory=False` if not needed
7. Check available memory: `free -h` and `/dev/shm` usage: `df -h /dev/shm`
8. Verify huge pages configuration: `cat /proc/meminfo | grep Huge`
9. If huge pages are needed for other workloads, configure them properly:
   ```bash
   # Check current huge pages
   cat /proc/sys/vm/nr_hugepages
   # Set huge pages (requires root)
   echo 1024 | sudo tee /proc/sys/vm/nr_hugepages
   ```
   Only use `FI_EFA_USE_HUGE_PAGE=1` if huge pages are properly configured

---

### Storage Management

#### Root Volume Exhausted - How to Expand Storage

**Orchestrator**: Common (Slurm, EKS)

**Issue**: Running out of disk space on the root volume, need more storage capacity

**Important to Know**:
You cannot configure the size of the primary EBS root volume in HyperPod - it is fixed at 100GB. This applies to all HyperPod clusters, and there is no way to change this size even when creating a new cluster.

**Available Storage Options**:

HyperPod provides alternative storage locations that you should use instead of the root volume:

1. **Secondary EBS Volume** (Configurable per instance group)
   - Mount point: `/opt/sagemaker`
   - Size is configurable for each instance group
   - Can be configured when creating new instance groups (even after cluster creation)

2. **NVMe Instance Storage** (Available on large instance types)
   - Mount point: `/opt/dlami/nvme`
   - High-performance local storage
   - Available on instance types like p4d, p5, etc.

3. **FSx for Lustre Filesystem**
   - Shared across all cluster nodes
   - High-performance parallel filesystem
   - Persistent storage shared across all nodes

4. **FSx for OpenZFS Filesystem**
   - Shared across all cluster nodes
   - High-performance filesystem with snapshots and cloning capabilities
   - Persistent storage shared across all nodes

5. **Amazon S3**
   - Object storage for large datasets
   - Fully persistent and durable

**Default Configuration**:

The default HyperPod lifecycle scripts automatically configure container runtimes to use alternative storage:
- **HyperPod Slurm**: Docker and containerd are configured to use `/opt/sagemaker` or `/opt/dlami/nvme`
- **HyperPod EKS**: Containerd and kubelet are configured to use `/opt/sagemaker` or `/opt/dlami/nvme`

This prevents container images and layers from filling up the root volume.

**Resolution Steps**:

1. **Check current disk usage**:
   ```bash
   # Check all mounted filesystems
   df -h
   
   # Identify what's consuming space on root volume
   sudo du -h --max-depth=1 / | sort -hr | head -20
   ```

2. **Redirect application data to secondary EBS volume**:
   ```bash
   # Use /opt/sagemaker for application data
   export APP_DATA_DIR=/opt/sagemaker/my-app-data
   mkdir -p $APP_DATA_DIR
   
   # Redirect logs
   export LOG_DIR=/opt/sagemaker/logs
   ```

3. **Use NVMe storage for temporary/scratch data**:
   ```bash
   # Use /opt/dlami/nvme for temporary files
   export TMPDIR=/opt/dlami/nvme/tmp
   mkdir -p $TMPDIR
   
   # Redirect cache directories
   export TORCH_HOME=/opt/dlami/nvme/torch_cache
   export HF_HOME=/opt/dlami/nvme/huggingface_cache
   ```

4. **Configure training scripts to use alternative storage**:
   ```python
   # In your training script
   checkpoint_dir = "/opt/sagemaker/checkpoints"
   cache_dir = "/opt/dlami/nvme/cache"
   ```

5. **Clean up root volume if already full**:
   ```bash
   # Remove old logs
   sudo rm -f /var/log/*.log.* /var/log/*/*.gz
   
   # Clean package manager cache
   sudo apt-get clean  # For Slurm (Ubuntu)
   sudo yum clean all  # For EKS (Amazon Linux)
   
   # Remove old container images (if applicable)
   docker system prune -a
   ```

6. **For Kubernetes pods, configure volume mounts**:
   ```yaml
   volumes:
   - name: secondary-ebs
     hostPath:
       path: /opt/sagemaker
   - name: nvme-storage
     hostPath:
       path: /opt/dlami/nvme
   
   volumeMounts:
   - name: secondary-ebs
     mountPath: /workspace
   - name: nvme-storage
     mountPath: /tmp
   ```

**Best Practices**:

- **Plan ahead**: Configure secondary EBS volume size appropriately during cluster creation
- **Use appropriate storage**: 
  - Persistent data → Secondary EBS or FSx
  - Temporary data → NVMe storage
  - Large datasets → FSx or S3
- **Monitor disk usage**: Set up CloudWatch alarms for disk space
- **Avoid root volume**: Never save large files or datasets to the root volume
- **Container images**: Ensure container runtime uses `/opt/sagemaker` or `/opt/dlami/nvme`
- **Environment variables**: Set cache directories to point to alternative storage:
  ```bash
  export TORCH_HOME=/opt/sagemaker/torch_cache
  export HF_HOME=/opt/sagemaker/huggingface_cache
  export TRANSFORMERS_CACHE=/opt/sagemaker/transformers_cache
  ```

**Prevention**:

When creating a HyperPod cluster or adding instance groups, configure the secondary EBS volume size based on your needs:
- Size can be configured differently for each instance group
- New instance groups can be added after cluster creation with appropriate storage
- Consider the size of container images you'll use
- Account for logs, checkpoints, and temporary files
- Add buffer for unexpected growth (recommend 2-3x your estimated needs)

---

### Utilities and How-To

#### How to Identify Instance ID from Slurm Node Name

**Orchestrator**: Slurm

**Issue**: Need to find the EC2 instance ID (e.g., `i-abcd12345678`) from a Slurm node name (e.g., `ip-10-1-123-45`)

**Background**:
On HyperPod Slurm clusters, nodes are named using their private IP addresses in the format `ip-10-1-123-45`. However, many AWS operations (SSM sessions, node replacement, CloudWatch logs) require the EC2 instance ID. This guide shows how to map between node names and instance IDs.

**Resolution Steps**:

**Option 1: Query resource_config.json on Head Node**

On the head node, the resource configuration file contains the mapping between IP addresses and instance IDs:

```bash
# Extract the IP address from the node name
# Example: ip-10-1-123-45 -> 10.1.123.45
NODE_NAME="ip-10-1-123-45"
IP_ADDRESS=$(echo $NODE_NAME | sed 's/ip-//; s/-/./g')

# Search for the instance ID in the resource config
sudo cat /opt/ml/config/resource_config.json | jq | grep -A 3 "$IP_ADDRESS"
```

This will show the instance details including the instance ID.

**Option 2: Use HyperPod Service APIs**

Use the HyperPod `list-cluster-nodes` and `describe-cluster-node` APIs to get node information:

```bash
# List all nodes in the cluster
aws sagemaker list-cluster-nodes --cluster-name <cluster-name>

# Describe a specific node
aws sagemaker describe-cluster-node \
  --cluster-name <cluster-name> \
  --node-id <instance-id>
```

**Recommended Tool**:

For easier lookup, use the `dump_cluster_nodes_info.py` tool from the awsome-distributed-training repository:
- Repository: https://github.com/aws-samples/awsome-distributed-training/blob/main/1.architectures/5.sagemaker-hyperpod/tools/dump_cluster_nodes_info.py
- This tool dumps all HyperPod node information into a CSV file
- You can easily lookup instance IDs from IP addresses or node names
- The CSV includes: instance ID, private IP, node name, instance type, availability zone, and status

**Usage Example**:
```bash
# Download the tool
wget https://raw.githubusercontent.com/aws-samples/awsome-distributed-training/main/1.architectures/5.sagemaker-hyperpod/tools/dump_cluster_nodes_info.py

# Run it to generate CSV
python3 dump_cluster_nodes_info.py --cluster-name <cluster-name>

# This creates a CSV file you can search or open in a spreadsheet
cat cluster_nodes_info.csv | grep "10.1.123.45"
```

---

### Getting Help

#### Collecting Diagnostic Data for Issue Reporting

**Orchestrator**: Common (Slurm, EKS)

When reporting issues to AWS Support, providing comprehensive diagnostic data helps expedite troubleshooting and resolution. 

**Recommended Tool**:
Use the `hyperpod_issue_report` tool to automatically collect relevant diagnostic information from your HyperPod cluster:
- Repository: https://github.com/shimomut/sagemaker-solutions/tree/main/hyperpod_issue_report
- Follow the instructions in the README for installation and usage

---

If you continue to experience issues:

1. **Check CloudWatch Logs**: Most services log detailed information to CloudWatch
2. **Review CloudFormation Events**: Stack events provide deployment timeline and errors
3. **AWS Support**: Open a support case with relevant logs and error messages
4. **GitHub Issues**: Report bugs or request features in the project repository

## Additional Resources

- [AWS HyperPod Documentation](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html)
- [EKS Troubleshooting Guide](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [Slurm Documentation](https://slurm.schedmd.com/documentation.html)
- [NCCOM Tests for Trainium Instances](/docs/eks-orchestration/validation-and-testing/performance-testing/nccom-tests)
