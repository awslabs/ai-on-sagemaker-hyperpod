---
title: CUR & Athena Setup
sidebar_position: 2
---

# CUR & Athena Setup

This section configures the AWS Cost and Usage Report (CUR) and Amazon Athena integration that provides the billing data Kubecost uses for pricing and cost visibility.

## Cluster Configuration

### Set Environment Variables

```bash
export CLUSTER_NAME="<your-hyperpod-eks-cluster-name>"
export AWS_REGION="<your-aws-region>"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# Verify
kubectl cluster-info
kubectl get nodes
```

### Get VPC ID

```bash
export VPC_ID=$(aws eks describe-cluster \
    --name $CLUSTER_NAME --region $AWS_REGION \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "VPC ID: $VPC_ID"
```

## CUR Configuration — Legacy & CUR 2.0

### Legacy CUR

```bash
aws cur describe-report-definitions --region us-east-1 --output table

export CUR_REPORT_NAME="<your-cur-report-name>"

export CUR_BUCKET_NAME=$(aws cur describe-report-definitions --region us-east-1 \
    --query "ReportDefinitions[?ReportName=='${CUR_REPORT_NAME}'].S3Bucket" --output text)
export CUR_REGION=$(aws cur describe-report-definitions --region us-east-1 \
    --query "ReportDefinitions[?ReportName=='${CUR_REPORT_NAME}'].S3Region" --output text)

echo "CUR Bucket: $CUR_BUCKET_NAME | Region: $CUR_REGION"
```

### Validate CUR Settings

```bash
echo "=== Validating CUR ==="
FORMAT=$(aws cur describe-report-definitions --region us-east-1 \
    --query "ReportDefinitions[?ReportName=='${CUR_REPORT_NAME}'].Format" --output text)
[ "$FORMAT" = "Parquet" ] && echo "✅ Format: Parquet" || echo "❌ Format must be Parquet"

RESOURCES=$(aws cur describe-report-definitions --region us-east-1 \
    --query "ReportDefinitions[?ReportName=='${CUR_REPORT_NAME}'].AdditionalSchemaElements[0]" --output text)
[[ "$RESOURCES" == *"RESOURCES"* ]] && echo "✅ Resource IDs: Enabled" || echo "❌ Enable Resource IDs"

ARTIFACTS=$(aws cur describe-report-definitions --region us-east-1 \
    --query "ReportDefinitions[?ReportName=='${CUR_REPORT_NAME}'].AdditionalArtifacts" --output text)
[[ "$ARTIFACTS" == *"ATHENA"* ]] && echo "✅ Athena: Enabled" || echo "❌ Enable Athena"
```

### CUR 2.0 (Data Exports)

If using CUR 2.0 instead of or alongside Legacy CUR:

```bash
aws bcm-data-exports list-exports --region us-east-1 --output json \
    | jq '.Exports[] | {Name: .Export.Name, Arn: .ExportArn, Status: .ExportStatus.StatusCode}'
```

The Kubecost cloud integration secret format is identical for both — just point to the correct Athena database/table.

## Verify Athena Integration

### Find Athena Database & Table

```bash
# Try CloudFormation first
aws cloudformation list-stacks --region $CUR_REGION \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query 'StackSummaries[?contains(StackName, `cur`) || contains(StackName, `athena`)].StackName' --output table

export CUR_CFN_STACK_NAME="<your-stack-name>"
export ATHENA_DATABASE=$(aws cloudformation describe-stacks \
    --stack-name $CUR_CFN_STACK_NAME --region $CUR_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`AWSCURDatabase`].OutputValue' --output text)

# Or list databases directly
aws athena list-databases --catalog-name AwsDataCatalog --region $CUR_REGION --output table
export ATHENA_DATABASE="<your-database>"

# Get table
aws athena list-table-metadata --catalog-name AwsDataCatalog \
    --database-name $ATHENA_DATABASE --region $CUR_REGION --output table
export ATHENA_TABLE="<your-table>"

echo "Database: $ATHENA_DATABASE | Table: $ATHENA_TABLE"
```

### Find Athena Results Bucket & Workgroup

```bash
export ATHENA_WORKGROUP="<your-workgroup>"  # Often "cid" or "primary"

export ATHENA_RESULTS_BUCKET=$(aws athena get-work-group \
    --work-group $ATHENA_WORKGROUP --region $CUR_REGION \
    --query 'WorkGroup.Configuration.ResultConfiguration.OutputLocation' \
    --output text | sed 's|s3://||' | cut -d'/' -f1)

echo "Athena Results: $ATHENA_RESULTS_BUCKET | Workgroup: $ATHENA_WORKGROUP"
```

### Test Athena Query

```bash
QUERY_ID=$(aws athena start-query-execution \
    --query-string "SELECT DISTINCT line_item_product_code FROM ${ATHENA_DATABASE}.${ATHENA_TABLE} LIMIT 10;" \
    --query-execution-context Database=${ATHENA_DATABASE} \
    --result-configuration OutputLocation=s3://${ATHENA_RESULTS_BUCKET}/ \
    --region $CUR_REGION --query 'QueryExecutionId' --output text)

# Poll until query completes
while [ "$(aws athena get-query-execution --query-execution-id $QUERY_ID \
  --region $CUR_REGION --query 'QueryExecution.Status.State' --output text)" != "SUCCEEDED" ]; do
  echo "Waiting for query to complete..."
  sleep 5
done
aws athena get-query-results --query-execution-id $QUERY_ID --region $CUR_REGION --output table
# Expected: AmazonEC2, AmazonSageMaker, AmazonS3, etc.
```

## Derive Pricing from CUR via Athena

:::info IMPORTANT
Instead of manually entering pricing, we query your actual AWS billing data to get the effective hourly rate per HyperPod instance type — including any RI/SP/EDP discounts.
:::

### Query Effective Hourly Rates

```bash
QUERY_ID=$(aws athena start-query-execution \
    --query-string "
    SELECT
        REGEXP_EXTRACT(line_item_usage_type, 'Cluster:(.+)', 1) AS instance_type,
        ROUND(SUM(line_item_unblended_cost) / SUM(line_item_usage_amount), 4) AS effective_hourly_rate,
        ROUND(SUM(line_item_unblended_cost), 2) AS total_cost_this_month,
        ROUND(SUM(line_item_usage_amount), 2) AS total_hours
    FROM ${ATHENA_DATABASE}.${ATHENA_TABLE}
    WHERE line_item_product_code = 'AmazonSageMaker'
      AND line_item_usage_type LIKE '%Cluster:ml.%'
      AND line_item_usage_amount > 0
      AND year = '$(date +%Y)' AND month = '$(date +%-m)'
    GROUP BY REGEXP_EXTRACT(line_item_usage_type, 'Cluster:(.+)', 1)
    ORDER BY total_cost_this_month DESC;
    " \
    --query-execution-context Database=${ATHENA_DATABASE} \
    --result-configuration OutputLocation=s3://${ATHENA_RESULTS_BUCKET}/ \
    --region $CUR_REGION --query 'QueryExecutionId' --output text)

echo "Query ID: $QUERY_ID"
# Poll until query completes
while [ "$(aws athena get-query-execution --query-execution-id $QUERY_ID \
  --region $CUR_REGION --query 'QueryExecution.Status.State' --output text)" != "SUCCEEDED" ]; do
  echo "Waiting for query to complete..."
  sleep 5
done
aws athena get-query-results --query-execution-id $QUERY_ID --region $CUR_REGION --output table
```

**Sample Expected output:**

```
| instance_type    | effective_hourly_rate | total_cost_this_month | total_hours |
|------------------|-----------------------|-----------------------|-------------|
| ml.g6.12xlarge   | 13.9860               | 10141.80              | 725.00      |
| ml.m5.12xlarge   | 2.6496                | 1922.17               | 725.40      |
| ml.g5.12xlarge   | 7.0900                | 1142.71               | 161.17      |
```

:::tip
Note the `effective_hourly_rate` — this is your actual rate including RI/SP discounts. Use these values in the next step.
:::

### Verify Which Instance Types Are in Your Cluster

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.node\.kubernetes\.io/instance-type}{"\n"}{end}' | sort -u
```

Make sure every instance type returned here has a corresponding rate from the Athena query above.
