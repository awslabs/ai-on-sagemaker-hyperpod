---
title: "c. Install Dependencies"
weight: 3
--- 
[Helm](https://helm.sh/), the package manager for Kubernetes, is an open-source tool for setting up a installation process for Kubernetes clusters. It enables the automation of dependency installations and simplifies various setups needed for EKS on HyperPod. The HyperPod service team provides a Helm chart package, which bundles key dependencies and associated permission configurations. See the [What Gets Installed](/01-cluster/03-install-dependencies#what-gets-installed) section for details. 

## Clone the Repo 

```bash
git clone https://github.com/aws/sagemaker-hyperpod-cli.git
cd sagemaker-hyperpod-cli/helm_chart
```

## Install the Helm Chart

Locally test the helm chart: 
```bash
helm lint HyperPodHelmChart
```
Update the dependencies: 
```bash 
helm dependencies update HyperPodHelmChart
```
Conduct a dry run: 
```bash 
helm install hyperpod-dependencies HyperPodHelmChart --dry-run
```
Deploy the helm chart: 
```bash 
helm install dependencies helm_chart/HyperPodHelmChart --namespace kube-system
```

Verify the deployment:

```bash
helm list 
```

Before moving on to the next step, change go to your original working directory:

```bash
cd ../..
```

## What Gets Installed
:::::alert{header="Note:"}
Several dependencies like the health monitoring agent and various role based access control policies for basic and deep health checks are required to be installed prior to HyperPod cluster creation. As a result, if you are using a new EKS cluster with no worker nodes attached yet, you will notice that all deployed pods are in a pending state. This is expected behavior, and all pods should update to a running state when HyperPod worker nodes are added later in the workshop. 
:::::
---
:::expand{header="Health Monitoring Agent" defaultExpanded=false}

HyperPod health-monitoring agent continuously monitors the health status of each GPU/Trn-based node. When it detects any failures (such as GPU failure, Kernel deadlock and driver crash), the agent marks the node as unhealthy.

Verify deployment: 
```bash
 kubectl get ds health-monitoring-agent -n aws-hyperpod
```
:::
---
:::expand{header="NVIDIA device plugin for Kubernetes" defaultExpanded=false}

The [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin) is a Daemonset that allows you to automatically:

- Expose the number of GPUs on each nodes of your cluster
- Keep track of the health of your GPUs
- Run GPU enabled containers in your Kubernetes cluster.

Verify deployment: 
```bash
kubectl get ds hyperpod-dependencies-nvidia-device-plugin -n kube-system
```
:::

---
:::expand{header="Neuron device plugin" defaultExpanded=false}

The [Neuron device plugin](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/containers/tutorials/k8s-setup.html) exposes Neuron cores & devices on [Trainium](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/general/arch/neuron-hardware/trainium.html) (`ml.trn1.32xlarge`) instances to kubernetes as a resource.

Verify deployment:
```bash
kubectl get ds neuron-device-plugin-daemonset -n kube-system
```
:::
---
:::expand{header="EFA Kubernetes device plugin" defaultExpanded=false}

[Elastic Fabric Adapter (EFA)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html) is a network interface for Amazon EC2 instances that uses a custom-built operating system bypass hardware interface to enhance the performance of inter-instance communications, allowing High Performance Computing (HPC) applications using the Message Passing Interface (MPI) and Machine Learning (ML) applications using [NVIDIA Collective Communications Library (NCCL)](https://developer.nvidia.com/nccl) to scale to thousands of CPUs or GPUs. 

Integrating EFA with applications running on Amazon EKS clusters can reduce the time to complete large scale distributed training workloads without having to add additional instances to your cluster. 

The [EFA Kubernetes device plugin](https://github.com/aws/eks-charts/tree/master/stable/aws-efa-k8s-device-plugin) detects and advertises EFA interfaces as allocatable resources to Kubernetes. An application can consume the extended resource type vpc.amazonaws.com/efa in a Pod request spec just like CPU and memory. Once requested, the plugin automatically assigns and mounts an EFA interface to the Pod. Using the device plugin simplifies EFA setup and does not require a Pod to run in privileged mode.

Verify deployment: 
```bash
kubectl get ds hyperpod-dependencies-aws-efa-k8s-device-plugin
```
:::
---
:::expand{header="Kubeflow Training Operator" defaultExpanded=false}

The [Kubeflow Training Operator](https://github.com/kubeflow/training-operator) is a tool designed for running and scaling machine learning model training on Kubernetes. It allows you to train models built with frameworks like TensorFlow and PyTorch by leveraging Kubernetes resources, simplifying the process of training complex models in a distributed way. You will use the Kubeflow training operator throughout this workshop to create various [PyTorch training jobs](https://www.kubeflow.org/docs/components/training/user-guides/pytorch/) running on SageMaker HyperPod nodes. 

Verify deployment: 
```bash
 kubectl get deploy hyperpod-dependencies-training-operators -n kubeflow
```
View the custom resource definitions for each supported ML framework: 
```bash 
kubectl get crd | grep kubeflow
```
```
mpijobs.kubeflow.org                         2024-07-11T22:35:03Z
mxjobs.kubeflow.org                          2024-07-11T22:00:35Z
paddlejobs.kubeflow.org                      2024-07-11T22:00:36Z
pytorchjobs.kubeflow.org                     2024-07-11T22:00:37Z
tfjobs.kubeflow.org                          2024-07-11T22:00:38Z
xgboostjobs.kubeflow.org                     2024-07-11T22:00:39Z

```
:::
---
:::expand{header="Kubeflow MPI Operator" defaultExpanded=false}

The [Kubeflow MPI Operator](https://github.com/kubeflow/mpi-operator) makes it easy to run allreduce-style distributed training on Kubernetes. 

Verify deployment: 
```bash 
kubectl get deploy hyperpod-dependencies-mpi-operator
```

The MPI Operator comes prepackaged with the MPIJob v2beta1 custom resource definition (CRD). 

Verify the version of the MPIJob CRD:
```bash
kubectl get crd mpijobs.kubeflow.org -n kubeflow -o jsonpath='{.status.storedVersions[]}'
```
:::
---
:::expand{header="Kubernetes PriorityClass" defaultExpanded=false}

Pods can have priority. Priority indicates the importance of a Pod relative to other Pods. If a Pod cannot be scheduled, the scheduler tries to preempt (evict) lower priority Pods to make scheduling of the pending Pod possible.

A [PriorityClass](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#priorityclass) is a non-namespaced object that defines a mapping from a priority class name to the integer value of the priority. 

Verify deployment: 
```bash
kubectl get priorityclass
```
:::
