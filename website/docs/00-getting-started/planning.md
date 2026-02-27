---
title: "Planning your deployment"
sidebar_position: 1
weight: 1
---

# Your Amazon SageMaker HyperPod journey
In order to better utilise the solution, proper planning is required. Amazon SageMaker HyperPod makes it easier to build a GPU cluster. Even though, you need to understand some concepts and create a plan on how you are going to use it. 

## What type of orchestrator are you going to use? 
The best approach to choose your orchestrator is to understand what features are available for each supported one and balance with your knowledge of each. If your team does not have experience working with Kubernetes, then choosing Slurm is the best approach. 

SageMaker HyperPod allows you to choose between two orchestrators: Slurm or Kubernetes. Here is a list of features available for each:

| |Slurm|EKS|
|-|-|-|
|All GPUs (G5, G6, G7, P4, P5, P6)|X|X|
|Spot Instances|X|X|
|Resiliency|X|X|
|Auto Resume|X|X|
|Multi-GPU Instance Group (MIG)|X|X|
|Restricted Instance Group (RIG)|X|X|
|Elastic Training| |X|
|Training Operator| |X|
|Inference Operator| |X|
|Checkpointless| |X|
|Tiered Checkpointing| |X|
|Task Governance| |X|

Besides specific features, managing and using the solutions are very different:

|Slurm|EKS|
|-|-|
|Simple to manage and maintain, focused on training|Flexibility of running both training and inference on the same cluster|
|Natively integrated job accounting, allowing for reporting capabilities out of the box|Requires additional tools to gather job accounting|
|Observability stack requires additional setup|Simple 1-click deploy Observability stack|
|Data Scientits can work on Login nodes by connecting to them using their IDE of choice|If you enable Spaces, Data Scientists will have access to a web-based IDE they can access remotely|
|By providing Login nodes, users have access to a separate home directory and shared data file system. This setup simplifies the Data Scientis work, as they can use their home diretory and access it both from the cluster and outside of it. Moving datasets from their data preparation stage to the shared data file system is easy.|Data scientists needs to upload their datasets to Amazon S3 so they can access on their cluster, either using a S3 CSI driver or using the FSx CSI driver to access a Persistent Volume (PV).|
|All the infrastructure exists on the Service Account|The Kubernetes Control Plane exists on your account while the HyperPod Data Plane exists on the Service Account|
|In order to have separate queues, you have to customise the solution after it was deployed|You can use namespaces and Task Governance to isolate different workloads|
|Preempting lower priority jobs requires to customise Slurm after the initial setup|Task Governance allows native task preemption|
|In order to have process-level restarts, you need to install the NVIDIA Resilient Extension (NVRX) post installation|Process-level restarts are a native feature of the Training and Inference Operators|
|Supports batch inference. For real time inference, lacks the ability of scaling up and down based on demand.|Supports both batch and real time inference, with native scaling mechanisms|

## How my Data Scientits and Researchers (users) will work?
When procuring a Generative AI solution, it is easy to focus on the type of GPUs and frameworks you are going to use and forget basic concepts such as operational efficiency. The solution needs to be treated as any other system in your business. It requires security, has a life cycle, needs backup ahd maintenance, resiliency, etc. Those topics might not be as exciting as developing your Generative AI workload but are equally important, I'd dare to say. 

Important topics to consider:
- Your users will create code and commit it to a code repository. This will help with code versioning and proper tracking and history of changes. They will clone the repository on their home diretory, if using Slurm. 
- They need to access data and create new data. Data can be downloaded on their home directories, if using Slurm, or accessed on Amazon S3. After preparing it, users have the choice of copying it to the Amazon FSx for Lustre file system, for higher throughput, or access it directly on their source (Amazon S3 or the users' home diretory).
- Checkpoints **SHOULD** be stored on Amazon FSx for Lustre. It is a highly performant file system that allows fine grained customisation of the stripping size on each directory. Lustre can deliver Terabytes/s throughput, millions of IOPS, and a very low latency access to data.
- Data movement from Amazon S3 to your Amazon FSx for Lustre file system, and back to Amazon S3, MUST be managed by a Dynamic Repository Association (DRA). This feature allows you to define how data moves from one layer to the other. You can choose to copy New, Changed, or Deleted files back and forth, based on your demand.
- If you have large data residing outside of AWS, it is recommended that you copy that data closer to your cluster rather than relying on internet connections. Use native AWS tools to help you copy the data. 
- Raw data, which is not frequently used, can be stored on Amazon S3 Deep Glacier.
- Data **MUST** be backed up. Code is commited to a repository and the repository is backed up periodically. Checkpoints and datasets are copied to Amazon S3 or Lustre, and backedup properly using the native AWS tools available. 

## Security, network and user management
If you are a small organization which has access to a single AWS Account ID, planning the network part of your deployment is easier. Make sure you have a dedicated VPC for your cluster, as those may require a large CIDR range to support many instances. 

If you are a large organization which operates under a central AWS Organization structure, then proper network setup is rquired. Amazon SageMaker HyperPod uses AWS PrivateLink to give your account access to the Service Account. Those are setup on the account that will operate the cluster. Other VPC Endpoints are also required, with AWS SSM, Amazon S3 and Amazon ECR being the basic ones. If your organization uses a centralized VPC endpoint architecture, then the proper inclusion of your cluster VPC in your Private Hosted Zone (PHZ) is required. 

In case you need to air-gap the VPC where the cluster exists, then you need to properly setup Transit Gateway to allow access to the internet via a centralized egress solution. Installing security endpoints on the cluster nodes are not a recommended practice as they consume precious resources which can slow down your training or inference GoodPut. In case you need to inspect and monitor the traffic, use Gateway Load Balancer VPC endpoints. Avoid doing this type of inspection on the traffic exchanged between the compute nodes as this will introduce a severe penalty to your throughput. Plan to protect on the outer layer, before data enters the cluster and when it exits (North/South inspection).

User management **SHOULD** happen on a centralized tool such as LDAP or SAML directories (ex: MS Entra ID). Identity Providers can be used with EKS, such as OpenID Connect (Okta Identity, Ping Identity, etc). Slurm allows you to manually manage users via a text file, although it is a discouraged method. If you don't have a centralized directory you can either deploy an AWS Managed ACtive Diretory solution or use the LDAP Server template provided on this repository. 

## Frameworks, libraries and drivers versioning
Both Slurm and EKS operates running container images. For EKS, containers are native and the only way to use the solution. For Slurm, you **SHOULD** use rootless containers. The SageMaker HyperPod solution provides, natively, the Enroot and PyXis binaries. They allow you to create a squash file from your container. This best practice allows you to have multiple types of frameworks operating on your cluster without interfering with the base setup. It allows you to test new library and driver versions without impacting the existing working setup. 

To manage your containers, you **SHOULD** have a central repository to store them. You can use either Docker Hub or Amazon ECR. 

## Additional considerations
After you've decided on the security, network, and operational aspect of your cluster, it's time to consider the technical details.

- **Do you have a centralised directory to manage users?**
  - If you use LDAP or Active Directory, SageMaker HyperPod can integrate with it. If you don't, you will need to manually manage those users on a .txt file used by SageMaker HyperPod. The former is the recommended method.
- **Are you going to use Login Nodes?**
  - Highly recommended as they allow users to work on a separate set of nodes and avoid problems on the controller node.
- **What types of instances are you going to use for each instance group?**
  - There are at least 2 types of instances groups required: controller node group and compute node group. You can have other too, such as a login node group and multiple other compute node groups.
  - If not using login nodes, it is highly recommended that your controlle node group use large instances that will support both users working on it (running docker build, jupyter notebooks, etc) and managing the jobs on the Slurm queues. Compute intensive instances (C6, C7) or General Purpose instances (M7, M8) are good choices here.
  - If using login nodes, the controller node don't need much compute power and relies more on RAM. Memory intensive instances, such as R6 and R7, are good choices.
- **What is the required file system size and performance?**
  - Plan accordingly to your workload. Lustre performance incrases as the file system size increases. And if you need a small file sysstem, you can also increase the throughput performance per unit. A good balance is 250MB/s/TB. On a 50TB file system you get a bseline of 12.5 GB/s, with eventual bursts that can deliver more than that. And if you need more performance, but not necesarily more storage space, then increase the throughput per unit to 500MB/s and instantly double your throughput performance.
- **Are you integrating this new cluster with existing file systems or observability solutions?**
  - If you are, then make sure the proper permissions are in place before you deploy the cluster. On a Lustre file system, for example, you will need to update its ENI (Elastic Network Intefaces) and add the security group for the new cluster. If reusing a Prometheus collector, then you will need to ensure the IAM Roles allow this new cluster to publish metrics there.

:::note
Throughput per unit can be changed after the file system has been created. File system size can be increased but not reduced after it has been created.
:::

## Conclusion
Amazon SageMaker HyperPod helps you deploy a large distributed system to operate your model training and inference workloads. The solution takes care of removing the undifferentiated heavy lifting of setting up the infrastructure properly. 

It is the user responsibility to plan on how they will use the solution. Careful planning is recommend a few of the choices you will make when deploying the solution might be hard to be changed after it is deployed. Or might require some downtime. To avoid it, spend some time discussing with your teams how you are going to operate the complete life cycle of your model development and the role of SageMaker HyperPod on this landscape.

