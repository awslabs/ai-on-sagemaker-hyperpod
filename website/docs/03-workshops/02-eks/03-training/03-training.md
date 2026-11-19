---
title: Training
sidebar_position: 3
---

# Training

## 🚀 Launch Training

**Objective**: Submit a distributed training job to train ESM2 across 2 GPU nodes.

**What's happening**: You'll create a `HyperPodPyTorchJob` that:

- Distributes training across 2x `ml.g5.2xlarge` instances
- Uses FSDP (Fully Sharded Data Parallel) for efficient training
- Monitors for hangs and failures
- Saves checkpoints to FSx every 50 steps
- Automatically recovers from failures

**Time to complete**: ~15 minutes (but you can move on while it trains!)

Now we are ready to submit a distributed training job to pretrain the ESM2 model. We provide the following `train.yaml` template to run training on HyperPod cluster compute nodes with a certain number of GPUs, per node specification.

## Data

The training job reads the [UniRef50](https://huggingface.co/datasets/agemagician/uniref50) dataset, which is data specifically for ML models on protein sequences. It has been pre-tokenized into Apache Arrow format and placed in the `DATASET_DIR` environment variable directory (`/fsx/arrow`), which is what the training job reads. Model checkpoints and the final model are written to the `TARGET_PATH` directory (`/fsx/esm`, with output under `OUTPUT_DIR=/fsx/esm/output`).

:::note Staging the dataset
At an AWS-hosted event this data is downloaded into the FSx for Lustre file system during account provisioning, because the download can take ~30 minutes. Running the workshop in your own account, download and tokenize the dataset onto `/fsx/arrow` before submitting the job (an [FSx for Lustre data repository association](https://docs.aws.amazon.com/fsx/latest/LustreGuide/create-dra-linked-data-repo.html) from an S3 bucket is a convenient way to do this).
:::

:::tip
You may not be able to see this dataset from your Code Editor instance. In order to demonstrate partitions (and setting up boundaries) on file systems, only the `/shared` partition from the file system is mounted onto the Code Editor instance. Think of yourself as an ML Engineer that's been told "the dataset resides here, go train a model for me now"!

This is actually a realistic scenario — data scientists prepare data, infrastructure sets up storage, and you (ML Engineer) make the training happen! 🎯
:::

### (Optional) Peek at the dataset on FSx

Since the `/fsx` file system isn't mounted into your Code Editor instance, how can you actually confirm the data is there before you launch a job? Just like a real ML Engineer, you can spin up a throwaway pod that mounts the FSx volume (via the `fsx-claim` PVC) and browse it directly.

Launch a helper pod that mounts FSx at `/fsx`:

```bash
kubectl run fsx-pod --image=ubuntu:latest --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"fsx-pod","image":"ubuntu:latest","command":["sleep","infinity"],"volumeMounts":[{"name":"fsx-volume","mountPath":"/fsx"}]}],"volumes":[{"name":"fsx-volume","persistentVolumeClaim":{"claimName":"fsx-claim"}}]}}'
```

Wait for it to be `Running`, then exec into it:

```bash
kubectl get pod fsx-pod
kubectl exec -it fsx-pod -- bash
```

Inside the pod, inspect the tokenized dataset at `DATASET_DIR` (`/fsx/arrow`):

```bash
ls /fsx/arrow
ls /fsx/arrow/train
```

You should see the dataset splits and the Apache Arrow shards that the training job reads:

```
dataset_dict.json  test  train  validation
```

```
data-00000-of-00062.arrow  data-00001-of-00062.arrow  data-00002-of-00062.arrow  ...  dataset_info.json  state.json
```

This is the pre-tokenized UniRef50 data that the training job consumes via `--dataset_dir=${DATASET_DIR}`. Exit the pod shell with `exit` when done — we'll leave the pod running so you can reuse it to inspect your checkpoints after training.

```bash
exit
```

## 1. Create HyperPodPytorchJob YAML

We use the following template to submit a training job to our SageMaker HyperPod cluster. As always, please run the command below from the terminal of your Code Editor instance!

```bash
cat << 'EOF' > train.yaml
apiVersion: sagemaker.amazonaws.com/v1
kind: HyperPodPyTorchJob
metadata:
  name: hpto-job
spec:
  nprocPerNode: "$GPU_PER_NODE"
  runPolicy:
    jobMaxRetryCount: 10
    restartPolicy:
      numRestartBeforeFullJobRestart: 3
      evalPeriodSeconds: 21600
      maxFullJobRestarts: 1
    cleanPodPolicy: All
    logMonitoringConfiguration:
    - name: JobStart
      logPattern: ".*'loss':.*"
      expectedStartCutOffInSeconds: 240
    - name: JobHangingDetection
      logPattern: ".*'loss':.*"
      expectedRecurringFrequencyInSeconds: 600
  replicaSpecs:
    - name: pods
      replicas: ${NUM_NODES}
      template:
        metadata:
          labels:
            job-name: esm-hpto
            replica-type: pods
        spec:
          volumes:
            - name: fsx-storage
              persistentVolumeClaim:
                claimName: fsx-claim
            - name: shmem
              hostPath:
                path: /dev/shm
            - name: local
              hostPath:
                path: /mnt/k8s-disks/0
          affinity:
            podAntiAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                - labelSelector:
                    matchLabels:
                      job-name: esm-hpto
                  topologyKey: kubernetes.io/hostname
          containers:
            - name: pytorch
              image: ${REGISTRY}${DOCKER_IMAGE_NAME}:${TAG}
              resources:
                requests:
                  nvidia.com/gpu: ${GPU_PER_NODE}
                  vpc.amazonaws.com/efa: ${EFA_PER_NODE}
                limits:
                  nvidia.com/gpu: ${GPU_PER_NODE}
                  vpc.amazonaws.com/efa: ${EFA_PER_NODE}
              env:
                - name: NCCL_DEBUG
                  value: "INFO"
                - name: POD_RANK
                  valueFrom:
                    fieldRef:
                      fieldPath: metadata.labels['training.kubeflow.org/replica-index']
                - name: FI_PROVIDER
                  value: "efa"
                - name: NCCL_SOCKET_IFNAME
                  value: "eth0"
                - name: NCCL_SHM_USE_CUDA_MEMCPY  # 2x performance in comparison to default memcpy
                  value: "1"
                - name: NCCL_PROTO
                  value: "simple"
                - name: FI_EFA_FORK_SAFE
                  value: "1"
              volumeMounts:
                - mountPath: /fsx
                  name: fsx-storage
              imagePullPolicy: Always
              command:
                - /bin/bash
                - -c
                - |
                  hyperpodrun \
                    --tee=3 \
                    --log_dir=/tmp/hyperpod \
                    --nproc_per_node=$GPU_PER_NODE \
                    --nnodes=$NUM_NODES \
```

:::warning Source manifest incomplete
The upstream workshop page truncates this code block part-way through the container's `command:` section, so the remainder of the `hyperpodrun` invocation — the training script and its arguments — could not be captured verbatim. The page documents these arguments elsewhere: the training script reads `--dataset_dir=${DATASET_DIR}`, writes to `--output_dir=${OUTPUT_DIR}`, uses `--save_steps=50`, and trains the model named in `${MODEL}` (`facebook/esm2_t6_8M_UR50D`).

For the complete, runnable manifest and the ESM2 training container, use the workshop assets repository: [Guidance for protein language ESM model training with SageMaker HyperPod](https://github.com/aws-solutions-library-samples/guidance-for-protein-language-esm-model-training-with-sagemaker-hyperpod) and the [awsome-distributed-ai](https://github.com/awslabs/awsome-distributed-ai/tree/main/examples) examples. Append the training command and the closing `EOF` before running `envsubst`.
:::

Notice all the unsubstituted environment variables here (e.g., `${GPU_PER_NODE}`). Remember, this is just a template. The magic happens below (via `envsubst`)!

## 2. Understanding your HyperPod PytorchJob YAML Configuration

At its core, a HyperPod PytorchJob defines a custom Kubernetes resource for running PyTorch jobs across multiple nodes:

```yaml
apiVersion: sagemaker.amazonaws.com/v1
kind: HyperPodPyTorchJob
metadata:
  name: hpto-job
```

The YAML implements robust error handling through retry policies and log monitoring. What we are doing in the following snippet is:

- **JobStart**: Fails if no loss line appears in logs within the first 4 minutes (240s)
- **JobHangingDetection**: Fails if the gap between logs exceeds 10 minutes (600s)
- In our `restartPolicy`, we allow 3 process restarts before full job restart, and a maximum of 10 total retries

```yaml
runPolicy:
  jobMaxRetryCount: 10
  restartPolicy:
    numRestartBeforeFullJobRestart: 3
    evalPeriodSeconds: 21600
    maxFullJobRestarts: 1
  cleanPodPolicy: All
  logMonitoringConfiguration:
  - name: JobStart
    logPattern: ".*'loss':.*"
    expectedStartCutOffInSeconds: 240
  - name: JobHangingDetection
    logPattern: ".*'loss':.*"
    expectedRecurringFrequencyInSeconds: 600
```

Finally, the command section launches the training with our `hyperpodrun` launch command, purpose built for our training operator:

```bash
hyperpodrun \
  --tee=3 \
  --log_dir=/tmp/hyperpod \
  --nproc_per_node=$GPU_PER_NODE \
  --nnodes=$NUM_NODES \
```

To enable auto-resume, the checkpoints are written to FSx which allows all the nodes to have a shared file system with checkpoints accessible to all:

```yaml
volumes:
  - name: shmem
    hostPath:
      path: /dev/shm
  - name: local
    hostPath:
      path: /mnt/k8s-disks/0
  - name: fsx-storage
    persistentVolumeClaim:
      claimName: fsx-claim   # Your FSx PVC
volumeMounts:
  ...
```

With this argument, we are placing checkpoints in FSx:

```bash
--output_dir=${OUTPUT_DIR}
```

## 3. Run Training Job

To initiate the PyTorch training job, run the command:

```bash
envsubst < train.yaml | kubectl apply -f -
```

`envsubst` will automatically substitute all `${VARIABLE}` with the actual value(s) for `VARIABLE` as set in your environment variables.

You should see output:

```
hyperpodpytorchjob.sagemaker.amazonaws.com/hpto-job created
```

:::tip Want to see the manifest that was submitted?
Render the template without applying it: `envsubst < train.yaml`, or inspect the live object with `kubectl get hyperpodpytorchjob hpto-job -o yaml`.
:::

To see your pods, run:

```bash
kubectl get pods
```

The jobs should show a `Running` status:

```
NAME                             READY   STATUS    RESTARTS   AGE
hpto-job-pods-794bd5fb5c-2brnb   1/1     Running   0          3m28s
hpto-job-pods-794bd5fb5c-7xjs2   1/1     Running   0          3m27s
```

To see logs of the job, we use `kubetail`:

:::note What is kubetail?
[kubetail](https://github.com/kubetail-org/kubetail) tails and merges the logs of multiple pods at once, prefixing each line with the pod it came from — handy for a distributed training job spread across several pods.
:::

View logs:

```bash
kubetail hpto
```

To exit pod logs, press Ctrl+C.

## Training! 🎉

You do not have to wait for the training to complete as this takes approximately 10 minutes. If you waited for the training to complete, you will see the output below.

```
Training completed. Do not forget to share your model on huggingface.co/models =)
{'train_runtime': 533.8102, 'train_samples_per_second': 187.333, 'train_steps_per_second': 2.128, 'train_loss': 2.6585248691934935, 'epoch': 1.0}
***** eval metrics *****
  epoch                   =     0.9997
  eval_accuracy           =     0.2008
  eval_loss               =     2.6318
  eval_runtime            = 0:01:33.76
  eval_samples            =      50000
  eval_samples_per_second =    533.242
  eval_steps_per_second   =     33.328
  perplexity              =    13.8984
```

:::note Seeing a SIGTERM / SignalException traceback after the metrics? That's expected ✅
The elastic agent tears the worker processes down with `SIGTERM` once training and evaluation have finished. The metrics above it are your signal that the run succeeded.
:::

Congratulations on running your first distributed training job on SageMaker HyperPod using the HP Training Operator!

## (Optional) Inspect your checkpoints on FSx

Your training job writes checkpoints and the final model to the `TARGET_PATH` directory (`/fsx/esm/output`, set via `OUTPUT_DIR`). Just like with the dataset, this lives on FSx and isn't visible from Code Editor — so let's reuse the `fsx-pod` helper we launched earlier to take a look.

If you didn't create the `fsx-pod` earlier (or deleted it), launch it now. The `|| true` makes the command safe to re-run — it will simply skip if the pod already exists.

```bash
kubectl run fsx-pod --image=ubuntu:latest --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"fsx-pod","image":"ubuntu:latest","command":["sleep","infinity"],"volumeMounts":[{"name":"fsx-volume","mountPath":"/fsx"}]}],"volumes":[{"name":"fsx-volume","persistentVolumeClaim":{"claimName":"fsx-claim"}}]}}' || true
```

Exec into the pod and browse the output directory:

```bash
kubectl exec -it fsx-pod -- bash
```

Inside the pod:

```bash
ls /fsx/esm/output
```

You'll see the periodic checkpoints (saved every `save_steps`) alongside the final model artifacts:

```
README.md          checkpoint-100   checkpoint-1136  config.json         model.safetensors
all_results.json   checkpoint-1000  ...              eval_results.json   trainer_state.json
train_results.json vocab.txt
```

Each `checkpoint-*` directory is a resumable training state, and `model.safetensors` + `config.json` are the final trained ESM2 model — exactly what you'd deploy or fine-tune later. Exit the shell when done:

```bash
exit
```

:::warning
Be careful not to delete or modify anything under `/fsx/esm/output` or `/fsx/arrow` — this is the same live file system your training jobs read from and write to. Browsing is safe; editing is not.
:::

## ✅ Success!

You've successfully:

- ✅ Submitted a distributed training job
- ✅ Trained ESM2 across 2 GPU nodes
- ✅ Saved checkpoints to FSx
- ✅ Monitored training with `kubectl` and `kubetail`

Up next, resiliency...
