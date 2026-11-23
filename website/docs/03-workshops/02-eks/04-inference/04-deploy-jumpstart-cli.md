---
title: Deploy with the CLI
sidebar_position: 4
---

# Deploy Gemma 2B Instruct using the CLI

## Prefer the CLI? Deploy the same model with kubectl

The previous page deployed Gemma 2B Instruct through the SageMaker Studio JumpStart UI. If you prefer the command line, you can deploy the exact same model with the same configuration directly from your Code Editor terminal using the HyperPod Inference Operator's `JumpStartModel` custom resource.

This produces an identical result: a Gemma 2B Instruct deployment on your HyperPod cluster, fronted by a SageMaker endpoint, with autoscaling — just declared as YAML instead of clicked through the UI.

:::note
This is an alternative to the UI walkthrough, not an additional step. Pick whichever approach you prefer — you don't need to do both.
:::

## Step 1: Author the JumpStartModel manifest

These values mirror the console deployment configuration exactly:

| Console setting | Manifest field | Value |
|---|---|---|
| Model | `spec.model.modelId` | `huggingface-llm-gemma-2b-instruct` |
| Instance type | `spec.server.instanceType` | `${INSTANCE_TYPE}` (e.g. `ml.g7.2xlarge`) |
| Namespace | `metadata.namespace` | `default` |
| Autoscaling (max 2) | `spec.autoScalingSpec` | min 1, max 2 |
| Endpoint | `spec.sageMakerEndpoint.name` | `gemma-2b` |

In your Code Editor terminal, create the manifest. `${INSTANCE_TYPE}` is already set for you from the cluster verification page — this heredoc substitutes it in automatically, so the manifest matches your cluster's actual GPU instance type:

```bash
cat > gemma-jumpstart.yaml <<EOF
apiVersion: inference.sagemaker.aws.amazon.com/v1
kind: JumpStartModel
metadata:
  name: gemma-2b
  namespace: default
spec:
  model:
    modelId: huggingface-llm-gemma-2b-instruct
    acceptEula: true
  server:
    instanceType: ${INSTANCE_TYPE}
  sageMakerEndpoint:
    name: gemma-2b
  replicas: 1
  autoScalingSpec:
    minReplicaCount: 1
    maxReplicaCount: 2
EOF
```

:::important
The `acceptEula: true` field indicates acceptance of the [Gemma Terms of Use](https://ai.google.dev/gemma/terms). This is required by Google to deploy Gemma models.
:::

## Step 2: Deploy

```bash
kubectl apply -f gemma-jumpstart.yaml
```

You should see:

```text
jumpstartmodel.inference.sagemaker.aws.amazon.com/gemma-2b created
```

## Step 3: Monitor the deployment

Check the high-level state of the model resource:

```bash
kubectl get jumpstartmodel gemma-2b -n default -o jsonpath='{.status.state}{"\n"}'
```

It will report `DeploymentInProgress` while the operator pulls the model and starts the pod.

Watch the inference pod come up (the model download plus container start takes ~3 minutes):

```bash
kubectl get pods -n default -w
```

When ready, you'll see a `3/3 Running` pod (the model server plus its sidecars):

```text
NAME                       READY   STATUS    RESTARTS   AGE
gemma-2b-d87fcd599-kk9l5   3/3     Running   0          3m
```

Confirm the SageMaker endpoint has been created and reached `InService`:

```bash
aws sagemaker describe-endpoint --endpoint-name gemma-2b \
  --query EndpointStatus --output text
```

## Step 4: Test the endpoint

Invoke the endpoint directly from the CLI. Gemma 2B Instruct is served by the vLLM engine, which accepts an OpenAI-style payload with a `prompt` field:

```bash
printf '{"prompt":"What is the capital of USA?","max_tokens":40}' > input.json
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name gemma-2b \
  --content-type application/json \
  --body fileb://input.json \
  output.json
cat output.json
```

Example response:

```json
{"id":"cmpl-...","object":"text_completion","model":"/opt/ml/model","choices":[{"index":0,"text":"\n\nThe capital of the United States of America is Washington, D.C., which is located in the state of District of Columbia.","finish_reason":"stop"}],"usage":{"prompt_tokens":8,"total_tokens":36,"completion_tokens":28}}
```

You can also use the OpenAI-style chat completion payload:

```bash
printf '{"messages":[{"role":"user","content":"What is the capital of USA?"}],"max_tokens":40}' > chat.json
aws sagemaker-runtime invoke-endpoint \
  --endpoint-name gemma-2b \
  --content-type application/json \
  --body fileb://chat.json \
  chat-output.json
cat chat-output.json
```

:::note
The live workshop has an expandable "Using AWS CLI v2? Add `--cli-binary-format`" block here whose contents were not captured in the crawl. The vLLM page later in this module shows the flag in use (`--cli-binary-format raw-in-base64-out`).
:::

## ✅ Success: Gemma 2B Instruct deployed via CLI

You've successfully:

- ✅ Deployed Gemma 2B Instruct from SageMaker JumpStart using `kubectl`
- ✅ Used the same configuration as the console (instance type, namespace, autoscaling)
- ✅ Created a SageMaker endpoint for API access
- ✅ Tested the endpoint from the CLI and verified it works

## Cleanup: delete the inference deployment

When done testing, free the GPU resources by deleting the `JumpStartModel` resource. The operator will tear down the pod and the SageMaker endpoint automatically.

```bash
kubectl delete -f gemma-jumpstart.yaml
```

Or, if you no longer have the file:

```bash
kubectl delete jumpstartmodel gemma-2b -n default
```

Verify the GPU pod is gone:

```bash
kubectl get pods -n default
```

You should no longer see the `gemma-2b-*` pod. Confirm the endpoint is removed (this should return an error once deletion completes):

```bash
aws sagemaker describe-endpoint --endpoint-name gemma-2b
```
