---
title: S3 Upload Automation
sidebar_position: 7
---

# S3 Upload Automation

Uploading GPU reports to S3 enables downstream analytics via Athena and QuickSight, persistent storage for audit trails, and access for non-cluster stakeholders.

## Create S3 Bucket

```bash
S3_BUCKET="<YOUR_GPU_ACCOUNTING_BUCKET>"

aws s3 mb s3://$S3_BUCKET --region <YOUR_REGION>

aws s3api put-bucket-versioning \
    --bucket $S3_BUCKET \
    --versioning-configuration Status=Enabled
```

## Upload Script

Create `/fsx/ubuntu/slurmAccounting/scripts/upload_to_s3.sh`:

```bash
#!/bin/bash
set -e

REPORT_DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="/fsx/ubuntu/slurmAccounting/reports"
S3_BUCKET="<YOUR_GPU_ACCOUNTING_BUCKET>"
PERIOD="${1:-monthly}"

# Hive-style partitioning for Athena compatibility
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
S3_BASE="s3://${S3_BUCKET}/slurm-reports"

# Upload each report to its own sub-path so Athena tables don't cross-read
REPORT_TYPES="account_utilization top_users job_sizes cluster_utilization jobs_detailed gpu_count_per_job gpu_count_summary"

for REPORT in $REPORT_TYPES; do
    FILE="$OUTPUT_DIR/${REPORT}_${PERIOD}_${REPORT_DATE}.csv"
    if [ -f "$FILE" ]; then
        S3_PREFIX="${S3_BASE}/report=${REPORT}/period=${PERIOD}/year=${YEAR}/month=${MONTH}/day=${DAY}"
        aws s3 cp "$FILE" "${S3_PREFIX}/$(basename $FILE)"
        echo "Uploaded: $(basename $FILE) → $S3_PREFIX"
    fi
done

echo "Upload complete"
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/upload_to_s3.sh
```

:::info S3 Path Structure
The Hive-style partitioning (`period=monthly/year=2026/month=04/day=09/`) allows Athena to automatically discover partitions and efficiently query subsets of data.
:::

## Combined Generate & Upload Script

Create `/fsx/ubuntu/slurmAccounting/scripts/generate_and_upload_reports.sh`:

```bash
#!/bin/bash
PERIOD="${1:-monthly}"
SCRIPT_DIR="/fsx/ubuntu/slurmAccounting/scripts"
$SCRIPT_DIR/generate_gpu_reports.sh $PERIOD
$SCRIPT_DIR/upload_to_s3.sh $PERIOD
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/generate_and_upload_reports.sh
```

## Schedule with Cron

```bash
sudo crontab -e
```

```bash
# Weekly - Monday 1 AM
0 1 * * 1 /fsx/ubuntu/slurmAccounting/scripts/generate_and_upload_reports.sh weekly >> /var/log/slurm/chargeback_weekly.log 2>&1

# Monthly - 1st of month 2 AM
0 2 1 * * /fsx/ubuntu/slurmAccounting/scripts/generate_and_upload_reports.sh monthly >> /var/log/slurm/chargeback_monthly.log 2>&1

# Yearly - January 1st 3 AM
0 3 1 1 * /fsx/ubuntu/slurmAccounting/scripts/generate_and_upload_reports.sh yearly >> /var/log/slurm/chargeback_yearly.log 2>&1
```

## Verify Upload

```bash
# List uploaded files
aws s3 ls s3://<YOUR_GPU_ACCOUNTING_BUCKET>/slurm-reports/ --recursive

# Manual run
/fsx/ubuntu/slurmAccounting/scripts/generate_and_upload_reports.sh monthly
```

## Modify Upload Configuration

```bash
# Change bucket — edit upload_to_s3.sh:
S3_BUCKET="new-bucket-name"

# Change schedule — edit crontab:
# Daily: 0 1 * * *
# Bi-weekly: 0 1 1,15 * *

# Manual upload of existing reports
/fsx/ubuntu/slurmAccounting/scripts/upload_to_s3.sh monthly
```
