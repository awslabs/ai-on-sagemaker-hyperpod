---
title: Deploy Mistral Lite using the JumpStart UI
sidebar_position: 3
---

# Deploy Mistral Lite using the SageMaker JumpStart UI

:::tip Prefer the command line?
This page walks through the deployment using the SageMaker Studio UI. If you'd rather deploy the same model with the same configuration using `kubectl` and the AWS CLI, see [(Alternative) Deploy Mistral Lite using the AWS CLI](./04-deploy-jumpstart-cli.md). You only need to follow one of the two approaches.
:::

## Step 1: Open SageMaker Studio

From the [SageMaker Studio UI](https://console.aws.amazon.com/sagemaker/home#/studio), open up your Studio Domain, similar to how you did before.

## Step 2: Open JumpStart

From the SageMaker Studio UI, you can select `Models` on the right-hand side to open up the model selection.

## Step 3: Search for Mistral Lite

In the search bar, type "Mistral Lite", and click on the model.

## Step 4: Click Deploy

Once you've selected the Mistral Lite model, click the **Deploy** button on the top right.

## Step 5: Configure Deployment Settings

From here, you can configure your deployment configuration for HyperPod, including the name, instance type, HyperPod cluster, namespace and scaling.

- **HyperPod cluster**: your cluster name
- **Instance type**: match your cluster's instance type (`ml.g5.2xlarge`)
- **Namespace**: `default`
- **Autoscaling**: Enabled, max replicas set to 2

## Step 6: Click Deploy and let's monitor the deployment!

If you go back to your **Code Editor terminal**, you can see the deployment pod initializing:

```bash
kubectl get pods -n default
```

Output:

```
NAME                                READY   STATUS    RESTARTS   AGE
hyp-1781042168062-b9d9b9889-gwb2d   3/3     Running   0          103s
```

If you go back to SageMaker Studio and on the left-hand side, select `Deployments` and select `Endpoints`. You can see the SageMaker endpoint to host your model being created.

This should take approximately 5-10 minutes.

Once the deployment status is `InService`, you can test the deployment from the SageMaker Studio UI with JSON data.

Select your endpoint, and select the `Playground` tab.

Paste the following in the JSON body:

```json
{
  "inputs": "What is the capital of USA?"
}
```

## ✅ Success: Mistral Lite Deployed!

You've successfully:

- ✅ Deployed Mistral Lite from SageMaker JumpStart
- ✅ Configured auto-scaling (1-2 replicas)
- ✅ Created a SageMaker endpoint for API access
- ✅ Tested the endpoint and verified it works

## Cleanup: Delete the Inference Deployment

When done testing, free the GPU resources.

:::important
Deleting the endpoint via the Studio UI alone is **not sufficient** — JumpStart creates a `JumpStartModel` Kubernetes custom resource that must also be deleted.
:::

In your Code Editor terminal:

```bash
# Find and delete your deployment
kubectl delete -n default $(kubectl get jumpstartmodel -n default -o name)
```

Verify the GPU pod is gone:

```bash
kubectl get pods -n default
```
