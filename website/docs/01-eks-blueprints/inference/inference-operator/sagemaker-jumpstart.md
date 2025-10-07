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

- HyperPod cluster: `Name of your cluster`
- Instance type: example/ `ml.g5.8xlarge`
- Namespace: example/ `default`
- Priority class: example/ `inference-priority` - This is created from the task governance cluster scheduler config
- Autoscaling: This can be toggled to `Enabled`, allowing pod-level autoscaling

<div style={{ textAlign: 'center' }}>
![Options](/img/07-inference/jumpstart-ui/options.png)
</div>

Please press `Deploy`.

One can see the deployment pod initializing:
```bash
kubectl get pods -n hyperpod-ns-team-a
```
```bash
NAME                                                 READY   STATUS            RESTARTS   AGE
hyperpod-deployment-1X5X021XXXXX-7b7bxxxxxx-2XXX   0/3     PodInitializing   0   
```
If you go back to SageMaker Studio and on the left-hand side, select `Deployments` and select `Endpoints`. You can see the SageMaker endpoint to host your model being created.
<div style={{ textAlign: 'center' }}>
![Options](/img/07-inference/jumpstart-ui/deployments.png)
</div>

Once the deployment status is In service, you can test the deployment from the SageMaker Studio UI with JSON data.

Select your endpoint, and select the `Test inference` tab.

Paste the following in the JSON body:
```json
{
    "inputs": "Hi, what can you help me with?"
}
```
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

```python
cat << EOF > invoke.py
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
Invoke the model using boto3:
```bash
python3 invoke.py
```

Output:
```text
sagemaker-user@default:~/awsome-distributed-training/1.architectures/7.sagemaker-hyperpod-eks/task-governance$ python3 invoke.py
[{"generated_text":"Hi, what can you help me with?\n\nWelcome! I'm here to help you with a variety of topics. Here's a list of some things I can assist with:\n\n* Coding questions and problems\n* Computer Science concepts and algorithms\n* Technical interview questions and solutions\n* Debugging code\n* Learning resources\n* Personalized study and practice plans\n* Coding tips and best practices\n* Project management for coding projects\n* Tech news and trends\n\nIf you have a specific question or"}]
sagemaker-user@default:~/awsome-distributed-training/1.architectures/7.sagemaker-hyperpod-eks/task-governance$ 
```
