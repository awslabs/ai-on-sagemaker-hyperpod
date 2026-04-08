---
title: "Setup and Launch training - Slurm"
sidebar_position: 2
weight: 71
---

## Prerequisites

1. You'll need to create a cluster with Amazon SageMaker HyperPod. Instructions can be found in [1. Cluster Setup](/docs/slurm-orchestration/getting-started/initial-cluster-setup). Please follow them if you haven't done so already.
 

## Environment

SSH into the head node of the cluster and run the following instructions.

1. Set up the virtual environment. Make sure you're using Python 3.9 or greater.

```bash
python3 -m venv ${PWD}/venv
source venv/bin/activate
```

2. Clone the SageMaker HyperPod recipes and SageMaker HyperPod adapter repositories to a shared storage location. 


```bash
git clone --recursive https://github.com/aws/sagemaker-hyperpod-recipes.git
cd sagemaker-hyperpod-recipes
pip3 install -r requirements.txt
```

3. Create a squash file using Enroot. To find the most recent release of the SMP container, see [SMP release notes](https://docs.aws.amazon.com/sagemaker/latest/dg/distributed-model-parallel-support-v2.html). To gain a deeper understanding of how to use the Enroot file, see Build [AWS-optimized Nemo-Launcher image](https://github.com/aws-samples/awsome-distributed-training/tree/main/3.test_cases/2.nemo-launcher#2-build-aws-optimized-nemo-launcher-image).


Use the below command to create a sqsh file. Set the AWS_REGION Env variable if not already set.

```bash
REGION=$AWS_REGION
IMAGE="658645717510.dkr.ecr.${REGION}.amazonaws.com/smdistributed-modelparallel:2.4.1-gpu-py311-cu121"
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin 855988369404.dkr.ecr.${REGION}.amazonaws.com
enroot import -o $PWD/smdistributed-modelparallel.sqsh dockerd://${IMAGE}
```

To use the Enroot squash file to start training, use the following example to modify the `recipes_collection/config.yaml` file in the sagemaker-hyperpod-recipes repository as shown below

```
container: /fsx/path/to/your/smdistributed-modelparallel.sqsh
```

## Data

HyperPod recipes support tokenized data in any of the below formats

* JSON
* JSONGZ (Compressed JSON)
* ARROW


## Launch training

After you install the necessary dependencies, start a training job from the `sagemaker-hyperpod-recipes/launcher_scripts` directory. You get the dependencies by cloning the SageMaker HyperPod recipes repository:


First, pick your training recipe from the [available recipes](https://github.com/aws/sagemaker-hyperpod-recipes/tree/main?tab=readme-ov-file#model-support), the model name is specified as part of the recipe and you can locate the corresponding launcher scripts under `launcher_scripts` directory. 

As an example We'll use the launcher_scripts/llama/run_hf_llama3_8b_seq16k_gpu_p5x16_pretrain.sh script to launch a Llama 8b with sequence length 8192 pre-training recipe. The launcher script as shown below runs a python script which is responsible to set up the slurm job. You need to modify the launcher script to change the paths to training and validation data. 

```

SAGEMAKER_TRAINING_LAUNCHER_DIR=${SAGEMAKER_TRAINING_LAUNCHER_DIR:-"$(pwd)"}

TRAIN_DIR="${TRAIN_DIR}" # Location of training dataset
VAL_DIR="${VAL_DIR}" # Location of validation dataset

EXP_DIR="${EXP_DIR}" # Location to save experiment info including logging, checkpoints, etc.


HYDRA_FULL_ERROR=1 python3 ${SAGEMAKER_TRAINING_LAUNCHER_DIR}/main.py \
    recipes=training/llama/hf_llama3_8b_seq8k_gpu_p5x16_pretrain \
    base_results_dir=${SAGEMAKER_TRAINING_LAUNCHER_DIR}/results \
    recipes.run.name="hf-llama3-8b" \
    recipes.exp_manager.exp_dir=$EXP_DIR \
    recipes.model.data.train_dir=$TRAIN_DIR \
    recipes.model.data.val_dir=$VAL_DIR \
```

:::info Important
If you want to do a dry run without using actual data add the following parameter to the python command `recipes.model.data.use_synthetic_data=true`.
:::

:::info Important
You can provide the HuggingFace token if you need pre-trained weights from HuggingFace by adding the following key-value pair to the python command `recipes.model.hf_access_token=<your_hf_token>`
:::

Once you have the launcher script updated, you can run the below command to start the training job

```bash
bash launcher_scripts/llama/run_hf_llama3_8b_seq8k_gpu_lora.sh
```

You should be able to see the job created by using squeue. 

The corresponding logs can be found under the results folder.