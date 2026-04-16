---
title: S3 Upload Automation
sidebar_position: 7
---

# S3 Upload Automation

Uploading GPU reports to S3 enables downstream analytics via Athena and QuickSight, persistent storage for audit trails, and access for non-cluster stakeholders.

## Create S3 Bucket

```bash
S3_BUCKET="<your-gpu-accounting-bucket>"

aws s3 mb s3://$S3_BUCKET --region <your-region>

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
S3_BUCKET="<your-gpu-accounting-bucket>"
PERIOD="${1:-monthly}"

# Hive-style partitioning for Athena compatibility
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
S3_PREFIX="s3://${S3_BUCKET}/slurm-reports/period=${PERIOD}/year=${YEAR}/month=${MONTH}/day=${DAY}"

for file in $OUTPUT_DIR/*_${PERIOD}_${REPORT_DATE}.csv; do
    [ -f "$file" ] && aws s3 cp "$file" "${S3_PREFIX}/$(basename $file)"
done

# QuickSight manifest
cat > $OUTPUT_DIR/manifest_${PERIOD}.json <<EOF
{
  "fileLocations": [{"URIPrefixes": ["${S3_PREFIX}/"]}],
  "globalUploadSettings": {"format": "CSV", "delimiter": "|", "containsHeader": "false"}
}
EOF
aws s3 cp $OUTPUT_DIR/manifest_${PERIOD}.json "${S3_PREFIX}/manifest.json"

echo "Uploaded to $S3_PREFIX"
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
aws s3 ls s3://<your-gpu-accounting-bucket>/slurm-reports/ --recursive

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
