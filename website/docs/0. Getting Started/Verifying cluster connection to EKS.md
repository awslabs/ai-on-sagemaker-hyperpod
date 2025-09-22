---
title: Verifying cluster connection to EKS
sidebar_position: 3
---

## Verify `kubectl` Access 
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
You should see an output similar to this: 
```
NAME             TYPE        CLUSTER-IP   EXTERNAL-IP PORT(S)   AGE
svc/kubernetes   ClusterIP   10.100.0.1   <none>      443/TCP   1m
```
---

## Verify `helm` Chart Installation 
[Helm](https://helm.sh/), the package manager for Kubernetes, is an open-source tool for setting up a installation process for Kubernetes clusters. It enables the automation of dependency installations and simplifies various setups needed for EKS on HyperPod. The HyperPod service team provides a [Helm chart package](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-install-packages-using-helm-chart.html), which bundles key dependencies and associated permission configurations. See [What Dependencies are Installed on Your EKS Cluster](https://nohello.net) for details. 

For your convenience, we've automatically installed the required Helm chart package using an AWS Lambda function. 

To verify that the Helm packages are installed by running the following command:
```bash
helm list -n kube-system

```
You should see an output similar to this: 
```
NAME                 	NAMESPACE  	REVISION	UPDATED                               	STATUS  	CHART                    	APP VERSION
hyperpod-dependencies	kube-system	1       	2025-02-22 02:01:44.82426219 +0000 UTC	deployed	hyperpod-helm-chart-0.1.0	1.16.0

```

:::alert{header="Note:" type="info"}
The HyperPod dependency [Helm charts](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-install-packages-using-helm-chart.html) need to be installed on your EKS cluster prior to kicking off the creation of a new HyperPod cluster. If you chose to disable the `HelmChartStack` stack but created a new EKS cluster using the `EKSClusterStack`, the `HyperPodClusterStack` was automatically disabled as well to avoid any HyperPod cluster creation failures. After the main stack completes, you can then proceed to manually install the dependencies prior to kicking off the manual creation of your HyperPod cluster. 
:::