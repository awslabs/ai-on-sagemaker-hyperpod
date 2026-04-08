---
title: Mistral 7B Inference with Load Balancer
sidebar_position: 1
sidebar_label: Mistral 7B with Load Balancer
---

# Mistral 7B Inference with TGI Container and Load Balancer

This guide demonstrates how to deploy Mistral 7B for inference using Hugging Face's Text Generation Inference (TGI) container and expose it through an AWS Load Balancer on SageMaker HyperPod EKS.

## Overview

The AWS Load Balancer Controller manages AWS Elastic Load Balancers for a Kubernetes cluster. You can use the controller to expose your models to the internet or internal traffic. The controller provisions AWS load balancers that point to cluster Service or Ingress resources deployed in your HyperPod cluster.

**Model Requirements:**
- **Mistral 7B** in fp16 requires 14 GB of GPU memory
- **Instance requirement**: 1 A10G GPU minimum
- **Container**: Hugging Face TGI container

## Prerequisites

Before proceeding, ensure you have:

- A functional HyperPod EKS cluster with GPU nodes
- `eksctl` installed for IAM OIDC provider creation
- A Hugging Face Hub token for model access
- Appropriate AWS permissions for load balancer management

## 1. Setup Load Balancer Controller

### 1.1 Set Environment Variables

Configure the required environment variables for your cluster:

```bash
export AWS_REGION={your-region}
export EKS_CLUSTER_NAME={your-eks-cluster-name}
export HP_CLUSTER_NAME={your-hyperpod-cluster-name}
export VPC_ID={your-vpc-id}
```

### 1.2 Associate IAM OIDC Provider

Associate your EKS cluster with IAM as an OIDC provider:

```bash
eksctl utils associate-iam-oidc-provider \
    --region ${AWS_REGION} \
    --cluster ${EKS_CLUSTER_NAME} \
    --approve
```

Expected output:
```
2024-06-21 11:23:06 [ℹ] eksctl version 0.69.0
2024-06-21 11:23:06 [ℹ] using region us-east-1
2024-06-21 11:23:07 [ℹ] will create IAM Open ID Connect provider for cluster "compass-beta" in "us-east-1"
2024-06-21 11:23:08 [✔] created IAM Open ID Connect provider for cluster "compass-beta" in "us-east-1"
```

:::info
If you receive a message that the IAM Open ID Connect provider is already associated with the cluster, proceed to the next step.
:::

### 1.3 Create IAM Policy

Create an IAM policy for the AWS Load Balancer Controller:

```bash
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.10.0/docs/install/iam_policy.json

aws iam create-policy \
      --policy-name AWSLoadBalancerControllerIAMPolicy \
      --policy-document file://iam-policy.json
```

### 1.4 Create IAM Service Account

Create an IAM role and associate it with the service account:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

eksctl create iamserviceaccount \
--cluster=${EKS_CLUSTER_NAME} \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--region=${AWS_REGION} \
--approve
```

### 1.5 Install Load Balancer Controller

Install the AWS Load Balancer Controller using Helm:

```bash
# Add EKS Helm charts
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# Install the controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${HP_CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set vpcId=${VPC_ID} \
  --set region=${AWS_REGION}
```

### 1.6 Verify Installation

Verify that version v2.10.0 or later is installed (required for HyperPod support):

```bash
helm ls -n kube-system
```

Expected output:
```
NAME                        	NAMESPACE  	REVISION	UPDATED                             	STATUS  	CHART                              	APP VERSION
aws-load-balancer-controller	kube-system	1       	2024-11-03 00:10:46.548465 -0700 PDT	deployed	aws-load-balancer-controller-1.10.0	v2.10.0    
```

Check that the controller pods are running:

```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

### 1.7 Configure Public Subnets

Tag the public subnets for load balancer usage:

```bash
# Get public subnets
PUBLIC_SUBNETS=$(aws ec2 describe-subnets --filters "[ {\"Name\":\"vpc-id\",\"Values\":[\"${VPC_ID}\"]}, {\"Name\":\"map-public-ip-on-launch\",\"Values\":[\"true\"]} ]" --query 'Subnets[*].{SubnetId:SubnetId}' --output text)

# Add required tags
for SUBNET_ID in $PUBLIC_SUBNETS; do
    aws ec2 create-tags --resources $SUBNET_ID --tags Key=kubernetes.io/role/elb,Value=1
done
```

Verify the tags were added:

```bash
for SUBNET_ID in $PUBLIC_SUBNETS; do
    aws ec2 describe-tags --filters "Name=resource-id,Values=${SUBNET_ID}"
done
```

## 2. Deploy Mistral 7B with TGI

### 2.1 Create Deployment Manifest

Create the Kubernetes manifest for Mistral 7B deployment:

```bash
cat <<EOF > mistral_TGI_eks.yml
---
apiVersion: v1
kind: Pod
metadata:
  name: text-inference
  labels:
    app: text-inference
spec:
  containers:
    - name: text-generation-inference
      image: ghcr.io/huggingface/text-generation-inference:2.1.1
      resources:
        limits:
          nvidia.com/gpu: 1
        requests:
          cpu: "4"
          memory: 4Gi
          nvidia.com/gpu: 1
      command:
        - "text-generation-launcher"
        - "--model-id"
        - "mistralai/Mistral-7B-Instruct-v0.2"
        - "--num-shard"
        - "1"
      ports:
        - containerPort: 80
          name: http
      volumeMounts:
        - name: model
          mountPath: /data
        - name: shm
          mountPath: /dev/shm
      env:
        - name: HUGGING_FACE_HUB_TOKEN
          value: "YOUR_HF_TOKEN_HERE"  # Replace with your actual token
  volumes:
    - name: model
      hostPath:
       path: /opt/dlami/nvme
       type: DirectoryOrCreate
    - name: shm
      emptyDir:
        medium: Memory
        sizeLimit: 1Gi
  tolerations:
    - key: "nvidia.com/gpu"
      operator: "Exists"
      effect: "NoSchedule"
  restartPolicy: Never
---
apiVersion: v1
kind: Service
metadata:
  name: text-inference-nlb
  annotations:
    # NLB specific annotations
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  ports:
    - port: 80
      protocol: TCP
      targetPort: http
  selector:
    app: text-inference
  type: LoadBalancer
EOF
```

### 2.2 Configure Hugging Face Token

**Important**: Update the `HUGGING_FACE_HUB_TOKEN` value in the manifest with your actual Hugging Face token before deploying.

Edit the file and replace `YOUR_HF_TOKEN_HERE` with your token:

```bash
# Edit the file to add your Hugging Face token
vim mistral_TGI_eks.yml
```

### 2.3 Deploy the Resources

Deploy the Mistral 7B inference service:

```bash
kubectl apply -f mistral_TGI_eks.yml
```

### 2.4 Verify Deployment

Check that the pod is running:

```bash
kubectl get pods
```

Expected output:
```
NAME             READY   STATUS      RESTARTS        AGE   IP              NODE                           NOMINATED NODE   READINESS GATES
text-inference   1/1     Running     0               26d   10.192.20.179   hyperpod-i-04c866398de1d6c9b   <none>           <none>
```

Check the service and load balancer:

```bash
kubectl get svc
```

Expected output:
```
text-inference-nlb   LoadBalancer   172.20.155.118   k8s-default-textinfe-6b45939327-004c0b23beebf81f.elb.us-east-1.amazonaws.com   80:31584/TCP   69m
```

:::info
Wait for the load balancer to be fully provisioned. You can check the status in the AWS Console under EC2 → Load Balancers.
:::

## 3. Test the Inference Endpoint

### 3.1 Get Load Balancer URL

Copy the DNS name from the service output above and test the inference endpoint:

```bash
# Replace with your actual load balancer DNS name
export LB_URL="k8s-default-textinfe-6b45939327-004c0b23beebf81f.elb.us-east-1.amazonaws.com"

# Test the inference endpoint
curl http://${LB_URL}:80/generate \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": "how to make chocolate cake",
    "parameters": {
      "max_new_tokens": 256,
      "temperature": 0.5
    }
  }'
```

### 3.2 Expected Response

You should receive a response similar to:

```json
{
  "generated_text": " with sour cream?\n\nYou can make a chocolate cake with sour cream by adding sour cream to the batter. This will give the cake a richer flavor and make it more moist.\n\n## What is the best way to make a chocolate cake from scratch?\n\nThere are many different ways to make a chocolate cake from scratch, but there are a few key steps that are essential to making a delicious and moist cake. First, you will need to mix together the dry ingredients. This includes flour, sugar, cocoa powder, baking powder, and salt. Once the dry ingredients are combined, you will need to add in the wet ingredients. This includes eggs, milk, and vegetable oil. Finally, you will need to bake the cake in a preheated oven.\n\n## What are the key ingredients in a chocolate cake?\n\nThere are many different ways to make a chocolate cake, but there are a few key ingredients that are essential for a delicious and moist cake. The first key ingredient is chocolate. The type of chocolate you use will determine the flavor and richness of your cake. For a classic chocolate cake, you will need unsweetened chocolate. The second key ingredient is butter. Butter adds flavor and rich"
}
```

## 4. Cleanup

### 4.1 Delete the Deployment

To remove the Mistral 7B deployment and associated resources:

```bash
kubectl delete -f mistral_TGI_eks.yml
```

### 4.2 Verify Cleanup

Confirm that the resources have been deleted:

```bash
kubectl get pods
kubectl get svc
```

The load balancer will also be automatically deleted when the service is removed.

## Troubleshooting

### Common Issues

1. **Pod not starting**: Check if GPU resources are available and the Hugging Face token is valid
2. **Load balancer not accessible**: Verify that public subnets are properly tagged
3. **Model download issues**: Ensure the Hugging Face token has access to the Mistral model

### Monitoring Commands

```bash
# Check pod logs
kubectl logs text-inference

# Describe pod for events
kubectl describe pod text-inference

# Check service status
kubectl describe svc text-inference-nlb
```

## Next Steps

- **Scale the deployment**: Convert to a Deployment with multiple replicas for higher availability
- **Add monitoring**: Integrate with Prometheus and Grafana for performance monitoring
- **Implement autoscaling**: Use Horizontal Pod Autoscaler based on request metrics
- **Security enhancements**: Add authentication and rate limiting to the inference endpoint

For more advanced configurations and other model deployments, refer to the [Hugging Face TGI documentation](https://huggingface.co/docs/text-generation-inference/index).