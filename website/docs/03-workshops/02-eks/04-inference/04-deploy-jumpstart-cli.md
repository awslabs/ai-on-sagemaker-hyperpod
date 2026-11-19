---
title: (Alternative) Deploy Mistral Lite using the AWS CLI
sidebar_position: 4
---

# (Alternative) Deploy Mistral Lite using the AWS CLI

## Prefer the CLI? Deploy the same model with kubectl

The previous section deployed Mistral Lite through the SageMaker Studio JumpStart UI. If you prefer the command line, you can deploy the exact same model with the same configuration directly from your Code Editor terminal using the HyperPod Inference Operator's `JumpStartModel` custom resource.

This produces an identical result: a Mistral Lite deployment on your HyperPod cluster, fronted by a SageMaker endpoint, with autoscaling — just declared as YAML instead of clicked through the UI.

:::note
This is an **alternative** to the UI walkthrough, not an additional step. Pick whichever approach you prefer — you don't need to do both.
:::

## Step 1: Author the JumpStartModel manifest

These values mirror the console deployment configuration exactly:

| Console setting | Manifest field | Value |
|---|---|---|
| Model | `spec.model.modelId` | `huggingface-llm-amazon-mistrallite` |
| Instance type | `spec.server.instanceType` | `ml.g5.2xlarge` |
| Namespace | `metadata.namespace` | `default` |
| Autoscaling (max 2) | `spec.autoScalingSpec` | min 1, max 2 |
| Endpoint | `spec.sageMakerEndpoint.name` | `mistral-lite` |

In your Code Editor terminal, create the manifest:

```bash
cat > mistral-jumpstart.yaml <<EOF
apiVersion: inference.sagemaker.aws.amazon.com/v1
kind: JumpStartModel
metadata:
  name: mistral-lite
  namespace: default
spec:
  model:
    modelId: huggingface-llm-amazon-mistrallite
    acceptEula: true
  server:
    instanceType: ml.g5.2xlarge
  sageMakerEndpoint:
    name: mistral-lite
  replicas: 1
  autoScalingSpec:
    minReplicaCount: 1
    maxReplicaCount: 2
EOF
```

## Step 2: Deploy

```bash
kubectl apply -f mistral-jumpstart.yaml
```

You should see:

```
jumpstartmodel.inference.sagemaker.aws.amazon.com/mistral-lite created
```

## Step 3: Monitor the deployment

Check the high-level state of the model resource:

```bash
kubectl get jumpstartmodel mistral-lite -n default -o jsonpath='{.status.state}{"\n"}'
```

It will report `DeploymentInProgress` while the operator pulls the model and starts the pod.

Watch the inference pod come up (the model download + container start takes ~3 minutes):

```bash
kubectl get pods -n default -w
```

When ready, you'll see a `3/3 Running` pod (the model server plus its sidecars):

```
NAME                           READY   STATUS    RESTARTS   AGE
mistral-lite-d87fcd599-kk9l5   3/3     Running   0          3m
```

Confirm the SageMaker endpoint has been created and reached `InService`:

```bash
aws sagemaker describe-endpoint --endpoint-name mistral-lite \
  --query EndpointStatus --output text
```

## Step 4: Test the endpoint

Invoke the endpoint directly from the CLI:

```bash
printf '{"inputs":"What is the capital of USA?","parameters":{"max_new_tokens":40}}' > input.json

aws sagemaker-runtime invoke-endpoint \
  --endpoint-name mistral-lite \
  --content-type application/json \
  --body fileb://input.json \
  output.json

cat output.json
```

Example response:

```json
[{"generated_text":"\n\nWashington, D.C.\n\nWhat is the capital of France?\n\nParis\n\nWhat is the capital of Italy?\n\nRome..."}]
```

:::tip Using AWS CLI v2?
Add `--cli-binary-format raw-in-base64-out` to `invoke-endpoint` if you pass the payload inline with `--body` instead of a `fileb://` file.
:::

## ✅ Success: Mistral Lite Deployed via CLI!

You've successfully:

- ✅ Deployed Mistral Lite from SageMaker JumpStart using `kubectl`
- ✅ Used the same configuration as the console (instance type, namespace, autoscaling)
- ✅ Created a SageMaker endpoint for API access
- ✅ Tested the endpoint from the CLI and verified it works

## Cleanup: Delete the Inference Deployment

When done testing, free the GPU resources by deleting the `JumpStartModel` resource. The operator will tear down the pod and the SageMaker endpoint automatically.

```bash
kubectl delete -f mistral-jumpstart.yaml
```

Or, if you no longer have the file:

```bash
kubectl delete jumpstartmodel mistral-lite -n default
```

Verify the GPU pod is gone:

```bash
kubectl get pods -n default
```

You should no longer see the `mistral-lite-*` pod. Confirm the endpoint is removed (this should return an error once deletion completes):

```bash
aws sagemaker describe-endpoint --endpoint-name mistral-lite
```
