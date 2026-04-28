---
title: Cost Allocation from CUR
sidebar_position: 8
---

# GPU Cost Allocation from CUR

This page converts GPU-hours (from [Data Extraction](./06-data-extraction.md)) into dollar costs using your actual instance pricing from the AWS Cost and Usage Report (CUR).

## The Formula

```
GPU Hourly Rate = Instance Hourly Cost (from CUR) ÷ GPUs Per Instance

User Cost     = User GPU-Hours (from sreport)     × GPU Hourly Rate
Team Cost     = Team GPU-Hours (from sreport)     × GPU Hourly Rate
Project Cost  = Project GPU-Hours (from sacct)    × GPU Hourly Rate
```

## How HyperPod Billing Works in CUR

:::warning Critical
SageMaker HyperPod compute is billed under `AmazonSageMaker` in CUR — **not** under `AmazonEC2`. The instance type is embedded in the usage type string as `Cluster:ml.<type>`.
:::

| Component | CUR `line_item_product_code` | CUR `line_item_usage_type` |
|---|---|---|
| HyperPod compute nodes | `AmazonSageMaker` | `<region>-Cluster:ml.p4d.24xlarge` |
| HyperPod EBS volumes | `AmazonSageMaker` | `<region>-Cluster:VolumeUsage.gp2` |
| FSx Lustre storage | `AmazonFSx` | Various |
| EKS control plane | `AmazonEKS` | `<region>-AmazonEKS-Hours:perCluster` |

## Discover HyperPod Usage Types

Run this first to see what HyperPod line items exist in your CUR:

```sql
SELECT DISTINCT
    line_item_product_code,
    line_item_usage_type,
    line_item_operation
FROM <YOUR_CUR_DATABASE>.<YOUR_CUR_TABLE>
WHERE line_item_product_code = 'AmazonSageMaker'
    AND line_item_usage_type LIKE '%Cluster:%'
ORDER BY line_item_usage_type;
```

## Get Effective Hourly Rate Per Instance Type

This query returns the actual rate you're paying, including any RI/SP/EDP discounts:

```sql
SELECT
    REGEXP_EXTRACT(line_item_usage_type, 'Cluster:(.+)', 1) AS instance_type,
    ROUND(SUM(line_item_unblended_cost) / SUM(line_item_usage_amount), 4) AS effective_hourly_rate,
    ROUND(SUM(line_item_unblended_cost), 2) AS total_cost_this_month,
    ROUND(SUM(line_item_usage_amount), 2) AS total_hours
FROM <YOUR_CUR_DATABASE>.<YOUR_CUR_TABLE>
WHERE line_item_product_code = 'AmazonSageMaker'
    AND line_item_usage_type LIKE '%Cluster:ml.%'
    AND line_item_usage_amount > 0
    AND year = CAST(YEAR(CURRENT_DATE) AS VARCHAR)
    AND month = CAST(MONTH(CURRENT_DATE) AS VARCHAR)
GROUP BY REGEXP_EXTRACT(line_item_usage_type, 'Cluster:(.+)', 1)
ORDER BY total_cost_this_month DESC;
```

**Example output:**

| instance_type | effective_hourly_rate | total_cost_this_month | total_hours |
|---|---|---|---|
| ml.p4d.24xlarge | 37.6880 | 27,324.32 | 725.00 |
| ml.p5.48xlarge | 98.3200 | 71,282.00 | 725.00 |
| ml.g5.12xlarge | 7.0900 | 1,142.71 | 161.17 |

## GPU Reference Table

| Instance Type | GPUs | GPU Type | Memory/GPU |
|---|---|---|---|
| ml.p5.48xlarge | 8 | H100 80GB | 80 GB |
| ml.p4d.24xlarge | 8 | A100 40GB | 40 GB |
| ml.p4de.24xlarge | 8 | A100 80GB | 80 GB |
| ml.p3.16xlarge | 8 | V100 16GB | 16 GB |
| ml.p3.8xlarge | 4 | V100 16GB | 16 GB |
| ml.g5.48xlarge | 8 | A10G 24GB | 24 GB |
| ml.g5.12xlarge | 4 | A10G 24GB | 24 GB |
| ml.g6.12xlarge | 4 | L4 24GB | 24 GB |

**Example:** `ml.p4d.24xlarge: $37.69/hr ÷ 8 GPUs = $4.71 per GPU-hour`

## Create Athena Cost Views

These views join your Slurm GPU-hours data with CUR-derived rates.

### GPU Cost Rate Reference

Update values with your actual rates from the CUR query above:

```sql
CREATE OR REPLACE VIEW gpu_chargeback.gpu_cost_rates AS
SELECT * FROM (VALUES
    ('ml.p4d.24xlarge',  8, 37.6880, 37.6880 / 8),
    ('ml.p5.48xlarge',   8, 98.3200, 98.3200 / 8),
    ('ml.g5.12xlarge',   4,  7.0900,  7.0900 / 4)
) AS t(instance_type, gpus_per_instance, instance_hourly_cost, gpu_hourly_cost);
```

:::tip Single Instance Type Clusters
If your cluster uses one instance type, this is just one row. The `gpu_hourly_cost` column is what gets multiplied by GPU-hours.
:::

### Per-User Cost View

:::warning Single Instance Type Assumption
The cost views below use `CROSS JOIN ... LIMIT 1` to pick one GPU cost rate from the `gpu_cost_rates` table. This assumes your cluster uses a **single instance type**. If you have multiple instance types, `LIMIT 1` will silently pick an arbitrary row with no guarantee of which. For mixed-instance clusters, use the **weighted average approach** described at the bottom of this page instead.
:::

```sql
CREATE OR REPLACE VIEW gpu_chargeback.user_cost AS
SELECT
    au.account AS team,
    au.login AS username,
    au.proper AS display_name,
    au.used AS gpu_hours,
    cr.gpu_hourly_cost,
    ROUND(au.used * cr.gpu_hourly_cost, 2) AS cost_usd,
    au.period, au.year, au.month, au.day
FROM gpu_chargeback.account_utilization au
CROSS JOIN (
    SELECT gpu_hourly_cost FROM gpu_chargeback.gpu_cost_rates LIMIT 1
) cr
WHERE au.used > 0;
```

### Per-Team Cost View

```sql
CREATE OR REPLACE VIEW gpu_chargeback.team_cost AS
SELECT
    team,
    SUM(gpu_hours) AS total_gpu_hours,
    gpu_hourly_cost,
    ROUND(SUM(gpu_hours) * gpu_hourly_cost, 2) AS total_cost_usd,
    COUNT(DISTINCT username) AS active_users,
    period, year, month
FROM gpu_chargeback.user_cost
GROUP BY team, gpu_hourly_cost, period, year, month;
```

### Per-Project Cost View

Parses `project-id` from the Comment field and computes GPU-hours per project:

```sql
CREATE OR REPLACE VIEW gpu_chargeback.project_cost AS
SELECT
    account AS team,
    "user" AS username,
    regexp_extract(comment, 'project-id:([^,]+)', 1) AS project_id,
    COUNT(*) AS job_count,
    SUM(gpu_count) AS total_gpus_used,
    ROUND(SUM(gpu_hours), 2) AS total_gpu_hours,
    ROUND(SUM(gpu_hours) * cr.gpu_hourly_cost, 2) AS cost_usd,
    period, year, month
FROM (
    SELECT
        account, "user", comment, period, year, month,
        CAST(regexp_extract(alloctres, 'gres/gpu=(\d+)', 1) AS INTEGER) AS gpu_count,
        CAST(regexp_extract(alloctres, 'gres/gpu=(\d+)', 1) AS INTEGER)
        * (
            COALESCE(CAST(regexp_extract(elapsed, '^(\d+)-', 1) AS DOUBLE), 0) * 24.0
            + COALESCE(CAST(regexp_extract(elapsed, '(\d+):(\d+):(\d+)$', 1) AS DOUBLE), 0)
            + COALESCE(CAST(regexp_extract(elapsed, '(\d+):(\d+):(\d+)$', 2) AS DOUBLE), 0) / 60.0
            + COALESCE(CAST(regexp_extract(elapsed, '(\d+):(\d+):(\d+)$', 3) AS DOUBLE), 0) / 3600.0
        ) AS gpu_hours
    FROM gpu_chargeback.jobs_detailed
    WHERE comment LIKE '%project-id:%'
        AND state = 'COMPLETED'
        AND alloctres LIKE '%gres/gpu=%'
) jobs
CROSS JOIN (
    SELECT gpu_hourly_cost FROM gpu_chargeback.gpu_cost_rates LIMIT 1
) cr
WHERE gpu_hours > 0
GROUP BY account, "user", regexp_extract(comment, 'project-id:([^,]+)', 1),
         cr.gpu_hourly_cost, period, year, month;
```

## Run Cost Queries

```sql
-- Per-user cost
SELECT team, username, display_name, gpu_hours, cost_usd
FROM gpu_chargeback.user_cost
WHERE period = 'monthly'
ORDER BY cost_usd DESC;

-- Per-team cost
SELECT team, total_gpu_hours, total_cost_usd, active_users
FROM gpu_chargeback.team_cost
WHERE period = 'monthly'
ORDER BY total_cost_usd DESC;

-- Per-project cost
SELECT team, project_id, job_count, total_gpu_hours, cost_usd
FROM gpu_chargeback.project_cost
WHERE period = 'monthly'
ORDER BY cost_usd DESC;
```

## Automated Cost Report Script

Create `/fsx/ubuntu/slurmAccounting/scripts/generate_cost_reports.sh`:

```bash
#!/bin/bash
set -e

PERIOD="${1:-monthly}"
REPORT_DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="/fsx/ubuntu/slurmAccounting/reports/costReports"
S3_BUCKET="<YOUR_GPU_ACCOUNTING_BUCKET>"
ATHENA_DATABASE="gpu_chargeback"
ATHENA_RESULTS="s3://${S3_BUCKET}/athena-results/"
ATHENA_WORKGROUP="primary"
REGION="<YOUR_REGION>"

mkdir -p $OUTPUT_DIR

run_athena_query() {
    local QUERY="$1"
    local OUTPUT_FILE="$2"

    QUERY_ID=$(aws athena start-query-execution \
        --query-string "$QUERY" \
        --query-execution-context Database=${ATHENA_DATABASE} \
        --result-configuration OutputLocation=${ATHENA_RESULTS} \
        --work-group ${ATHENA_WORKGROUP} \
        --region ${REGION} \
        --query 'QueryExecutionId' --output text)

    for i in $(seq 1 60); do
        STATE=$(aws athena get-query-execution --query-execution-id $QUERY_ID \
            --region ${REGION} --query 'QueryExecution.Status.State' --output text)
        [ "$STATE" = "SUCCEEDED" ] && break
        [ "$STATE" = "FAILED" ] && echo "Query failed" && return 1
        sleep 5
    done

    aws athena get-query-results --query-execution-id $QUERY_ID \
        --region ${REGION} --output text > "$OUTPUT_FILE"
}

run_athena_query \
    "SELECT team, username, display_name, gpu_hours, cost_usd FROM ${ATHENA_DATABASE}.user_cost WHERE period='${PERIOD}' ORDER BY cost_usd DESC" \
    "$OUTPUT_DIR/user_cost_${PERIOD}_${REPORT_DATE}.csv"

run_athena_query \
    "SELECT team, total_gpu_hours, total_cost_usd, active_users FROM ${ATHENA_DATABASE}.team_cost WHERE period='${PERIOD}' ORDER BY total_cost_usd DESC" \
    "$OUTPUT_DIR/team_cost_${PERIOD}_${REPORT_DATE}.csv"

run_athena_query \
    "SELECT team, project_id, username, job_count, total_gpu_hours, cost_usd FROM ${ATHENA_DATABASE}.project_cost WHERE period='${PERIOD}' ORDER BY cost_usd DESC" \
    "$OUTPUT_DIR/project_cost_${PERIOD}_${REPORT_DATE}.csv"

# Upload to S3
YEAR=$(date +%Y); MONTH=$(date +%m); DAY=$(date +%d)
S3_PREFIX="s3://${S3_BUCKET}/cost-reports/period=${PERIOD}/year=${YEAR}/month=${MONTH}/day=${DAY}"
for file in $OUTPUT_DIR/*_${PERIOD}_${REPORT_DATE}.csv; do
    [ -f "$file" ] && aws s3 cp "$file" "${S3_PREFIX}/$(basename $file)" --region ${REGION}
done
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/generate_cost_reports.sh
```

Schedule after GPU reports (add to existing crontab):

```bash
# Cost reports — 30 minutes after GPU reports
30 1 * * 1 /fsx/ubuntu/slurmAccounting/scripts/generate_cost_reports.sh weekly >> /var/log/slurm/cost_weekly.log 2>&1
30 2 1 * * /fsx/ubuntu/slurmAccounting/scripts/generate_cost_reports.sh monthly >> /var/log/slurm/cost_monthly.log 2>&1
```

## Update Cost Rates

When your CUR rates change (new discounts, instance types), update the Athena view:

```sql
CREATE OR REPLACE VIEW gpu_chargeback.gpu_cost_rates AS
SELECT * FROM (VALUES
    ('ml.p4d.24xlarge', 8, 35.5000, 35.5000 / 8),
    ('ml.p5.48xlarge',  8, 98.3200, 98.3200 / 8),
    ('ml.g5.12xlarge',  4,  7.0900,  7.0900 / 4)
) AS t(instance_type, gpus_per_instance, instance_hourly_cost, gpu_hourly_cost);
```

:::tip Mixed Instance Types
If users run on different instance types and you can't determine which, use a weighted average:
```sql
SELECT ROUND(SUM(line_item_unblended_cost) / SUM(line_item_usage_amount), 4) AS blended_rate
FROM <YOUR_CUR_DATABASE>.<YOUR_CUR_TABLE>
WHERE line_item_product_code = 'AmazonSageMaker'
    AND line_item_usage_type LIKE '%Cluster:ml.%'
    AND line_item_usage_amount > 0;
```
:::
