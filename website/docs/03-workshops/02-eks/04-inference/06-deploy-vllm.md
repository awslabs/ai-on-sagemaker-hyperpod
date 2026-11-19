---
title: Deploy Qwen2.5 with an InferenceEndpointConfig
sidebar_position: 6
---

# Deploy Qwen2.5 with vLLM using an InferenceEndpointConfig

In this section you deploy Qwen2.5-1.5B-Instruct with the vLLM inference engine on your HyperPod cluster. The whole deployment is one Kubernetes resource, an `InferenceEndpointConfig`. You watch the HyperPod Inference Operator turn it into a running model behind a SageMaker endpoint, then invoke that endpoint the same way you invoked Mistral Lite.

The steps follow the AWS guide [Deploy models from Amazon S3, Amazon FSx, or Hugging Face Hub using kubectl](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-model-deployment-deploy-ftm.html), adapted to this cluster: weights straight from the Hugging Face Hub, one `ml.g5.2xlarge` GPU node, and the endpoint name `qwen25-1-5b`. The serving container is the AWS vLLM Deep Learning Container, configured as described in the [vLLM on Amazon SageMaker AI guide](https://aws.github.io/deep-learning-containers/vllm/deployment/sagemaker/).

:::important
Run every command in your **Code Editor terminal**.

These steps use the environment variables from the cluster verification page (`AWS_REGION`, `INSTANCE_TYPE`). If you opened a new terminal, run `source fsx-shared/env_vars` again first.
:::

## Step 1: Free a GPU (required)

The cluster has **two A10G GPUs**, one per `ml.g5.2xlarge` node, and vLLM needs one whole GPU. The JumpStart deployment uses one GPU per replica and autoscales up to two, so it may be holding both. The FSDP training job from the training module also uses GPUs if it is still running.

Delete both. Each command is safe to run even if the resource is already gone:

```bash
kubectl delete jumpstartmodel --all -n default
kubectl delete hyperpodpytorchjob hpto-job -n default --ignore-not-found
```

Wait until the JumpStart pod is gone. It takes a minute or two:

```bash
kubectl get pods -n default
```

Then confirm a GPU is free:

```bash
kubectl describe nodes | grep -E '^Name:|nvidia.com/gpu'
```

For each node you see the GPU `Capacity`, `Allocatable` and the number in use under `Allocated resources`. At least one node must show `nvidia.com/gpu 0` in use before you continue.

## Step 2: Set your environment and check the operator

```bash
export ENDPOINT_NAME=qwen25-1-5b
export GPU_INSTANCE_TYPE=${INSTANCE_TYPE}
export MODEL_CPU=4 MODEL_MEMORY=16Gi
export VLLM_IMAGE=763104351884.dkr.ecr.${AWS_REGION}.amazonaws.com/vllm:0.31.0-gpu-py312-cu130-ubuntu24.04-sagemaker
echo "$AWS_REGION $GPU_INSTANCE_TYPE cpu=$MODEL_CPU memory=$MODEL_MEMORY"
```

The last line should print your Region followed by `ml.g5.2xlarge cpu=4 memory=16Gi`. An `ml.g5.2xlarge` has 8 vCPUs and 32 GiB; requesting half leaves room for the operator's sidecars and the node's system pods.

The operator that ran JumpStart also serves `InferenceEndpointConfig`. Check that it is running and that it can load models from the Hugging Face Hub:

```bash
kubectl get pods -n hyperpod-inference-system
kubectl get crd inferenceendpointconfigs.inference.sagemaker.aws.amazon.com \
  -o jsonpath='{.spec.versions[?(@.name=="v1")].schema.openAPIV3Schema.properties.spec.properties.modelSourceConfig.properties.modelSourceType.enum}{"\n"}'
```

The controller manager pod is `Running`, and the second command prints a list that includes `huggingface`:

```
["fsx","s3","huggingface","kubernetesVolume"]
```

## Step 3: Write and apply the InferenceEndpointConfig

Everything about the deployment lives in this one object: where the weights come from, which serving container runs, how much of a GPU node each replica gets, and the name of the SageMaker endpoint to create.

### Which vLLM container

The serving container is the AWS vLLM Deep Learning Container, SageMaker variant (`vllm:0.31.0-gpu-py312-cu130-ubuntu24.04-sagemaker`). It is the upstream vLLM v0.31.0 server with a SageMaker entrypoint added:

- It is pulled from the in-Region AWS Deep Learning Containers registry in Amazon ECR (account `763104351884`), the same registry the JumpStart serving images come from.
- It speaks the SageMaker container contract on port 8080: `/ping` for health checks and `/invocations` for requests. `/invocations` routes an OpenAI-style chat payload to vLLM's chat completions handler.
- It is configured with environment variables only. The entrypoint turns every `SM_VLLM_*` variable into a vLLM flag (`SM_VLLM_MAX_MODEL_LEN` becomes `--max-model-len`), so the manifest has no `command` or `args`.

:::note
The image is built on CUDA 13.0, which needs NVIDIA driver 580 or later on the node. Current HyperPod AMIs for EKS ship it.
:::

### The manifest

The heredoc expands your variables and pipes the result straight into `kubectl apply`. Note the time before you apply:

```bash
date
kubectl apply -f - <<EOF
apiVersion: inference.sagemaker.aws.amazon.com/v1
kind: InferenceEndpointConfig
metadata:
  name: ${ENDPOINT_NAME}
  namespace: default
spec:
  modelName: ${ENDPOINT_NAME}
  endpointName: ${ENDPOINT_NAME}            # the SageMaker endpoint you will invoke
  instanceType: ${GPU_INSTANCE_TYPE}        # the cluster's GPU instance type
  invocationEndpoint: invocations           # the SageMaker vLLM image serves /invocations
  replicas: 1
  modelSourceConfig:
    modelSourceType: huggingface
    prefetchEnabled: true                   # operator adds an init container that downloads the model into /opt/ml/model before vLLM starts
    huggingFaceModel:
      modelId: Qwen/Qwen2.5-1.5B-Instruct   # ungated: no token needed
  worker:
    image: ${VLLM_IMAGE}
    modelInvocationPort:
      containerPort: 8080                   # the SageMaker vLLM image always listens on 8080
      name: http
    modelVolumeMount:
      name: model-weights
      mountPath: /opt/ml/model              # the operator downloads the model here before vLLM starts
    resources:
      requests:
        nvidia.com/gpu: 1                   # one GPU per replica; a g5.2xlarge has exactly one
        cpu: "${MODEL_CPU}"
        memory: ${MODEL_MEMORY}
      limits:
        nvidia.com/gpu: 1
    environmentVariables:                   # each SM_VLLM_* becomes a vLLM flag
      - name: SM_VLLM_MODEL                 # --model: load the downloaded weights
        value: /opt/ml/model
      - name: SM_VLLM_SERVED_MODEL_NAME     # --served-model-name: the model name in responses
        value: ${ENDPOINT_NAME}
      - name: SM_VLLM_TENSOR_PARALLEL_SIZE  # --tensor-parallel-size: one A10G per replica
        value: "1"
      - name: SM_VLLM_MAX_MODEL_LEN         # --max-model-len: prompt plus completion, in tokens
        value: "8192"
      - name: HF_HUB_OFFLINE                # vLLM itself never calls the Hub; the weights are already local
        value: "1"
EOF
```

Expected output:

```
inferenceendpointconfig.inference.sagemaker.aws.amazon.com/qwen25-1-5b created
```

### What the fields do

| Field | Value here | What it does |
|---|---|---|
| `metadata.name`, `spec.modelName`, `spec.endpointName` | `qwen25-1-5b` | One name for everything: the Kubernetes object, the Deployment the operator creates (pod label `app=qwen25-1-5b`) and the SageMaker endpoint. |
| `instanceType` | `ml.g5.2xlarge` | The node type the pod is scheduled on. It must match an instance group in the cluster. |
| `invocationEndpoint` | `invocations` | The path on the container that SageMaker requests are forwarded to. |
| `modelSourceConfig` | `huggingface`, `Qwen/Qwen2.5-1.5B-Instruct`, `prefetchEnabled: true` | An init container downloads the model from the Hugging Face Hub into the model volume before vLLM starts. |
| `worker.image` | vLLM DLC 0.31.0 | vLLM with the SageMaker entrypoint, from the in-Region DLC registry. |
| `modelInvocationPort.containerPort` | `8080` | The port the model server listens on. The load balancer forwards requests to it. |
| `modelVolumeMount.mountPath` | `/opt/ml/model` | Where the weights appear inside the container. |
| `resources` | 1 GPU, 4 CPU, 16 GiB | One GPU per replica, plus CPU and memory sized for the node. |
| `SM_VLLM_MODEL` | `/opt/ml/model` | vLLM's `--model`: load config, tokenizer and weights from the model volume. |
| `SM_VLLM_SERVED_MODEL_NAME` | `qwen25-1-5b` | vLLM's `--served-model-name`: the name reported in responses and by `/v1/models`. |
| `SM_VLLM_TENSOR_PARALLEL_SIZE` | `1` | vLLM's `--tensor-parallel-size`: the model runs on the node's single A10G. |
| `SM_VLLM_MAX_MODEL_LEN` | `8192` | vLLM's `--max-model-len`: the longest prompt plus completion, in tokens. |
| `HF_HUB_OFFLINE` | `1` | vLLM does not contact the Hub; it uses the files the operator downloaded. |

## Step 4: Watch the operator work

Follow the pod:

```bash
kubectl get pods -n default -o wide -w
```

The pod is scheduled on a GPU node (the `NODE` column). It shows `Init` while the model downloads and `PodInitializing` while the roughly 9 GB vLLM image is pulled onto the node. It then moves to `3/3 Running`: the model server plus two sidecar containers the operator adds. `3/3` means the containers are up, not that the model is loaded. Press `Ctrl-C` and watch vLLM load the model:

```bash
kubectl logs -n default -l app=${ENDPOINT_NAME} --all-containers --prefix -f --tail=50
```

The first line from the model container shows how the entrypoint turned the `SM_VLLM_*` variables into vLLM flags, similar to:

```
INFO: vLLM server arguments: ['--port', '8080', '--max-model-len', '8192', '--model', '/opt/ml/model', '--served-model-name', 'qwen25-1-5b', '--tensor-parallel-size', '1']
```

vLLM then loads the weights and captures CUDA graphs. Wait for `Application startup complete.`; until then port 8080 does not accept connections. Press `Ctrl-C` once you see it, then look at the operator's view of progress:

```bash
kubectl describe inferenceendpointconfig "$ENDPOINT_NAME" -n default | sed -n '/^Status:/,$p'
```

The `State` moves from `DeploymentInProgress` to `DeploymentComplete`, and `Endpoints.Sagemaker` shows the endpoint ARN with `State: CreationCompleted`. A few warnings in the `Events` list are normal: `CertificateProcessingFailed ... no ingress found` in the first seconds, and `ALBNotAvailable ... retrying` for two to three minutes while the load balancer becomes active.

While you wait, the operator is doing, in order:

1. It creates a **Deployment** for the model pod and schedules it on a GPU node. An init container downloads the model from the Hugging Face Hub into the model volume.
2. It asks cert-manager for a **TLS certificate** and imports it into AWS Certificate Manager.
3. It creates an **Ingress**. The AWS Load Balancer Controller turns it into an internal Application Load Balancer with an HTTPS listener.
4. It creates a **SageMakerEndpointRegistration**, which registers the load balancer as a SageMaker endpoint. It appears in the SageMaker console and answers `invoke-endpoint`, just like the JumpStart endpoint.

## Step 5: Wait for the SageMaker endpoint

```bash
until aws sagemaker describe-endpoint --endpoint-name "$ENDPOINT_NAME" >/dev/null 2>&1; do sleep 15; done
aws sagemaker wait endpoint-in-service --endpoint-name "$ENDPOINT_NAME" && date
```

The first line waits for the operator to register the endpoint, which does not exist until the certificate and load balancer are ready. The waiter then polls until the status is `InService` and prints the time.

## Step 6: Invoke the endpoint

```bash
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "$ENDPOINT_NAME" \
  --content-type application/json \
  --body '{"messages":[{"role":"user","content":"In one sentence, what is Amazon SageMaker HyperPod?"}],"max_tokens":80}' \
  --cli-binary-format raw-in-base64-out /dev/stdout
```

You get an OpenAI-style chat completion, similar to this (formatted for readability):

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "model": "qwen25-1-5b",
  "choices": [
    {
      "index": 0,
      "message": {"role": "assistant", "content": "Amazon SageMaker HyperPod is a managed service that ..."},
      "finish_reason": "stop"
    }
  ],
  "usage": {"prompt_tokens": 39, "completion_tokens": 31, "total_tokens": 70}
}
```

Compare this with Mistral Lite: JumpStart's container took `{"inputs": ...}` and returned `generated_text`, while vLLM takes OpenAI-style `messages` and returns a chat completion. The serving container decides the API; you chose it here.

`/invocations` also accepts an OpenAI completions payload, with a `prompt` instead of `messages`:

```bash
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name "$ENDPOINT_NAME" \
  --content-type application/json \
  --body '{"prompt":"Explain Kubernetes in two sentences.","max_tokens":80}' \
  --cli-binary-format raw-in-base64-out /dev/stdout
```

The result is a `text_completion` object whose `choices[0].text` holds the generated text. No chat template is applied, so the model simply continues the prompt. The first invocation after a deployment is often slower while vLLM warms up.

:::tip Optional: call vLLM's OpenAI API on the pod directly
Port-forward the model pod and use any OpenAI-compatible client against `http://localhost:8080/v1`:

```bash
kubectl port-forward -n default deployment/${ENDPOINT_NAME} 8080:8080
```
:::

## Step 7: Look at what was created for you

```bash
kubectl get pods,svc,deployment,ingress,inferenceendpointconfig,sagemakerendpointregistration -n default
aws sagemaker describe-endpoint --endpoint-name "$ENDPOINT_NAME" --query '{Status:EndpointStatus,Arn:EndpointArn,Created:CreationTime}'
```

One `kubectl apply` produced a Deployment, a Service, an Ingress backed by an internal ALB, a TLS certificate, and a SageMaker endpoint, all running a container and model you chose.

## ✅ Success: Qwen2.5 served with vLLM!

You've successfully:

- ✅ Freed GPU capacity from the JumpStart deployment
- ✅ Deployed an open model from the Hugging Face Hub with the AWS vLLM Deep Learning Container
- ✅ Watched the Inference Operator create the pod, load balancer and SageMaker endpoint
- ✅ Invoked the endpoint with chat and completions payloads

## Cleanup: Delete the Inference Deployment (required)

The next module, **Task Governance**, needs free GPUs. Delete the `InferenceEndpointConfig`. The operator tears down the pod, load balancer and SageMaker endpoint:

```bash
kubectl delete inferenceendpointconfig "$ENDPOINT_NAME" -n default
```

Verify everything is gone:

```bash
kubectl get pods,deployment,inferenceendpointconfig,sagemakerendpointregistration -n default
kubectl describe nodes | grep -E '^Name:|nvidia.com/gpu'
aws sagemaker describe-endpoint --endpoint-name "$ENDPOINT_NAME"
```

The `qwen25-1-5b` pod is gone, no node shows a GPU in use, and `describe-endpoint` returns a `Could not find endpoint` error once deletion completes (it can take a minute).

:::note Troubleshooting
If the pod never leaves `Init`, check the init container's logs — it is downloading the model from the Hugging Face Hub. If it stays `Pending`, no GPU is free: revisit Step 1. If the SageMaker endpoint never appears, re-read the `Events` in `kubectl describe inferenceendpointconfig` — the certificate and ALB must be ready first.
:::
