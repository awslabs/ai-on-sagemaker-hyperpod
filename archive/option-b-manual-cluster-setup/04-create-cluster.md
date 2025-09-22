---
title: "d. Create the HyperPod Cluster"
weight: 4
---

1. We'll create a HyperPod cluster configuration file (`cluster-config.json`) that points to the EKS cluster as the orchestrator for new instance groups that will be created. The example below creates two instance groups, one for your accelerated compute nodes (`ml.g5.12xlarge` by default), and an additional instance group containing a general purpose compute node (`ml.m5.2xlarge` by default) used to host pods that do not require accelerated compute capacity.

:::::alert{header="Important:" type="warning"}
Before creating your HyperPod cluster, consider the types of experiments you intend to run. For example, if you want to run the [Fully Sharded Data Parallel(FSDP)](/02-FSDP/) experiment, it has been verified on a cluster of 8 `ml.g5.8xlarge` nodes, whereas the [Llama 3 model training using Trainium](/04-Trainium_NxD/) experiment has been verified on 1 to 2 node clusters of `ml.trn1.32xlarge` or `ml.trn1n.32xlarge` instances. To choose a different accelerated instance type and count, refer back to the [Setup Environment Variables](/01-cluster/01-environment-vars) section. 
:::::


::::tabs{variant="container" activeTabId="simplified"}

:::tab{id="simplified" label="Simplified (Workshop Studio)"}

- Single instance group
- Deep Health Checks are disabled.
- Modify threadsPerCore(set it to 2 for G5/P4/P5)

```json
cat > cluster-config.json << EOL
{
    "ClusterName": "ml-cluster",
    "Orchestrator": { 
      "Eks": 
      {
        "ClusterArn": "${EKS_CLUSTER_ARN}"
      }
    },
    "InstanceGroups": [
      {
        "InstanceGroupName": "worker-group-1",
        "InstanceType": "${ACCEL_INSTANCE_TYPE}",
        "InstanceCount": ${ACCEL_COUNT},
        "InstanceStorageConfigs": [
          {
            "EbsVolumeConfig": {
              "VolumeSizeInGB": ${ACCEL_VOLUME_SIZE}
            }
          }
        ],
        "LifeCycleConfig": {
          "SourceS3Uri": "s3://${BUCKET_NAME}",
          "OnCreate": "on_create.sh"
        },
        "ExecutionRole": "${EXECUTION_ROLE}",
        "ThreadsPerCore": 2
      }
    ],
    "VpcConfig": {
      "SecurityGroupIds": ["$SECURITY_GROUP"],
      "Subnets":["$SUBNET_ID"]
    },
    "NodeRecovery": "${NODE_RECOVERY}"
}
EOL
```

:::

:::tab{id="full" label="Full"}

- Two instance groups
- Deep Health Checks are enabled
- Modify threadsPerCore(set it to 2 for G5/P4/P5)

```json
cat > cluster-config.json << EOL
{
    "ClusterName": "ml-cluster",
    "Orchestrator": { 
      "Eks": 
      {
        "ClusterArn": "${EKS_CLUSTER_ARN}"
      }
    },
    "InstanceGroups": [
      {
        "InstanceGroupName": "worker-group-1",
        "InstanceType": "${ACCEL_INSTANCE_TYPE}",
        "InstanceCount": ${ACCEL_COUNT},
        "InstanceStorageConfigs": [
          {
            "EbsVolumeConfig": {
              "VolumeSizeInGB": ${ACCEL_VOLUME_SIZE}
            }
          }
        ],
        "LifeCycleConfig": {
          "SourceS3Uri": "s3://${BUCKET_NAME}",
          "OnCreate": "on_create.sh"
        },
        "ExecutionRole": "${EXECUTION_ROLE}",
        "ThreadsPerCore": 2,
        "OnStartDeepHealthChecks": ["InstanceStress", "InstanceConnectivity"]
      },
      {
        "InstanceGroupName": "worker-group-2",
        "InstanceType": "${GEN_INSTANCE_TYPE}",
        "InstanceCount": ${GEN_COUNT},
        "InstanceStorageConfigs": [
          {
            "EbsVolumeConfig": {
              "VolumeSizeInGB": ${GEN_VOLUME_SIZE}
            }
          }
        ],
        "LifeCycleConfig": {
          "SourceS3Uri": "s3://${BUCKET_NAME}",
          "OnCreate": "on_create.sh"
        },
        "ExecutionRole": "${EXECUTION_ROLE}",
        "ThreadsPerCore": 1
      }
    ],
    "VpcConfig": {
      "SecurityGroupIds": ["$SECURITY_GROUP"],
      "Subnets":["$SUBNET_ID"]
    },
    "NodeRecovery": "${NODE_RECOVERY}"
}
EOL
```

:::

::::

:::::alert{header="Note:"}
If you'd like to use [training plans](https://aws.amazon.com/blogs/machine-learning/speed-up-your-cluster-procurement-time-with-amazon-sagemaker-hyperpod-training-plans/) nodes in your cluster, you'd need to add in the following line to your `cluster-config.json` file

```bash
"TrainingPlanArn": "<ENTER TRAINING PLAN ARN HERE>",
```

To get your training plan details, you can run
```bash
export TRAINING_PLAN="<NAME OF TRAINING PLAN>"
TRAINING_PLAN_DESCRIPTION=$(aws sagemaker describe-training-plan --training-plan-name "$TRAINING_PLAN")

TRAINING_PLAN_ARN=$(echo "$TRAINING_PLAN_DESCRIPTION" | jq -r '.TrainingPlanArn')
```

Here's an example `cluster-config.json` with a training plan used
```bash
cat > cluster-config.json << EOL
{
    "ClusterName": "ml-cluster",
    "Orchestrator": { 
      "Eks": 
      {
        "ClusterArn": "${EKS_CLUSTER_ARN}"
      }
    },
    "InstanceGroups": [
      {
        "InstanceGroupName": "worker-group-1",
        "InstanceType": "${ACCEL_INSTANCE_TYPE}",
        "InstanceCount": ${ACCEL_COUNT},
        "InstanceStorageConfigs": [
          {
            "EbsVolumeConfig": {
              "VolumeSizeInGB": ${ACCEL_VOLUME_SIZE}
            }
          }
        ],
        "LifeCycleConfig": {
          "SourceS3Uri": "s3://${BUCKET_NAME}",
          "OnCreate": "on_create.sh"
        },
        "TrainingPlanArn": "${TRAINING_PLAN_ARN}",
        "ExecutionRole": "${EXECUTION_ROLE}",
        "ThreadsPerCore": 2
      }
    ],
    "VpcConfig": {
      "SecurityGroupIds": ["$SECURITY_GROUP"],
      "Subnets":["$SUBNET_ID"]
    },
    "NodeRecovery": "${NODE_RECOVERY}"
}
EOL
```
:::::


## Cluster Configuration Parameters:

- You can configure up to 20 instance groups under the `InstanceGroups` parameter. 
- For `Orchestrator.Eks.ClusterArn`, specify the ARN of the EKS cluster you want to use as the orchestrator. 
- For `OnStartDeepHealthChecks`, add `InstanceStress` and `InstanceConnectivity` to enable deep health checks. 
- For `NodeRecovery`, specify `Automatic` to enable automatic node recovery. HyperPod replaces or reboots instances (nodes) that fail the basic health or deep health checks (when enabled). 
- For the `VpcConfig` parameter, specify the information of the VPC used in the EKS cluster. The subnets must be private

---

2. Create the cluster:

```bash
aws sagemaker create-cluster \
    --cli-input-json file://cluster-config.json \
    --region $AWS_REGION
```

3. We can describe the state of the cluster:

```bash
aws sagemaker list-clusters \
 --output table \
 --region $AWS_REGION
```

You'll see output similar to the following:

```
-------------------------------------------------------------------------------------------------------------------------------------------------
|                                                                 ListClusters                                                                  |
+-----------------------------------------------------------------------------------------------------------------------------------------------+
||                                                              ClusterSummaries                                                               ||
|+----------------------------------------------------------------+----------------------+----------------+------------------------------------+|
||                           ClusterArn                           |     ClusterName      | ClusterStatus  |           CreationTime             ||
|+----------------------------------------------------------------+----------------------+----------------+------------------------------------+|
||  arn:aws:sagemaker:us-west-2:xxxxxxxxxxxx:cluster/uwme6r18mhic |  ml-cluster          |  Creating     |  2024-07-11T16:30:42.219000-04:00   ||
|+----------------------------------------------------------------+----------------------+----------------+------------------------------------+|
```