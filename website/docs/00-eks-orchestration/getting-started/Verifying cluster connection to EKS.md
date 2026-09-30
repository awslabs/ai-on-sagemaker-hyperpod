---
title: Verifying cluster connection to EKS
sidebar_position: 4
---
## Source HyperPod Environment Variables

The HyperPod environment variables will be used throughout this repo. We will be sourcing them from the CloudFormation stacks that created your cluster.

Creating a cluster from the SageMaker console deploys those stacks on your behalf, and the stack name it generates includes a random suffix. Look it up from your cluster name rather than guessing it:

``` bash
export AWS_REGION=${AWS_REGION:-$(aws configure get region)}
export HP_CLUSTER_NAME={your-hyperpod-cluster-name}

export STACK_ID=$(aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --query "Stacks[?ParentId==null && Outputs[?OutputKey=='OutputHyperPodClusterName' && OutputValue=='${HP_CLUSTER_NAME}']].StackName" \
  --output text)

echo "STACK_ID = ${STACK_ID}"
```

`ParentId==null` restricts the search to the root stack, which is the only one that publishes the outputs the next step reads. A cluster typically spans dozens of nested stacks.

:::warning
If `STACK_ID` comes back empty, stop here. No root stack in `${AWS_REGION}` reports that HyperPod cluster name, so check the cluster name and region before continuing. Running the next step with an empty `STACK_ID` fails in a way that is hard to read.
:::

Now download the helper script and source the variables:

``` bash
curl -fsSLO https://raw.githubusercontent.com/aws-samples/awsome-distributed-training/refs/heads/main/architectures/sagemaker-hyperpod-eks/create_config.sh

chmod +x create_config.sh

./create_config.sh

source env_vars
```

:::info
`create_config.sh` appends a line to your `~/.bashrc` and `~/.zshrc` that sources the `env_vars` file from the directory you ran it in. Run it from a directory you intend to keep, otherwise you will be left with a `source` line pointing at a path that no longer exists.
:::

To confirm all the environment variables were set correctly, run:
``` bash
cat env_vars
```

## Verify `kubectl` Access 
Run the [aws eks update-kubeconfig](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/eks/update-kubeconfig.html) command to update your local kube config file (located at `~/.kube/config`) with the credentials and configuration needed to connect to your EKS cluster using the `kubectl` command.  
```bash
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION
```

You can verify that you are connected to the EKS cluster by running this commands: 
```bash 
kubectl config current-context 
```
```
arn:aws:eks:us-west-2:xxxxxxxxxxxx:cluster/hyperpod-eks-cluster
```
```bash
kubectl get svc
```
You should see an output similar to this: 
```
NAME             TYPE        CLUSTER-IP   EXTERNAL-IP PORT(S)   AGE
svc/kubernetes   ClusterIP   10.100.0.1   <none>      443/TCP   1m
```
---

## Verify `helm` Chart Installation 
[Helm](https://helm.sh/), the package manager for Kubernetes, is an open-source tool for setting up a installation process for Kubernetes clusters. It enables the automation of dependency installations and simplifies various setups needed for EKS on HyperPod. The HyperPod service team provides a [Helm chart package](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-install-packages-using-helm-chart.html), which bundles key dependencies and associated permission configurations. See [What Dependencies are Installed on Your EKS Cluster](./additional-information.md#what-dependencies-are-installed-on-your-eks-cluster) for details. 

For your convenience, we've automatically installed the required Helm chart package using an AWS Lambda function. 

To verify that the Helm packages are installed by running the following command:
```bash
helm list -n kube-system

```
You should see an output similar to this: 
```
NAME        	NAMESPACE  	REVISION	UPDATED                                	STATUS  	CHART                    	APP VERSION
dependencies	kube-system	1       	2025-02-22 02:01:44.82426219 +0000 UTC 	deployed	hyperpod-helm-chart-0.1.0	1.16.0

```

Match on the `CHART` column rather than the release name. The release name comes from the `HelmRelease` parameter on the cluster stack, so it varies: the console passes `dependencies`, while the template default is `hyperpod-dependencies`. What matters is that a `hyperpod-helm-chart-*` release is present and `deployed`.

:::alert{header="Note:" type="info"}
The HyperPod dependency [Helm charts](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-install-packages-using-helm-chart.html) need to be installed on your EKS cluster prior to kicking off the creation of a new HyperPod cluster. If you chose to disable the `HelmChartStack` stack but created a new EKS cluster using the `EKSClusterStack`, the `HyperPodClusterStack` was automatically disabled as well to avoid any HyperPod cluster creation failures. After the main stack completes, you can then proceed to manually install the dependencies prior to kicking off the manual creation of your HyperPod cluster. 
:::