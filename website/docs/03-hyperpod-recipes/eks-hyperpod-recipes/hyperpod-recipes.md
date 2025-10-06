---
title: Setup and Launch training - EKS
sidebar_position: 1
---
# Install and use the Hyperpod CLI

## Prerequisites

1. You'll need to create a cluster with Amazon EKS on SageMaker HyperPod. Instructions can be found in [1. Cluster Setup](/docs/category/getting-started). Please follow them if you haven't done so already.

2. Dependencies - Make sure that you deployed GPU device plugin, EFA device plugin, and Kubeflow training operator to your cluster. See [Installing the required tools](/docs/category/getting-started) section and [Add-ons](/docs/category/add-ons
   ) section.

3. Fsx Lustre file system -  please follow the steps detailed in "**Set up your shared file system**" under Orchestrated by EKS section [here](/docs/category/getting-started) to create Fsx.

4. HyperPod Cli (recommended not mandatory) - Please follow the "**Installing the Hyperpod CLI**" installation instructions under [Add-ons](/docs/category/add-ons) section. 


## Environment

Set up the virtual environment. Make sure you're using Python 3.9 or greater.

```bash
python3 -m venv ${PWD}/venv
source venv/bin/activate
```

Download and setup HyperPod recipes repo.

```bash
git clone --recursive https://github.com/aws/sagemaker-hyperpod-recipes.git
cd sagemaker-hyperpod-recipes
pip3 install -r requirements.txt
```

## Data

HyperPod recipes support tokenized data in any of the below formats

* JSON
* JSONGZ (Compressed JSON)
* ARROW


## Launch training

### Using HyperPod Cli (Recommended)

We recommend using the SageMaker HyperPod command-line interface (CLI) tool to submit your training job with your configurations. The following example submits a training job for pretraining llama 3 8b model. You can check the [recipe config](https://github.com/aws/sagemaker-hyperpod-recipes/blob/main/recipes_collection/recipes/training/llama/hf_llama3_8b_seq16k_gpu_p5x16_pretrain.yaml) for more details. 

::alert[Replace the parameters in override-parameters section with actual values before submitting the job.]{header="Important" type="info"}

::alert[If you want to do a dry run without using actual data add the following parameter to the override-parameters section `"recipes.model.data.use_synthetic_data":"true"` .]{header="Important" type="info"}


::alert[You can provide the HuggingFace token if you need pre-trained weights from HuggingFace by adding the following key-value pair to the override-parameters section `"recipes.model.hf_access_token": "<your_hf_token>"`]{header="Important" type="info"}


```bash
hyperpod start-job --recipe training/llama/hf_llama3_8b_seq16k_gpu_p5x16_pretrain \
--persistent-volume-claims fsx-claim:data \
--override-parameters \
'{
 "recipes.run.name": "hf-llama3-8b",
 "recipes.exp_manager.exp_dir": "/data/<your_exp_dir>",
 "container": "658645717510.dkr.ecr.<region>.amazonaws.com/smdistributed-modelparallel:2.4.1-gpu-py311-cu121",
 "recipes.model.data.train_dir": "<your_train_data_dir>",
 "recipes.model.data.val_dir": "<your_val_data_dir>",
 "cluster": "k8s",
 "cluster_type": "k8s"
}'
```

::alert[You can also use any of the available recipes listed in the [HyperPod Recipes](https://github.com/aws/sagemaker-hyperpod-recipes/tree/main?tab=readme-ov-file#model-support) Git repo by chaning the --recipe parameters]

After you’ve submitted a training job, you can use the following command to verify if you submitted it successfully.

```bash
kubectl get pods
```

```
NAME                             READY   STATUS             RESTARTS        AGE
hf-llama3-<your-alias>-worker-0   0/1     running         0               36s
```

After the job STATUS changes to Running, you can examine the log by using the following command.

```bash
kubectl logs <name of pod>
```

Once the job is completed the `STATUS` of the pds will turn to Completed when you run kubectl get pods.

### Using recipes launcher

Alternatively, you can use the SageMaker HyperPod recipes to submit your training job. Using the recipes involves updating k8s.yaml, config.yaml and running the launch script.


* In `recipes_collection/cluster/k8s.yaml`, update persistent_volume_claims . It mounts the fsx claim to the /data directory of each computing pod

```persistent_volume_claims:
  - claimName: fsx-claim
    mountPath: data
```

* In `recipes_collection/config.yaml` , update repo_url_or_path under git to use the Hyperpod-recipes git URL

```
git:
  repo_url_or_path: <training_adapter_repo>
  branch: null
  commit: null
  entry_script: null
  token: null
```

HyperPod recipes provides a launch script for each recipe under launcher_scripts directory. In order to pretrain llama 3.1 8b model,  update the launch scripts under launcher_scripts/llama/run_hf_llama3_8b_seq16k_gpu_p5x16_pretrain.sh

The launch script should look like below 

```bash
#!/bin/bash
#Users should setup their cluster type in /recipes_collection/config.yaml
REGION="<region>"
IMAGE="658645717510.dkr.ecr.${REGION}.amazonaws.com/smdistributed-modelparallel:2.4.1-gpu-py311-cu121"
SAGEMAKER_TRAINING_LAUNCHER_DIR=${SAGEMAKER_TRAINING_LAUNCHER_DIR:-"$(pwd)"}
EXP_DIR="<your_exp_dir>" # Location to save experiment info including logging, checkpoints, ect
TRAIN_DIR="<your_training_data_dir>" # Location of training dataset
VAL_DIR="<your_val_data_dir>" # Location of talidation dataset

HYDRA_FULL_ERROR=1 python3 "${SAGEMAKER_TRAINING_LAUNCHER_DIR}/main.py" \
    recipes=training/llama/hf_llama3_8b_seq8k_gpu_p5x16_pretrain \
    base_results_dir="${SAGEMAKER_TRAINING_LAUNCHER_DIR}/results" \
    recipes.run.name="hf-llama3" \
    recipes.exp_manager.exp_dir="$EXP_DIR" \
    cluster=k8s \
    cluster_type=k8s \
    container="${IMAGE}" \
    recipes.model.data.train_dir=$TRAIN_DIR \
    recipes.model.data.val_dir=$VAL_DIR 
```

::alert[Replace the env variable in the script with actual values before submitting the job.]{header="Important" type="info"}

::alert[If you want to do a dry run without using actual data add the following parameter to the python command `recipes.model.data.use_synthetic_data=true` .]{header="Important" type="info"}

::alert[You can provide the HuggingFace token if you need pre-trained weights from HuggingFace by adding the following key-value pair to the python command `recipes.model.hf_access_token=<your_hf_token>`]{header="Important" type="info"}


Once the script is ready you can launch the training job using below command

```bash
bash launcher_scripts/llama/run_hf_llama3_8b_seq16k_gpu_p5x16_pretrain.sh
```

After you’ve submitted a training job, you can use the following command to verify if you submitted it successfully.

```bash
kubectl get pods
```

```
NAME                             READY   STATUS             RESTARTS        AGE
hf-llama3-<your-alias>-worker-0   0/1     running         0               36s
```

After the job STATUS changes to Running, you can examine the log by using the following command.

```bash
kubectl logs <name of pod>
```

Once the job is completed the `STATUS` of the pods will turn to Completed when you run kubectl get pods.
