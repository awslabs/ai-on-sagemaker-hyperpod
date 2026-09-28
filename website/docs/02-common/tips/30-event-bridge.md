---
title : "Receive cluster status/health events"
weight : 49
---

## Integration with Amazon EventBridge

SageMaker HyperPod delivers three types of notifications through Amazon EventBridge:
  
  1. [Cluster events](https://docs.aws.amazon.com/sagemaker/latest/dg/automating-sagemaker-with-eventbridge.html#eventbridge-hyperpod-cluster-event)
  1. [Cluster status change events](https://docs.aws.amazon.com/sagemaker/latest/dg/automating-sagemaker-with-eventbridge.html#eventbridge-hyperpod-cluster-state)
  1. [Node health events](https://docs.aws.amazon.com/sagemaker/latest/dg/automating-sagemaker-with-eventbridge.html#eventbridge-hyperpod-node-health)


**Cluster events** is a newly introduced event type for HyperPod's [Continuous Provisioning mode](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-scaling-eks.html). In Continuous Provisioning mode, you will receive detailed events from HyperPod cluster operations including instance provisioning and health events. Also you can get same events by calling [ListClusterEvents](https://docs.aws.amazon.com/sagemaker/latest/APIReference/API_ListClusterEvents.html) API.
**Cluster status change events** and **Node health events** come from HyperPod clusters without Continuous Provisioning mode.

This guide provides instructions for setting up human-readable email notifications for these events using AWS Lambda and Amazon Simple Email Service (SES).

## Setup email notifications

#### 1. Decide email addresses

Firstly, determine the sender's email address and receiver's email address.

#### 2. Create and verify email identities in SES

Visit the [management console of Amazon SES](https://console.aws.amazon.com/ses/home#/identities), create email identities (for both sender address and receiver address) from the "Create identity" button.

![SES Console](/img/11-tips/ses-console.png)

A confirmation email will be sent to your email address. Click on the link to verify your email address and make sure your "Identity status" changes to "Verified".

#### 3. Deploy the CloudFormation template

Click the button below to deploy the CloudFormation stack, which will install the EventBridge rule, Lambda function, and required IAM roles.

[Deploy EventBridge Email Stack](https://console.aws.amazon.com/cloudformation/home?#/stacks/quickcreate?templateURL=https://ws-assets-prod-iad-r-iad-ed304a55c2ca1aee.s3.us-east-1.amazonaws.com/2433d39e-ccfe-4c00-9d3d-9917b729258e/hyperpod-event-bridge-email.yaml&stackName=hyperpod-event-bridge-email)

#### 4. Verify

Verify that you can receive notification emails by changing the cluster status (e.g., scaling up/down).
You can also test node health notifications by triggering [manuall instance replacement](/docs/eks-orchestration/validation-and-testing/resiliency/eks-resiliency#1manual-replacement-or-reboot).

![Node Health Email](/img/11-tips/node-health-email.png)


## Troubleshooting

If you don't receive the email, please check whether it is being classified as spam, and monitor the graphs in the EventBridge console and Lambda console to see if any errors are occurring. If your Lambda function is failing, check CloudWatch Logs for the reason for the failure.

## Next steps

- You can customize the format of the emails by modifying the Lambda function. You can extract more information from [the event JSON data](https://docs.aws.amazon.com/sagemaker/latest/dg/automating-sagemaker-with-eventbridge.html#eventbridge-hyperpod-cluster-event), or even by calling SageMaker AI service APIs.
- If you used Amazon SES for the first time, your SES account is most likely in the sandbox mode. Some restrictions are applied to the sandbox mode. See [this document](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) to learn more about the sandbox mode, and how to moved out of the sandbox and into production.
