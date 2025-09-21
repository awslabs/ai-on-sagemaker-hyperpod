---
title: "b. Training"
weight: 32
---


## 2. Install envsubst

This example uses [`envsubst`](https://github.com/a8m/envsubst
) to generate a Kubernetes manifest file from a template file and parameters. If you don't have `envsubst` on your development environment, install it by following the [Installation instruction](https://github.com/a8m/envsubst?tab=readme-ov-file#installation).


## 3. Generate manifest file

Check your cluster's specification by running following command:

``` bash
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,INSTANCETYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa"
```

```
NAME                           INSTANCETYPE    GPU   EFA
hyperpod-i-055aeff9546187dee   ml.g5.8xlarge   1     1
hyperpod-i-09662f64f615c96f5   ml.g5.8xlarge   1     1
hyperpod-i-099e2a84aba621d52   ml.g5.8xlarge   1     1
hyperpod-i-0a6fea3329235be91   ml.g5.8xlarge   1     1
hyperpod-i-0ac3feb733dc0f00e   ml.g5.8xlarge   1     1
hyperpod-i-0bf7dce836e063fa6   ml.g5.8xlarge   1     1
hyperpod-i-0ddf28f3ff2870f1b   ml.g5.8xlarge   1     1
hyperpod-i-0fe48912b03d2c22e   ml.g5.8xlarge   1     1
```

Editing the shell script `generate-pytorchjob.sh`, based on your cluster specification.


For ml.g5.8xlarge x 8:

``` bash
    :
export NUM_NODES=8
export INSTANCE_TYPE=ml.g5.8xlarge
export GPU_PER_NODE=1
export EFA_PER_NODE=1
export FI_PROVIDER=efa
    :
export TRAIN_BATCH_SIZE=4
export HIDDEN_WIDTH=4096
export NUM_LAYERS=32
export NUM_HEADS=32
export LLAMA_INTERMEDIATE_SIZE=11008
export SHARD_DEGREE=8
export USE_SYNTHETIC_DATA=1
export USE_FP8=0
    :
```

Generate `smpv2.yaml` by running the `generate-pytorchjob.sh`.

``` bash
./generate-pytorchjob.sh
```


## 4. Deploy training workload

Now the manifest file `smpv2.yaml` is generated, and you are ready to deploy the training workload. Run following command to deploy the training workload.

``` bash
kubectl apply -f ./smpv2.yaml
```

You should see following message.

```
service/etcd created
deployment.apps/etcd created
pytorchjob.kubeflow.org/smpv2-llama2 created
```


## 5. Monitor

To see the status of your job, use the commands below:

``` bash
kubectl get pytorchjobs
kubectl get pods
```

```
NAME           STATE     AGE
smpv2-llama2   Created   76s

NAME                    READY   STATUS              RESTARTS   AGE
etcd-7787559c74-v2z48   1/1     Running             0          10m
smpv2-llama2-worker-0   0/1     ContainerCreating   0          10m
smpv2-llama2-worker-1   0/1     ContainerCreating   0          10m
smpv2-llama2-worker-2   0/1     ContainerCreating   0          10m
smpv2-llama2-worker-3   0/1     ContainerCreating   0          10m
smpv2-llama2-worker-4   0/1     ContainerCreating   0          10m
smpv2-llama2-worker-5   0/1     ContainerCreating   0          10m
smpv2-llama2-worker-6   0/1     ContainerCreating   0          10m
smpv2-llama2-worker-7   0/1     ContainerCreating   0          10m
```

When you run for the first time, it takes 2~3min until the Pod statuses change from `ContainerCreating` to `Running`.

```
NAME                    READY   STATUS    RESTARTS   AGE
etcd-7787559c74-v2z48   1/1     Running   0          17m
smpv2-llama2-worker-0   1/1     Running   0          17m
smpv2-llama2-worker-1   1/1     Running   0          17m
smpv2-llama2-worker-2   1/1     Running   0          17m
smpv2-llama2-worker-3   1/1     Running   0          17m
smpv2-llama2-worker-4   1/1     Running   0          17m
smpv2-llama2-worker-5   1/1     Running   0          17m
smpv2-llama2-worker-6   1/1     Running   0          17m
smpv2-llama2-worker-7   1/1     Running   0          17m
```

Each of the pods produces job logs. One of the pods is elected master during job initialization. Only this pod will show the progress of the training job in its log. To find out which pod is currently the master, run the command below.


``` bash
kubectl logs smpv2-llama2-worker-0 | grep master_addr=
```

```
[2024-06-28 18:04:58,097] torch.distributed.elastic.agent.server.api: [INFO]   master_addr=smpv2-llama2-worker-2
```

This shows that the pod smpv2-llama2-worker-2 is currently the master. To look at the current job logs, use the command below:


``` bash
kubectl logs -f smpv2-llama2-worker-2
```

```
    :
2024-06-28 18:34:47 I [logging_utils.py:135] Batch 74 Loss: 11.625, Speed: 1.35 samples/sec, Model TFLOPS/GPU: 28.64, lr: 0.000049, gradnorm: 12.3398
2024-06-28 18:35:11 I [logging_utils.py:135] Batch 75 Loss: 11.625, Speed: 1.32 samples/sec, Model TFLOPS/GPU: 28.03, lr: 0.000050, gradnorm: 12.3637
2024-06-28 18:35:34 I [logging_utils.py:135] Batch 76 Loss: 11.6875, Speed: 1.37 samples/sec, Model TFLOPS/GPU: 29.09, lr: 0.000050, gradnorm: 12.3340
2024-06-28 18:35:58 I [logging_utils.py:135] Batch 77 Loss: 11.625, Speed: 1.37 samples/sec, Model TFLOPS/GPU: 29.08, lr: 0.000051, gradnorm: 12.3454
    :
```


**Note:** You may see following warning messages between the above log lines.
```
[2024-06-28 18:30:50.171: W torch/sagemaker/distributed/fsdp/fully_sharded_data_parallel.py:38] 8 pytorch allocator cache flushes since last step. this happens when there is high memory pressure and is detrimental to performance. if this is happening frequently consider adjusting settings to reduce memory consumption. If you are unable to make the cache flushes go away consider adding torch.cuda.empty_cache() calls in your training loop to ensure that all ranks flush their caches at the same time which also has a performance hit but generally smaller than when all ranks do it at different times.
```


You can execute `nvidia-smi` command inside a running container within a Pod to see GPU utilization.

``` bash
kubectl exec -it smpv2-llama2-worker-2 -- nvidia-smi
```

```
Fri Jun 28 18:17:20 2024       
+---------------------------------------------------------------------------------------+
| NVIDIA-SMI 535.183.01             Driver Version: 535.183.01   CUDA Version: 12.2     |
|-----------------------------------------+----------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |         Memory-Usage | GPU-Util  Compute M. |
|                                         |                      |               MIG M. |
|=========================================+======================+======================|
|   0  NVIDIA A10G                    On  | 00000000:00:1E.0 Off |                    0 |
|  0%   59C    P0             196W / 300W |  17878MiB / 23028MiB |    100%      Default |
|                                         |                      |                  N/A |
+-----------------------------------------+----------------------+----------------------+
                                                                                         
+---------------------------------------------------------------------------------------+
| Processes:                                                                            |
|  GPU   GI   CI        PID   Type   Process name                            GPU Memory |
|        ID   ID                                                             Usage      |
|=======================================================================================|
+---------------------------------------------------------------------------------------+
```


## 7. Stop

To stop the current training job, use the following command.

``` bash
kubectl delete -f ./smpv2.yaml
```
