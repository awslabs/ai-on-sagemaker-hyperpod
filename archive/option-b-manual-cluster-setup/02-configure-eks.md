---
title: "b. Configure the EKS Cluster"
weight: 2
--- 
## Configure Admin Access
In Full deployment mode, an Amazon EKS cluster named `hyperpod-eks-cluster` has been deployed as part of the supporting infrastructure for this workshop. We'll reference this EKS cluster as the orchestrator of the HyperPod compute nodes. If you are using your own EKS cluster and already have kubectl access configured, you can skip to the next section. 

::::alert{header="Note:"}
By default, the Amazon EKS service will automatically create an [AccessEntry](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-eks-accessentry.html) with [AmazonEKSClusterAdminPolicy](https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html#access-policy-permissions) permissions for the IAM principal that you use to deploy the CloudFormation stack, which includes an EKS cluster resource. You can create additional access entries later through the EKS management console or the AWS CLI. For more information, see the documentation on [managing access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html). 

:::expand{header="AWS CLI Examples" defaultExpanded=false}
The [create-access-entry](https://docs.aws.amazon.com/cli/latest/reference/eks/create-access-entry.html) command creates an access entry that gives an IAM principal access your EKS cluster: 
```bash 
aws eks create-access-entry \
 --cluster-name $EKS_CLUSTER_NAME \
 --principal-arn arn:aws:iam::xxxxxxxxxxxx:role/ExampleRole \
 --type STANDARD \
 --region $AWS_REGION
```
The [associate-access-policy](https://docs.aws.amazon.com/cli/latest/reference/eks/associate-access-policy.html) command associates an access policy and its scope to an access entry: 
```bash 
aws eks associate-access-policy \
 --cluster-name $EKS_CLUSTER_NAME \
 --principal-arn arn:aws:iam::xxxxxxxxxxxx:role/ExampleRole \
 --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
 --access-scope type=cluster \
 --region $AWS_REGION
```
:::
::::

Run the [aws eks update-kubeconfig](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/eks/update-kubeconfig.html) command to update your local kube config file (located at `~/.kube/config`) with the credentials and configuration needed to connect to your EKS cluster using the `kubectl` command.  
```bash
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME
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
```
NAME             TYPE        CLUSTER-IP   EXTERNAL-IP PORT(S)   AGE
svc/kubernetes   ClusterIP   10.100.0.1   <none>      443/TCP   1m
```
