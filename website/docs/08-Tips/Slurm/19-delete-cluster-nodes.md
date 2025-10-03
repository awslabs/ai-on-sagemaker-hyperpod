---
title: "Delete Cluster Nodes"
weight: 59
---

The SageMaker [BatchDeleteClusterNode API](https://docs.aws.amazon.com/sagemaker/latest/dg/smcluster-scale-down.html#smcluster-scale-down-batchdelete) allows you to delete specific nodes within a SageMaker HyperPod cluster. BatchDeleteClusterNodes accepts a cluster name and a list of node IDs.

:::info
**Note:** The following instructions apply to cluster created after 6/20/2024. If your cluster was created before this date, you will need to run `aws sagemaker update-cluster-software` before executing below steps. See [release notes](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-release-notes.html#sagemaker-hyperpod-release-notes-20240620).
:::


```bash
aws sagemaker batch-delete-cluster-nodes --cluster-name "cluster-name" --node-ids '["i-111112222233333", "i-111112222233333"]'
```

Below are the recommended steps to use this API safely on a production HyperPod Cluster, without disrupt running jobs on your cluster.

## Prepare cluster for node deletion

##### Set node state to DOWN 

**Run the following on the compute/login node of your HyperPod Cluter**

1. List the current nodes and their status withing the cluster:

```bash 
sinfo
```

2. The following command will generate a list of ALL IDLE Node IP Addresses, which can be passed to scontrol:

```bash
export IDLE_NODES_TO_TERMINATE=$(sinfo --noheader --state=idle -o "%N")
```

3. It is best practice to set the nodes in DOWN state in Slurm before Terminating them. This will ensure the slurm scheduler will not allocate new jobs on these nodes. Run the below command to set all IDLE nodes in the cluster to DOWN. 

:::warning
The below example will set all IDLE nodes to Down. If you want to specify specific nodes to terminate, you can do so instead with: `sudo scontrol update NodeName=<Node_IP> State=Down Reason="Termination"`
:::

```bash
sudo scontrol update NodeName=$IDLE_NODES_TO_TERMINATE State=Down Reason="Termination"
```


4. Confirm the nodes are set to DOWN in Slurm

```bash
export NODES_SET_FOR_TERMINATION=$(sinfo -R --noheader -o "%N")
echo $NODES_SET_FOR_TERMINATION
```

5. Broadcast a message to other users on the cluster:

```bash
sudo wall "The nodes $NODES_SET_FOR_TERMINATION have been set to DOWN and are scheduled for termination. Please take note"
```

##### Confirm InstanceID of DOWN nodes:
1. Create and run the following script. The `get-node-status.sh` script will Retrieve the InstanceID for each of the Cluster Nodes. This script will parse the `/opt/ml/config/resource_config.json` file created by HyperPod to get the instance IDs.

Create the script:

```bash
cat <<'EOF' > get-node-status.sh
#!/bin/bash

# Print the header for the table
printf "%-20s %-20s %-30s %-10s %-40s\n" "IP Address" "Instance ID" "Instance Name" "Status" "Reason"
printf "%-20s %-20s %-30s %-10s %-40s\n" "--------------------" "--------------------" "------------------------------" "----------" "----------------------------------------"

# Extract details and check node status with scontrol
sudo cat /opt/ml/config/resource_config.json | jq -r '.InstanceGroups[].Instances[] | "\(.CustomerIpAddress) \(.InstanceId) \(.InstanceName)"' | while read -r ip instance_id instance_name; do
    # Format IP address by replacing dots with dashes
    formatted_ip="ip-${ip//./-}"

    # Run scontrol to get the node status using formatted IP
    node_status=$(scontrol show node "$formatted_ip" | grep -oP 'State=\K\w+')

    # Get the reason from sinfo -R, match the formatted IP with the nodes
    node_reason=$(sinfo -R --noheader | grep "$formatted_ip" | awk '{print $1}')

    # Print each line in a formatted way
    printf "%-20s %-20s %-30s %-10s %-40s\n" "$formatted_ip" "$instance_id" "$instance_name" "${node_status:-unknown}" "${node_reason:-unknown}"
done
EOF
```

2. Run the script:

```bash
bash get-node-status.sh
```

##### Execute Node Deletion 
:::info
To execute the batch delete-cluster-node command, you will need to call the API from a development environment with the AWS CLI installed. You can use [AWS CloudShell](https://aws.amazon.com/cloudshell/) from within your AWS Account, which comes pre-installed with the AWS CLI
:::


1. Execute the batch-delete-cluster-nodes api:

```bash
#Confirm cluster name
aws sagemaker list-clusters --region <YOUR_REGION>

#Confirm cluster nodes

aws sagemaker list-cluster-nodes --cluster-name <CLUSTER_NAME> --region <YOUR_REGION>
aws sagemaker batch-delete-cluster-nodes --cluster-name <YOUR_CLUSTER_NAME> --node-ids [InstanceIDs] --region <YOUR_REGION>
```

2. When the `batch-delete-cluster-nodes` API has been executed successfully, you will see an output similar to the following:

```
$ aws sagemaker batch-delete-cluster-nodes --cluster-name ml-cluster --node-ids i-04486002ebdb59e0a i-0b8bc2c52dc7b1fa2
{
    "Successful": [
        "i-04486002ebdb59e0a",
        "i-0b8bc2c52dc7b1fa2"
    ]
}
```

:::info
If you are using Reserved Instances for your HyperPod Cluster (via a Neogatiated PPA), you will continue to be billed for nodes which have been deleted from your cluster. If you wish to no longer be billed for the deleted instances, contact your AWS Account / Support team to notify them of the node termination and request for billing to be termianted for the deleted nodes.
:::

