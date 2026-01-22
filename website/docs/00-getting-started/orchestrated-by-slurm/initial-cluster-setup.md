---
title: Creating your SageMaker HyperPod cluster
sidebar_position: 1
sidebar_title: Creating your SageMaker HyperPod cluster
slug: initial-cluster-setup
preview: /img/01-setup/preview-initial-cluster-setup.png
---

# Setting up your cluster following the best practices
If you just want to deploy a simple cluster, for small environments or a development use case, then you can use the **Quick Setup** section of this page. Otherwise, please use the Custom Setup.

You need to have at least the following information before you start creating your cluster:
- Instances groups that you want to create
- Size and throughput performance required on the file system
- If using a centralised directory for user authentication, it must be already setup 
- If using home directories on OpenZFS, it must be already created
- If you modified the LifeCycle Scripts (LCS), then you need to upload the modified LCS to your Amazon S3 bucket too.

:::note
If you plan to use OpenZFS for Home Directories, then you need to manually create your Lustre file sytem on the AWS Management Console before deploying the cluster, and **Quick Setup** is an option for you. 

The console experience on SageMaker HyperPod does not integrates the creation of OpenZFS, so it won't modify the `provisioning_parameters.json` file for you. You need to manually create it and upload to Amazon S3. When you do so, then SageMaker HyperPod expects that an Amazon FSx for Lustre file system is also defined on that same file. You can't use the SageMaker HyperPod console experience to create the Lustre file system. 
:::

## Preparing your User Management solution
Users can be maanage in two ways: either on a text file or on a centralised directory. 

### Text file
If using a text file, please download the LifeCycle Scripts (LCS) [here](https://github.com/awsome-distributed-training/11.architecture/5.sagemaker-hyperpod/LifecycleScripts/base-confiig/). Rename the file `shared_users_sample.txt` to `shared_users.txt` and update it. The format of the file is:
```
username, user UID, /fsx/username
```
Then, upload the LCS to your Amazon S3 bucket, including this file. You will use this bucket URI during your **Custom Setup** of the SageMaker HyperPod solution. When nodes are deployed for the first time, they will run a routine that will check if the users exists on the operating system. If not, a proper user setup will happen, allowing users to SSH to the nodes and run jobs. 

If you want to view how this setup is done, and even customise it, open the file [add_users.sh](https://github.com/awsome-distributed-training/11.architecture/5.sagemaker-hyperpod/LifecycleScripts/base-confiig/add_users.sh) on the LCS folder. As part of the LCS execution, the `add_users.sh` is used to setup users based on the `shared_users.txt` file.

### Centralised directory
When using LDAP or SAML, you need to download the LifeCycle Scripts (LCS) [here](https://github.com/awsome-distributed-training/11.architecture/5.sagemaker-hyperpod/LifecycleScripts/base-confiig/) and customise the `config.py` file. 

First, enable **SSSD** by changing the parameter `enable_sssd = False` to ` True`. 

Then, modify the section `Configuration parameters for ActiveDirectory/LDAP/SSSD` with the minimum required configuration below:
- ldap_uri, example `ldaps://nlb-ds-xyzxyz.elb.us-west-2.amazonaws.com`
- ldap_search_base, ldap_default_bind_dn: change at least `DC=abc123, DC=com` so it reflects your domain
- ldap_default_authtok_type, ldap_default_authtok: use `obfuscated_password` as the password type and paste the obfuscated value here. 
- override_homedir: modify it to use `/home/%u` to use OpenZFS as your home directories (highly recommended). 

The other parameters are optional. If you want to create other organizational units and groups, you can do so and change them here. You can restrict SSH access to specifiic instance groups by modifying the `ssh_allow_groups` parameter.

## Preparing your Home Directories file system
Model training and inference looks like a simple job: you create your dataset, prepare your model script, and submit the job. When you dive deep into each of those steps, they consist of multiple other steps, interactions over experiments, copying files here and there, and so much more. 

File systems such as Lustre where created with high performance in mind. Whiile operations such as reading large datasets (TBs of data) and writing distributed checkpoints (multiple clients writing at the same time) are the sweet spot for Lustre, heavily intense metadata operations are not. Users cloning code repositories, running jupyter notebooks, listing thousands or millions of files, iterating over those files to read small bits of data, are operations that relies heavily on metadata.

Lustre is focused on having compute nodes accessing it, using its own dedicated client binary. On the other hand, users wants to the flexibility of mounting their home directories anywhere, such as on their own laptops which could be running an OS that does not support the Lustre client.

The recommended solution is to use Amazon FSx for OpenZFS. OpenZFS has some advantages over Lustre for this kind of workload:
- It uses NFS to mount the file system, making it highly compatible with most operating systems out-of-the-box.
- It uses a primary in-memory cache combined with a secondary local NVME disk cache layer, and both sits on top of the EBS-backed persistent layer. It can handle a large number of metadata operations without struggling for performance.
- OpenZFS can be deployed on multiple Availabilty Zones, making it more resilient than Lustre. 
- You can use the same OpenZFS file system to share the home directories on multiple clusters.

Download the LifeCycle Scripts (LCS), if you haven't done yet, [here](https://github.com/awsome-distributed-training/11.architecture/5.sagemaker-hyperpod/LifecycleScripts/base-confiig/). Then, modify `config.py` and change the `enable_fsx_openzfs = False` to `True`.

### Creating the file system
Navigate to the AWS Management Console and click on `Create File System`. Choose OpenZFS. Now, you choose if you want to deploy on multiple Availability Zones (AZ) or a single AZ. Both choices allow you to have a Highly Available solution. 

You don't need to change the metadata performance. Using Intelligent Tiering allows OpenZFS to select the best storage strategy for you, while you pay just for what you need. It is the recommended choice. 

Create at least one additional volume. Make sure you set the following parameters as the mount options: `no_root_squash, async, rw, crossmnt`. if you don't set `no_root_squash` SageMaker HypePod won't be able to set the proper permissions on the users' home directories. And `async` helps improving the performance as it will not wait the in-memory cache to persist the data before releasing the file for another operation. 

Creating at least one volume, and not using the root volume, increases the performance of OpenZFS. The way that OpenZFS manages its cache is based on those volumes. If you use the root volume, then it won't be able to properly manage the cache usage.

## Setting up observability
SageMaker HyperPod can install additional plug-ins for advanced monitoring of your cluster. To enable those feature, first download the LCS if you have not done so ([here](https://github.com/awsome-distributed-training/11.architecture/5.sagemaker-hyperpod/LifecycleScripts/base-confiig/)), then modify the `config.py` file. Change `enable_observability = False` to `True`. The observability feature will install tools such as NVIDIA DCGM exporter, EFA exporter, Node exporter, Slurm exporter, and many others. While their naming convention is not that creative, those tools exports important metrics required to properly monitor your cluster and jobs. 

You need an existing Prometheus URI to receive the data collected by those tools. If you don't have one setup now, you can follow [these](https://awslabs.github.io/ai-on-sagemaker-hyperpod/observability) instructions to set it up.

After you got your Prometheus URI up and running, then you add it to your `config,py` under the section `Configuration parameters for observability`. 

**TODO**: the config.py file redirects users to the old Workshop Studio catalog.

## Setting up Process-Level restarts (NVRX)
**TODO**:
- create a file that installs NVRX and NCCLRAS
- add an option to `config.py` that enables users to turn on/off that option
- upload code to ADT repo

## Quick Setup
If you have changed some of the LifeCycle Scripts (LCS), you will be able to upload your custom set of LCS when creating instance groups. Make sure you have uploaded them to your Amazon S3 bucket before you create your cluster.

If you are using OpenZFS as your Home Directories, you need to manually create a `provisioning_parameters.json` file and upload to the same bucket as your LCS. An example of this file can be found [here](https://github.com/awsome-distributed-training/1.architecture/5.sagemaker-hyperpod/LifeCycleScripts/base-config/provisioning_parameters_sample.json).

To create a SageMaker HyperPod in just a few clicks, navigate to the [Amazon Sagemaker AI](https://console.aws.amazon.com/sagemaker/home?region=us-west-2#/landing) console and click on `HyperPod Clusters`. Under [Cluster Management](https://console.aws.amazon.com/sagemaker/home?region=us-west-2#/cluster-management), click on the `Create HyperPod Cluster` button. More details, read the official AWS documentation [here](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html). 

![Amazon Sagemaker Hyperpod cluster creation experience](/img/01-cluster/slurm-cluster-creation-console.png)

- With the **quick setup** option you can launch a fully-operational cluster optimized for large-scale AI workloads directly from the AWS console using a streamlined single-page interface. It provisions all dependencies including VPCs, subnets, Amazon FSx storage, Slurm orchestrator, and the essential configurations required for building and deploying models. 

![Console experience with a single instance group](/img/01-cluster/orchestrated-by-slurm-setup.png)

After you click on Submit, you will see your cluster being created. You can check the console to verify what's the status of this process. When the clsuter shows as **InService** then you can start using it. The whole process usually don't take more than 20 minutes to be ready.

## Custom Setup
If you have changed some of the LifeCycle Scripts (LCS), you will be able to upload your custom set of LCS when creating instance groups. Make sure you have uploaded them to your Amazon S3 bucket before you create your cluster.

If you are using OpenZFS as your Home Directories, you need to manually create a `provisioning_parameters.json` file and upload to the same bucket as your LCS. An example of this file can be found [here](https://github.com/awsome-distributed-training/1.architecture/5.sagemaker-hyperpod/LifeCycleScripts/base-config/provisioning_parameters_sample.json).

To create a SageMaker HyperPod in just a few clicks, navigate to the [Amazon Sagemaker AI](https://console.aws.amazon.com/sagemaker/home?region=us-west-2#/landing) console and click on `HyperPod Clusters`. Under [Cluster Management](https://console.aws.amazon.com/sagemaker/home?region=us-west-2#/cluster-management), click on the `Create HyperPod Cluster` button. More details, read the official AWS documentation [here](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html). 

![Amazon Sagemaker Hyperpod cluster creation experience](/img/01-cluster/slurm-cluster-creation-console.png)

- The **custom setup** option empowers platform engineering teams familiar with AWS to customise the settings. You can use an existing subnet configurations, FSx storage soltuion, and customise the installations, all within the same unified console experience. At the end, you can either click on Submit and deploy, or download a custom generated CloudFormation parameters file and the respecitve CloudFormation template to add to your IaC (Infrastructure as a Code) pipeline. 

During the Custom Setup, you will use both file systems previously created and the modified LCS. 
