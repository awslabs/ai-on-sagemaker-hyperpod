---
title: "Scale up"
sidebar_position: 5
weight: 24
---

In this session, we ran a small training of Llama 8B on a single node. But scaling up training is just a simple few steps. 

Let's say, for example, you want to train a Llama 70B model on 16 nodes.

1. Modify your `cluster-config.json` to bring up a cluster with 16 x `trn1.32xlarge` nodes:

```json
[
  {
    "InstanceGroupName": "controller-machine",
    "InstanceType": "ml.c5.xlarge",
    "InstanceCount": 1,
    "LifeCycleConfig": {
      "SourceS3Uri": "s3://${BUCKET}/src",
      "OnCreate": "on_create.sh"
    },
    "ExecutionRole": "${ROLE}",
    "ThreadsPerCore": 2
  },
  {
    "InstanceGroupName": "worker-group-1",
    "InstanceType": "ml.trn1.32xlarge",
    "InstanceCount": 16,
    "LifeCycleConfig": {
      "SourceS3Uri": "s3://${BUCKET}/src",
      "OnCreate": "on_create.sh"
    },
    "ExecutionRole": "${ROLE}",
    "ThreadsPerCore": 1
  }
]
```

2. Update your cluster:

```bash
aws sagemaker update-cluster \
    --cluster-name ml-cluster \
    --instance-groups file://cluster-config.json \
    --region $AWS_REGION
```

3. Once the update is complete, ssh into the cluster and create a `llama_70b.sh` training configuration:

Replace the `config.json` and tokenizer.
```
cp llama3-70B/* .
```
First do compilation for this new model.

```bash
#!/bin/bash
#SBATCH -N 16
#SBATCH --exclusive
#SBATCH -o llama_compile.out

export OMP_NUM_THREADS=1

export COMPILE=1
export CONF_FILE=hf_llama3_70B_config

srun ./train.sh
```

* Notice that we've added pipeline parallelism. This splits the model across devices by layers. It's a good idea to also increase your global batch size (GBS) when using pipeline parallelism, as it means less downtime (sometimes referred to as bubbles).

4. Create a new `sbatch` file that launches a 16 node training job:

```bash
#!/bin/bash
#SBATCH -N 16
#SBATCH --exclusive
#SBATCH -o llama_train.out

export OMP_NUM_THREADS=1

export COMPILE=0
export CONF_FILE=hf_llama3_70B_config

srun ./train.sh

```

And that's it! The training script already contains the logic to handle multi-node training.

Since we are currently training on a small subset of the C4 data, you might also want to get a larger dataset (perhaps the rest of the C4 data, available from [HuggingFace](https://huggingface.co/datasets/allenai/c4)), which can be pre-process for [NeuronX Nemo](https://github.com/aws-neuron/neuronx-nemo-megatron/tree/main) using the data preprocessing from [Megatron](https://github.com/NVIDIA/Megatron-LM/blob/main/tools/preprocess_data.py).
