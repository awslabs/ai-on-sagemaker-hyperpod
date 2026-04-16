---
title: QuickSight Dashboard (optional)
sidebar_position: 9
---

# QuickSight Dashboard

Amazon QuickSight provides visual dashboards for GPU chargeback data. This page covers creating Athena tables from your S3 reports and building QuickSight visualizations.

## Configure QuickSight S3 Access

1. Go to **QuickSight Console** → **Manage QuickSight** → **Security & permissions**
2. Click **Manage** under "QuickSight access to AWS services"
3. Select **S3** and add your GPU accounting bucket

## Create Athena Tables

Run in the Athena Query Editor. These tables match the Hive-style S3 paths from [S3 Upload](./07-s3-upload-automation.md).

```sql
CREATE DATABASE IF NOT EXISTS gpu_chargeback;

-- Account Utilization (GPU hours by team & user)
CREATE EXTERNAL TABLE IF NOT EXISTS gpu_chargeback.account_utilization (
    account STRING,
    login STRING,
    proper STRING,
    used DOUBLE
)
PARTITIONED BY (period STRING, year STRING, month STRING, day STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '|'
STORED AS TEXTFILE
LOCATION 's3://<your-gpu-accounting-bucket>/slurm-reports/'
TBLPROPERTIES ('skip.header.line.count'='0');

-- Top Users
CREATE EXTERNAL TABLE IF NOT EXISTS gpu_chargeback.top_users (
    account STRING,
    login STRING,
    used DOUBLE
)
PARTITIONED BY (period STRING, year STRING, month STRING, day STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '|'
STORED AS TEXTFILE
LOCATION 's3://<your-gpu-accounting-bucket>/slurm-reports/';

-- Jobs Detailed (includes project-id in comment)
CREATE EXTERNAL TABLE IF NOT EXISTS gpu_chargeback.jobs_detailed (
    jobid STRING,
    jobname STRING,
    user STRING,
    account STRING,
    partition STRING,
    state STRING,
    elapsed STRING,
    alloctres STRING,
    comment STRING
)
PARTITIONED BY (period STRING, year STRING, month STRING, day STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '|'
STORED AS TEXTFILE
LOCATION 's3://<your-gpu-accounting-bucket>/slurm-reports/';

-- GPU Count per Job
CREATE EXTERNAL TABLE IF NOT EXISTS gpu_chargeback.gpu_count_per_job (
    jobid STRING,
    jobname STRING,
    user STRING,
    account STRING,
    allocgres STRING,
    elapsed STRING,
    state STRING,
    start_time STRING,
    end_time STRING
)
PARTITIONED BY (period STRING, year STRING, month STRING, day STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '|'
STORED AS TEXTFILE
LOCATION 's3://<your-gpu-accounting-bucket>/slurm-reports/';

-- GPU Count Summary
CREATE EXTERNAL TABLE IF NOT EXISTS gpu_chargeback.gpu_count_summary (
    account STRING,
    user STRING,
    total_jobs INT,
    total_gpus_allocated INT,
    avg_gpus_per_job DOUBLE,
    max_gpus INT
)
PARTITIONED BY (period STRING, year STRING, month STRING, day STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '|'
STORED AS TEXTFILE
LOCATION 's3://<your-gpu-accounting-bucket>/slurm-reports/';

-- Load all partitions
MSCK REPAIR TABLE gpu_chargeback.account_utilization;
MSCK REPAIR TABLE gpu_chargeback.top_users;
MSCK REPAIR TABLE gpu_chargeback.jobs_detailed;
MSCK REPAIR TABLE gpu_chargeback.gpu_count_per_job;
MSCK REPAIR TABLE gpu_chargeback.gpu_count_summary;
```

:::note Partition Discovery
Run `MSCK REPAIR TABLE` after each new upload to discover new partitions. Or use a Glue Crawler to auto-detect them.
:::

## Create QuickSight Datasets

1. **QuickSight Console** → Datasets → New Dataset → **Athena**
2. Create datasets:

| Dataset Name | Athena Source | Import Mode |
|---|---|---|
| `gpu_account_utilization` | `gpu_chargeback.account_utilization` | SPICE |
| `gpu_user_cost` | `gpu_chargeback.user_cost` | SPICE |
| `gpu_team_cost` | `gpu_chargeback.team_cost` | SPICE |
| `gpu_project_cost` | `gpu_chargeback.project_cost` | SPICE |

3. Schedule SPICE refresh daily (after report upload cron)

:::info Cost Views
The `user_cost`, `team_cost`, and `project_cost` views are created in [Cost Allocation from CUR](./08-cost-allocation-from-cur.md). Create them before building cost-based datasets.
:::

## Build GPU Chargeback Dashboard

### Option A: Standalone Dashboard

1. Create a new Analysis from your GPU datasets
2. Build sheets with the visuals below
3. Publish as a dashboard

### Option B: Add Tab to CID/CUDOS

1. Open CID Dashboard → **Save As** → Create Analysis (backup first)
2. In Analysis → click **Add dataset** → add your GPU cost datasets
3. Click **+ Add sheet** → name it "GPU Chargeback"
4. Build visuals below
5. Publish updated dashboard

:::warning CID Updates
CID template updates may overwrite custom sheets. Always save a backup Analysis copy before updating CID.
:::

## Recommended Visuals

### GPU Usage Sheet

| Visual | Type | Configuration |
|---|---|---|
| GPU Hours by Team | Bar Chart | X: account, Value: SUM(used) |
| Top Users | Table | Columns: login, account, used |
| Cluster Utilization | KPI | Value: SUM(allocated) / SUM(total) |
| Usage Trend | Line Chart | X: month, Value: SUM(used), Color: account |

### GPU Cost Sheet

| Visual | Type | Configuration |
|---|---|---|
| Team Cost Summary | Bar Chart | X: team, Value: SUM(total_cost_usd) |
| Top Users by Cost | Table | Columns: username, team, cost_usd, gpu_hours |
| Cost by Project | Donut Chart | Group: project_id, Value: SUM(cost_usd) |
| Monthly Cost Trend | Line Chart | X: month, Value: SUM(total_cost_usd), Color: team |
| KPI: Total GPU Cost | KPI | Value: SUM(cost_usd) |
| KPI: Total GPU Hours | KPI | Value: SUM(gpu_hours) |
| KPI: Cost per GPU-Hour | KPI | Value: AVG(gpu_hourly_cost) |

## Modify Dashboard

| Action | Steps |
|--------|-------|
| Add visualization | Edit dashboard → Add visual → Select chart type |
| Add date filter | Edit → Add filter → Select date field |
| Add calculated field | Edit dataset → Add calculated field → Enter formula |
| Share dashboard | Dashboard → Share → Users/Groups → Set permissions |
| Schedule email reports | Dashboard → Schedule → Set frequency → Add recipients |
| Refresh data | Datasets → Select dataset → Refresh now |
