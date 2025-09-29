---
title : SageMaker JumpStart
sidebar_position : 1
---
# Deploy models from SageMaker JumpStart using SageMaker Studio UI

Amazon SageMaker JumpStart provides pretrained, open-source models for a wide range of problem types to help you get started with machine learning. You can incrementally train and tune these models before deployment. JumpStart also provides solution templates that set up infrastructure for common use cases, and executable example notebooks for machine learning with SageMaker AI.

You can deploy, fine-tune, and evaluate pretrained models from popular models hubs through the JumpStart landing page

With the HyperPod Inference Operator, you can deploy over 400 open-weights foundation models from SageMaker JumpStart on HyperPod with just a click, including the latest state-of-the-art models like DeepSeek-R1, Mistral, and Llama4. SageMaker JumpStart models will be deployed on HyperPod clusters orchestrated by EKS and will be made available as SageMaker endpoints or Application Load Balancers (ALB).


SageMaker Studio allows you to deploy models from SageMaker JumpStart on HyperPod clusters interactively via the UI.

From the SageMaker Studio UI, you can select JumpStart to open up the model selection.
<div style={{ textAlign: 'center' }}>
![SageMaker UI](/img/07-inference/jumpstart-ui/sagemaker-ui-start.png)
</div>

<div style={{ textAlign: 'center' }}>
![Model Selection](/img/07-inference/jumpstart-ui/jumpstart-model-selection.png)
</div>
Once a model is selected, click the 'Deploy' button to bring up the deployment options. In this case, we've selected Mistral Instruct v3.

<div style={{ textAlign: 'center' }}>
![Mistral 7B Instruct](/img/07-inference/jumpstart-ui/press-deploy.png)
</div>

From here, you can configure your deployment configuration for HyperPod, including the name, instance type, hyperpod cluster, namespace and scaling.

<div style={{ textAlign: 'center' }}>
![Options](/img/07-inference/jumpstart-ui/options.png)
</div>
The UI will then show you the deployment status. Once the deployment is complete, you can test the deployment from the SageMaker Studio UI with JSON data.

<div style={{ textAlign: 'center' }}>
![Options](/img/07-inference/jumpstart-ui/test-invoke.png)
</div>

## Deploy models from SageMaker JumpStart using kubectl

For example, to deploy Mistral Instruct v3 on your cluster, you can define a YAML file called model.yaml with:

```
apiVersion: inference.sagemaker.aws.amazon.com/v1alpha1
kind: JumpStartModel
metadata:
  name: mistral-jumpstart
  namespace: default
spec:
  sageMakerEndpoint:
    name: "mistral-endpoint"
  model:
    modelHubName: SageMakerPublicHub
    modelId: huggingface-llm-mistral-7b-instruct-v3
    modelVersion: "1.0.0"
  server:
    instanceType: ml.g5.8xlarge
  metrics:
    enabled: true
  maxDeployTimeInSeconds: 1800
  tlsConfig:
    tlsCertificateOutputS3Uri: "s3://<BUCKET_NAME>" # you can use an existing bucket 
```

    Then you can run

```
    kubectl apply -f model.yaml
```

    From here, monitor the deployment using 
```
    kubectl get jumpstartmodels
```

### Invoking the model
Once the model is deployed, you can invoke the SageMaker Endpoint that is created using the InvokeEndpoint API. In the YAML file, this is defined as "mistral-endpoint".

For example, using boto3, this would be:

```
import boto3
import json

client = boto3.client('sagemaker-runtime')

response = client.invoke_endpoint(
    EndpointName='mistral-endpoint',
    ContentType='application/json',
    Accept='application/json',
    Body=json.dumps({
    	"inputs": "Hi, what can you help me with?"
    })
)

print(response['Body'].read().decode('utf-8'))
```
