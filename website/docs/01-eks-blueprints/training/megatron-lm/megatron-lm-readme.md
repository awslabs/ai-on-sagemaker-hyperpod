---
title: NVIDIA Megatron-LM
sidebar_position: 1
sidebar_label: NVIDIA Megatron-LM
---

# Running Megatron-LM on HyperPod EKS

[MegatronLM](https://github.com/NVIDIA/Megatron-LM) is a framework from Nvidia designed for training large language models (LLMs). We recommend reading the following papers to understand the various tuning options available:

- [Megatron-LM: Training Multi-Billion Parameter Language Models Using Model Parallelism](https://arxiv.org/abs/1909.08053)
- [Efficient Large-Scale Language Model Training on GPU Clusters Using Megatron-LM](https://arxiv.org/abs/2104.04473)
- [Reducing Activation Recomputatio in Large Transformer Models](https://arxiv.org/pdf/2205.05198)

To run a test case, follow these steps:

1. Prepare your environment.
2. Build a container, download, and preprocess the data.
3. Train the model.

## 1. Preparation

Ensure you have the following prerequisites:

- A functional HyperPod EKS cluster on AWS with EFA device plugin and NVIDIA device plugin deployed. This should be installed automatically.
- Docker installed for building the container image.
- An FSx for Lustre filesystem mounted via a persistent volume claim on `/fsx` in EKS pods. An example of setting up FSx on EKS is available [here](https://docs.aws.amazon.com/eks/latest/userguide/fsx-csi-create.html).
- To run distributed training jobs as described in this guide, you must also have the [Kubeflow Training Operator](https://www.kubeflow.org/docs/components/training/) installed and configured on your HyperPod EKS cluster. This should be installed automatically via our [helm charts](https://github.com/aws/sagemaker-hyperpod-cli/tree/main/helm_chart). If not installed, please install helm charts. 

### 1.1 Clone the Repository

First, clone the awesome-distributed-training repository to get access to the Dockerfile and Kubernetes manifests:

```bash
git clone https://github.com/aws-samples/awsome-distributed-training.git
cd awsome-distributed-training/3.test_cases/megatron/megatron-lm
```

## 2. Building the Container

1. You should now be in the `awsome-distributed-training/3.test_cases/megatron/megatron-lm` directory which contains the `aws-megatron-lm.Dockerfile`.

2. Build the container image:

```bash
docker build -t aws-megatron-lm -f aws-megatron-lm.Dockerfile .
```

3. Tag and push the image to your container registry:

```bash
export AWS_REGION=us-east-1  # Set to the AWS region where your EKS cluster and ECR repository are located
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
export ECR_REPOSITORY_NAME=aws-megatron-lm
export REPO_URI=${REGISTRY}/${ECR_REPOSITORY_NAME}:latest

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} 2>/dev/null || \
aws ecr create-repository --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION}

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}

docker tag ${ECR_REPOSITORY_NAME}:latest ${REGISTRY}/${ECR_REPOSITORY_NAME}:latest
docker push ${REGISTRY}/${ECR_REPOSITORY_NAME}:latest
```

Now you are all set for distributed training with Megatron-LM on EKS! Proceed to the GPT3 training section for detailed instructions.

## 3. GPT Model Training on HyperPod EKS with Megatron-LM

Before proceeding with GPT training setup, please follow the steps described above to prepare your environment.
The following example assumes that you have a PVC named `fsx-claim` and the `REPO_URI` environment variable is exported.

### 3.1 Determine Compute Resources

Before running the training, you need to determine the compute resources available on your EKS cluster nodes. This will help you set the correct resource limits for GPUs and EFA (Elastic Fabric Adapter) network interfaces.

Export the following environment variables based on your instance type:

```bash
# Example for p5.48xlarge
export INSTANCE_TYPE=ml.p5.48xlarge
export GPU_PER_NODE=8
export EFA_PER_NODE=32
export NUM_NODES=2
```

You can refer to the following table to find the correct values for your instance type:

| Instance Type | GPUs | EFA Interfaces |
|---------------|------|----------------|
| ml.p5.48xlarge   | 8    | 32             |
| ml.p5e.48xlarge  | 8    | 32             |
| ml.p5en.48xlarge | 8    | 16             |
| ml.p6-b200.48xlarge | 8 | 8             |

### 3.2 Data Preprocessing

1. Navigate to the GPT3 manifests directory and run the following snippet to create a job container that mounts the fsx volume and downloads the input datasets and vocabulary on it:

    ```bash
    cd kubernetes/gpt3
    ```

    #### Step 1: Create and Apply the Data Download Job

    Generate the `getdata-job.yaml` manifest from the template and apply it:

    ```bash
    envsubst < manifests/getdata-job.yaml-template > manifests/getdata-job.yaml
    kubectl apply -f manifests/getdata-job.yaml
    ```

    #### Step 2: Verify Job Creation

    List jobs to confirm creation:

    ```bash
    kubectl get jobs
    ```

    You should see an entry for `getdata-job` with information about its status, completions, and age. To get more details about the pods created by the job, run:

    ```bash
    kubectl get pods -l job-name=getdata-job
    ```

    This will show the pod(s) managed by the job. If you want to describe the job and see events or issues, use:

    ```bash
    kubectl describe job getdata-job
    ```

    #### Step 3: Monitor Job Progress

    Stream the logs to monitor download progress:

    ```bash
    kubectl logs -f job/getdata-job
    ```
    
    You should be able to see output similar to the following once the downloads have completed successfully:

        ```text
    ...
    Saving to: 'gpt2-merges.txt'

         0K .......... .......... .......... .......... .......... 11% 19.2M 0s
        50K .......... .......... .......... .......... .......... 22% 55.9M 0s
       100K .......... .......... .......... .......... .......... 33% 57.3M 0s
       150K .......... .......... .......... .......... .......... 44% 66.1M 0s
       200K .......... .......... .......... .......... .......... 56%  106M 0s
       250K .......... .......... .......... .......... .......... 67%  132M 0s
       300K .......... .......... .......... .......... .......... 78%  139M 0s
       350K .......... .......... .......... .......... .......... 89%  133M 0s
       400K .......... .......... .......... .......... .....     100%  122M=0.007s

    2025-06-20 08:59:58 (62.9 MB/s) - 'gpt2-merges.txt' saved [456318/456318]

    total 940M
    drwxr-xr-x 2 root root   33K Jun 20 09:00 .
    drwxr-xr-x 5 root root   33K Jun 20 08:59 ..
    -rw-r--r-- 1 root root  446K Feb 18  2019 gpt2-merges.txt
    -rw-r--r-- 1 root root 1018K Feb 18  2019 gpt2-vocab.json
    -rw-r--r-- 1 root root  1.1G Jul 24  2021 oscar-1GB.jsonl
    Download completed.
    ```
    


    #### Step 4: Cleanup

    Once the job status is `Completed`, delete the job and its pod:

    ```bash
    kubectl delete -f manifests/getdata-job.yaml
    ```

2. **Preprocess the Data**

    Launch the preprocessing job to convert the downloaded data for training.

    ```bash
    cat manifests/prepdata-job.yaml-template | envsubst > manifests/prepdata-job.yaml
    kubectl apply -f ./manifests/prepdata-job.yaml
    ```

    Check pods for `prepdata-job`:

    ```bash
    kubectl get pods -l job-name=prepdata-job
    ```

    Monitor the job's progress by streaming its logs:

    ```bash
    kubectl logs -f job/prepdata-job
    ```

    The expected log output from the above command should look similar to the following when preprocessing completes successfully:

    ```text
    ...
    -rw-r--r--  1 root root 3.4K Jun 14 02:55 pretrain_vision_classify.py
    -rw-r--r--  1 root root 3.5K Jun 14 02:55 pretrain_vision_dino.py
    -rw-r--r--  1 root root 4.8K Jun 14 02:55 pretrain_vision_inpaint.py
    -rw-r--r--  1 root root 8.2K Jun 14 02:55 pretrain_vlm.py
    -rw-r--r--  1 root root  824 Jun 14 02:55 pyproject.toml
    -rw-r--r--  1 root root 4.0K Jun 14 02:55 setup.py
    drwxr-xr-x  8 root root  200 Jun 14 02:55 tasks
    drwxr-xr-x  4 root root   67 Jun 14 02:55 tests
    drwxr-xr-x  6 root root 4.0K Jun 14 02:55 tools
    Data preprocessing completed.
    ```

    After the job status is `Completed`, clean up the job and its pod:

    ```bash
    kubectl delete -f prepdata-job.yaml
    ```

    Voilà! The preprocessing job has finished. You are now ready to proceed to the training step.

### 3.3 Distributed Training

Now that the data is preprocessed, we will pretrain a GPT3 model MegatronLM.  Launch a PyTorchJob with the environment variables:

```bash
export TENSOR_PARALLEL=8
export PIPELINE_PARALLEL=1
export NUM_LAYERS=36
export HIDDEN_SIZE=4096
export NUM_ATTENTION_HEADS=32
export SEQ_LENGTH=2048
export MAX_POSITION_EMBEDDINGS=2048
export MICRO_BATCH_SIZE=1
export GLOBAL_BATCH_SIZE=288
cat manifests/pytorchjob.yaml-template | envsubst > manifests/pytorchjob.yaml
kubectl apply -f ./manifests/pytorchjob.yaml
```

The training starts running:

```bash
kubectl get pods
```

You should see one etcd and one worker pod.

```bash
NAME                    READY   STATUS      RESTARTS   AGE
etcd-7787559c74-wpcb9   1/1     Running     0          3m10s
megatron-worker-0       1/1     Running     0          3m10s
```

Log lines describing the iterations show that the training is working properly.

```bash
kubectl logs -f megatron-worker-0
```

An abbreviated sample log is shown below:

```text
...
using torch.float16 for parameters ...
------------------------uments ------------------------
accumulate_allreduce_grads_in_fp32 .............. False
adam_beta1 ...................................... 0.9
adam_beta2 ...................................... 0.95
...
-------------------- end of arguments ---------------------
setting number of micro-batches to constant 288
> building GPT2BPETokenizer tokenizer ...
> padded vocab (size: 50257) with 943 dummy tokens (new size: 51200)
> initializing torch distributed ...
> initialized tensor model parallel with size 8
> initialized pipeline model parallel with size 1
> setting random seeds to 1234 ...
> compiling dataset index builder ...
make: Entering directory '/workspace/Megatron-LM/megatron/core/datasets'
...
time to initialize megatron (seconds): 15.424
[after megatron is initialized] datetime: 2024-07-16 22:14:01
building GPT model ...
> number of parameters on (tensor, pipeline) model parallel rank (4, 0): 941594624
...
> building train, validation, and test datasets ...
> datasets target sizes (minimum size):
    train:      146484375
    validation: 5863680
    test:       11520
...
iteration        1/  508626 | consumed samples:          288 | elapsed time per iteration (ms): 255940.5 | learning rate: 0.000E+00 | global batch size:   288 | loss scale: 4294967296.0 | number of skipped iterations:   1 | number of nan iterations:   0 |
iteration        2/  508626 | consumed samples:          576 | elapsed time per iteration (ms): 243438.3 | learning rate: 0.000E+00 | global batch size:   288 | loss scale: 2147483648.0 | number of skipped iterations:   1 | number of nan iterations:   0 |
iteration        3/  508626 | consumed samples:          864 | elapsed time per iteration (ms): 243344.4 | learning rate: 0.000E+00 | global batch size:   288 | loss scale: 1073741824.0 | number of skipped iterations:   1 | number of nan iterations:   0 |
...
```

You can stop the training job by executing:

```bash
kubectl delete -f ./pytorchjob.yaml
```

## 4. What's Next?

The example is based on the GPT3 example from MegatronLM's [repository](https://github.com/NVIDIA/Megatron-LM/blob/main/examples/pretrain_gpt.sh). You can modify `NUM_ATTENTION_HEADS`, `NUM_LAYERS`, and `HIDDEN_SIZE` based on the Table 1 (Page 8) of the document [Efficient Large-Scale Language Model Training on GPU Clusters Using Megatron-LM](https://arxiv.org/abs/2104.04473) to change the model size. You can launch training for different model sizes by setting the environment variables before applying the PyTorchJob, for example: `NUM_LAYERS=64 HIDDEN_SIZE=8192 NUM_ATTENTION_HEADS=48`

| Model size | Parameters                                                |
|------------|-----------------------------------------------------------|
| 1.7B       | `NUM_ATTENTION_HEADS=24 HIDDEN_SIZE=2304 NUM_LAYERS=24`   |
| 3.6B       | `NUM_ATTENTION_HEADS=32 HIDDEN_SIZE=3072 NUM_LAYERS=30`   |
| 7.5B       | `NUM_ATTENTION_HEADS=32 HIDDEN_SIZE=4096 NUM_LAYERS=36`   |
| 18.4B      | `NUM_ATTENTION_HEADS=48 HIDDEN_SIZE=6144 NUM_LAYERS=40`   |
| 39.1B      | `NUM_ATTENTION_HEADS=64 HIDDEN_SIZE=8192 NUM_LAYERS=48`   |
| 76.1B      | `NUM_ATTENTION_HEADS=80 HIDDEN_SIZE=10240 NUM_LAYERS=60`  |
| 145.6B     | `NUM_ATTENTION_HEADS=96 HIDDEN_SIZE=12288 NUM_LAYERS=80`  |
| 310.1B     | `NUM_ATTENTION_HEADS=128 HIDDEN_SIZE=16384 NUM_LAYERS=96` |

## 5. Appendix

### 5.1 Benchmark Mode

To run in benchmark mode (i.e., train only, no validation and test), modify the PyTorchJob arguments in the `pytorchjob.yaml-template` file:

```diff
-        --eval-iters 40 \
-        --eval-interval 1000 \
-        --split 98,2,0 \
+        --eval-iters 0 \
+        --split 100,0,0 \
```

Incorrect settings will cause this error message to appear in the training logs:

```text
Traceback (most recent call last):
  File "/workspace/Megatron-LM/pretrain_gpt.py", line 198, in <module>
    pretrain(train_valid_test_datasets_provider,
  File "/workspace/Megatron-LM/megatron/training.py", line 227, in pretrain
    = build_train_valid_test_data_iterators(
  File "/workspace/Megatron-LM/megatron/training.py", line 1283, in build_train_valid_test_data_iterators
    build_train_valid_test_data_loaders(
  File "/workspace/Megatron-LM/megatron/training.py", line 1244, in build_train_valid_test_data_loaders
    train_ds, valid_ds, test_ds = build_train_valid_test_datasets(
  File "/workspace/Megatron-LM/megatron/training.py", line 1214, in build_train_valid_test_datasets
    return build_train_valid_test_datasets_provider(train_val_test_num_samples)
  File "/workspace/Megatron-LM/pretrain_gpt.py", line 186, in train_valid_test_datasets_provider
    ).build()
  File "/workspace/Megatron-LM/megatron/core/datasets/blended_megatron_dataset_builder.py", line 56, in build
    return self._build_blended_dataset_splits()
  File "/workspace/Megatron-LM/megatron/core/datasets/blended_megatron_dataset_builder.py", line 76, in _build_blended_dataset_splits
    return self._build_megatron_dataset_splits(blend[0], split, self.sizes)
  File "/workspace/Megatron-LM/megatron/core/datasets/blended_megatron_dataset_builder.py", line 216, in _build_megatron_dataset_splits
    self.build_generic_dataset(
  File "/workspace/Megatron-LM/megatron/core/datasets/blended_megatron_dataset_builder.py", line 258, in build_generic_dataset
    dataset = cls(*args)
  File "/workspace/Megatron-LM/megatron/core/datasets/gpt_dataset.py", line 68, in __init__
    super().__init__(indexed_dataset, indexed_indices, num_samples, index_split, config)
  File "/workspace/Megatron-LM/megatron/core/datasets/megatron_dataset.py", line 42, in __init__
    assert num_samples > 0
AssertionError
```

### 5.2 Adjust Training Steps

By default, the PyTorchJob specifies the number of samples, then the number of training steps equals to `--train_samples` / `--global-batch-size`. To directly specify the number of steps, modify the arguments in the `pytorchjob.yaml-template` file. Note that `samples` and `iters` are mutually exclusive.

```diff
-        --train-samples 146484375 \
-        --lr-decay-samples 126953125 \
-        --lr-warmup-samples 183105 \
+        --train-iters 50 \
+        --lr-decay-iters 45 \
+        --lr-warmup-iters 2 \
```

Following the same pattern, you can train other models. Pretraining scripts for models like 
Bert, ICT, and T5 are already included in the Megatron-LM container under `/workspace/Megatron-LM`.

## 6. Kubernetes Manifests

The training setup uses three main Kubernetes manifest templates located in the `kubernetes/gpt3/manifests/` directory of the cloned repository:

- **`getdata-job.yaml-template`** - Downloads training data and vocabulary files
- **`prepdata-job.yaml-template`** - Preprocesses data for training
- **`pytorchjob.yaml-template`** - Runs distributed training using PyTorchJob

:::info
The manifest templates use environment variable substitution with `envsubst`. Make sure all required environment variables are exported before generating the final manifests.
:::

## 7. Directory Structure

After cloning the repository, your directory structure should look like this:

```
awsome-distributed-training/
└── 3.test_cases/
    └── megatron/
        └── megatron-lm/
            ├── aws-megatron-lm.Dockerfile
            ├── README.md
            ├── kubernetes/
            │   ├── README.md
            │   └── gpt3/
            │       ├── README.md
            │       └── manifests/
            │           ├── getdata-job.yaml-template
            │           ├── prepdata-job.yaml-template
            │           └── pytorchjob.yaml-template
            └── slurm/ 
```

For additional examples and configurations, refer to the [awesome-distributed-training repository](https://github.com/aws-samples/awsome-distributed-training/tree/main/3.test_cases/megatron/megatron-lm) and the [Megatron-LM GitHub repository](https://github.com/NVIDIA/Megatron-LM).