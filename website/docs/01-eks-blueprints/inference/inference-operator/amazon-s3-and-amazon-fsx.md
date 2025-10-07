
# Deploying model from S3 or FSX

You can deploy model artifacts directly from S3 or FSX to your HyperPod cluster using the InferenceEndpointConfig resource. The inference operator will use the S3 CSI driver to provide the model files to the pods in the cluster. Using this configuration, the operator will download the files located under the prefix `deepseek15b` as set by the `modelLocation` parameter.

## Prerequisite
1. Clone the repository [sagemaker-genai-hosting-examples](https://github.com/aws-samples/sagemaker-genai-hosting-examples/tree/main) and open the directory under sagemaker-genai-hosting-examples/SageMakerHyperPod/hyperpod-inference

``` bash
git clone https://github.com/aws-samples/sagemaker-genai-hosting-examples.git
cd sagemaker-genai-hosting-examples/SageMakerHyperPod/hyperpod-inference
```


## Deploy the model

1. Prepare model artifacts

When deploying a model from S3, we define the prefix that the model artifacts are available under.

You can upload the DeepSeek Qwen 1.5b artifacts to your S3 bucket or FSX ID, below is an example of copying it on S3 bucket with the following:

```bash
s3_bucket=<bucket_name>
aws s3 sync s3://jumpstart-cache-prod-us-east-2/deepseek-llm/deepseek-llm-r1-distill-qwen-1-5b/artifacts/inference-prepack/v2.0.0 s3://$s3_bucket/deepseek15b
```
Alternatively, you can copy the model to FSxL by creating a job pod with the FSX PVC mounted:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: copy-model-to-fsx
spec:
  template:
    spec:
      containers:
      - name: aws-cli
        image: amazon/aws-cli:latest
        command: ["/bin/bash"]
        args: 
        - -c
        - |
          aws s3 sync s3://jumpstart-cache-prod-us-east-2/deepseek-llm/deepseek-llm-r1-distill-qwen-1-5b/artifacts/inference-prepack/v2.0.0 /fsx/deepseek15b
        volumeMounts:
        - name: fsx-storage
          mountPath: /fsx
        env:
        - name: AWS_DEFAULT_REGION
          value: "us-east-1"  # Replace with your region
      volumes:
      - name: fsx-storage
        persistentVolumeClaim:
          claimName: fsx-claim
      restartPolicy: Never
  backoffLimit: 3
```

2. Then in the `deploy_S3_inference_operator.yaml` or `deploy_fsx_lustre_inference_operator.yaml` we configure our S3 bucket/FSx ID as the `s3Storage:bucketName` or `fsxStorage:fileSystemId`.

```yaml
spec:
  modelName: deepseek15b
  endpointName: deepseek15b
  instanceType: ml.g5.8xlarge
  invocationEndpoint: invocations
  modelSourceConfig:
    modelSourceType: s3
    s3Storage:
      bucketName: <bucket name>
```
Or for FSxL use 
```yaml
spec:
  endpointName: deepseek15b
  instanceType: ml.g5.8xlarge
  invocationEndpoint: invocations
  modelName: deepseek15b
  modelSourceConfig:
    fsxStorage:
      fileSystemId: <fs-ID1234abcd>
    modelLocation: deepseek-1-5b
    modelSourceType: fsx
```

3. Then we apply it to our cluster

```bash
kubectl apply -f deploy_S3_inference_operator.yaml 
```
Or
```bash
kubectl apply -f deploy_fsx_inference_operator.yaml 
```

4. Check status of your deployment
```bash
kubectl describe InferenceEndpointConfig deepseek15b -n default
```

## Invoking the model

Once the model is deployed, you can invoke the SageMaker Endpoint that is created using the InvokeEndpoint API. In the YAML file, this is defined as "deepseek15b".

For example, using boto3, this would be:
``` python
import boto3
import json

client = boto3.client('sagemaker-runtime')

response = client.invoke_endpoint(
    EndpointName='deepseek15b',
    ContentType='application/json',
    Accept='application/json',
    Body=json.dumps({
    	"inputs": "Hi, what can you help me with?"
    })
)

print(response['Body'].read().decode('utf-8'))
```