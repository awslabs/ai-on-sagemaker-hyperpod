---
title: Training
sidebar_position: 3
---

# Training

## 🚀 Launch training

**Objective:** submit a distributed training job to train ESM2 across 2 GPU nodes.

**What's happening:** you'll create a `HyperPodPyTorchJob` that:

- Distributes training across 2x `ml.g7.2xlarge` instances
- Uses FSDP (Fully Sharded Data Parallel) for efficient training
- Monitors for hangs and failures
- Saves checkpoints to FSx every 50 steps
- Automatically recovers from failures

**Time to complete:** ~15 minutes (but you can move on while it trains!)

Now we are ready to submit a distributed training job to pretrain the ESM2 model. We provide the following `train.yaml` template to run training on HyperPod cluster compute nodes with a certain number of GPUs per node.

## Data

During the provisioning of your accounts, we have downloaded the necessary data for training into your workshop account's FSx for Lustre file system, as this download can take ~30 minutes. We have downloaded the [UniRef50](https://huggingface.co/datasets/agemagician/uniref50) dataset, which is data specifically for ML models on protein sequences. It has been pre-tokenized into Apache Arrow format and placed in the `DATASET_DIR` environment variable directory (`/fsx/arrow`), which is what the training job reads. Model checkpoints and the final model are written to the `TARGET_PATH` directory (`/fsx/esm`, with output under `OUTPUT_DIR=/fsx/esm/output`).

:::note
You may not be able to see this dataset from your Code Editor instance. In order to demonstrate partitions (and setting up boundaries) on file systems, we only mounted the `/shared` partition from the file system onto the Code Editor instance. Think of yourself as an ML Engineer that's been told "the dataset resides here, go train a model for me now"!

This is actually a realistic scenario — data scientists prepare data, infrastructure sets up storage, and you (the ML Engineer) make the training happen. 🎯
:::

## (Optional) Peek at the dataset on FSx

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

```text
dataset_dict.json  test  train  validation
```

```text
data-00000-of-00062.arrow  data-00001-of-00062.arrow  data-00002-of-00062.arrow  ...
dataset_info.json  state.json
```

This is the pre-tokenized UniRef50 data that the training job consumes via `--dataset_dir=${DATASET_DIR}`. Exit the pod shell when done — we'll leave the pod running so you can reuse it to inspect your checkpoints after training.

```bash
exit
```

## 1. Create the HyperPodPyTorchJob YAML

We use the following template to submit a training job to our SageMaker HyperPod cluster. As always, please run the command below from the terminal of your Code Editor instance.

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
        expectedStartCutOffInSeconds: 900
      - name: JobHangingDetection
        logPattern: ".*'loss':.*"
        expectedRecurringFrequencyInSeconds: 1200
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
                - name: LD_PRELOAD
                  value: /usr/local/lib/python3.10/dist-packages/nvidia/nccl/lib/libnccl.so.2
                - name: NCCL_NET_PLUGIN
                  value: "none"
                - name: NCCL_SOCKET_IFNAME
                  value: "eth0"
              volumeMounts:
                - mountPath: /fsx
                  name: fsx-storage
                - mountPath: /dev/shm
                  name: shmem
              imagePullPolicy: Always
              command:
                - /bin/bash
                - -c
                - |
                  hyperpodrun \
                    --tee=3 \
                    --log_dir=/tmp/hyper
# NOTE: the crawled page truncates here, mid-command. See the live workshop for the rest
# of the hyperpodrun invocation and the closing EOF.
```

:::note
The crawl cut this manifest off inside the container `command` (at `--log_dir=/tmp/hyper`), so the `hyperpodrun` arguments, the training script flags and the closing `EOF` of the heredoc are missing. Copy the complete `train.yaml` from the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/02-fsdp/02-train) rather than from this page.
:::

Notice all the unsubstituted environment variables here (for example `${GPU_PER_NODE}`). Remember, this is just a template — the magic happens below, via `envsubst`.

## 2. Understanding your HyperPodPyTorchJob YAML configuration

At its core, a `HyperPodPyTorchJob` defines a custom Kubernetes resource for running PyTorch jobs across multiple nodes:

```yaml
apiVersion: sagemaker.amazonaws.com/v1
kind: HyperPodPyTorchJob
metadata:
  name: hpto-job
```

The YAML implements robust error handling through retry policies and log monitoring. What we are doing in the following snippet is:

- **JobStart:** fails if no matching log line appears in the logs within the first 15 minutes (900s)
- **JobHangingDetection:** fails if the gap between matching log lines exceeds 20 minutes (1200s)
- In our `restartPolicy`, we allow 3 process restarts before a full job restart, and a maximum of 10 total retries

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
      expectedStartCutOffInSeconds: 900
    - name: JobHangingDetection
      logPattern: ".*'loss':.*"
      expectedRecurringFrequencyInSeconds: 1200
```

Finally, the `command` section launches the training with our `hyperpodrun` launch command, purpose-built for our training operator:

```bash
hyperpodrun \
  --tee=3 \
  --log_dir=/tmp/hyperpod \
  --nproc_per_node=$GPU_PER_NODE \
  --nnodes=$NUM_NODES \
```

:::note
This snippet is also truncated in the crawl — the remaining `hyperpodrun` and training script arguments are only available in the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/02-fsdp/02-train).
:::

To enable auto-resume, the checkpoints are written to FSx, which gives all the nodes a shared file system with checkpoints accessible to all:

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
      claimName: fsx-claim  # Your FSx PVC
volumeMounts: ...
```

With this argument, we are placing checkpoints in FSx:

```bash
--output_dir=${OUTPUT_DIR}
```

## 3. Run the training job

To initiate the PyTorch training job, run the command:

```bash
envsubst < train.yaml | kubectl apply -f -
```

`envsubst` will automatically substitute all `${VARIABLE}` occurrences with the actual values set in your environment variables.

You should see output:

```text
hyperpodpytorchjob.sagemaker.amazonaws.com/hpto-job created
```

:::note
The live workshop has an expandable "Want to see your manifest that was submitted?" block here that was not captured in the crawl.
:::

To see your pods, run:

```bash
kubectl get pods
```

The jobs should show a `Running` status:

```text
NAME                             READY   STATUS    RESTARTS   AGE
hpto-job-pods-794bd5fb5c-2brnb   1/1     Running   0          3m28s
hpto-job-pods-794bd5fb5c-7xjs2   1/1     Running   0          3m27s
```

To see the logs of the job, we use `kubetail`:

```bash
kubetail hpto
```

To exit the pod logs, press `Ctrl-C`.

:::note
The live workshop has an expandable "What is kubetail?" explainer here that was not captured in the crawl.
:::

## Training! 🎉

You do not have to wait for the training to complete, as this takes approximately 10 minutes. If you waited for the training to complete, you will see the output below.

```text
Training completed. Do not forget to share your model on huggingface.co/models =)
{'train_runtime': 537.2944, 'train_samples_per_second': 372.235, 'train_steps_per_second': 4.229, 'train_loss': 2.6355, 'epoch': 1.0}
***** eval metrics *****
  epoch                   =     0.9997
  eval_accuracy           =     0.2067
  eval_loss               =     2.6116
  eval_runtime            = 0:00:48.48
  eval_samples            =      50000
  eval_samples_per_second =   1031.179
  eval_steps_per_second   =     64.449
  perplexity              =    13.6213
```

:::note
Seeing a `SIGTERM` / `SignalException` traceback after the metrics? That's expected ✅. The live workshop expands on why; that explanation was not captured in the crawl.
:::

Congratulations on running your first distributed training job on SageMaker HyperPod using the HyperPod Training Operator!

## (Optional) Inspect your checkpoints on FSx

Your training job writes checkpoints and the final model to the `OUTPUT_DIR` directory (`/fsx/esm/output`), which sits under `TARGET_PATH` (`/fsx/esm`). Just like with the dataset, this lives on FSx and isn't visible from Code Editor — so let's reuse the `fsx-pod` helper we launched earlier to take a look.

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

```text
README.md           checkpoint-100   checkpoint-2272   config.json          model.safetensors
all_results.json    checkpoint-1000  ...               eval_results.json    trainer_state.json
train_results.json  vocab.txt
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
