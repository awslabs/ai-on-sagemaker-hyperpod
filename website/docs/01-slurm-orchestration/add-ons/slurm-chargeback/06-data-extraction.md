---
title: Data Extraction
sidebar_position: 6
---

# Data Extraction with sreport and sacct

Slurm provides two tools for extracting GPU usage data: `sreport` for aggregated summaries and `sacct` for job-level detail. Together they produce the reports needed for chargeback.

## Report Types

| Report | Tool | Metric | Use Case |
|--------|------|--------|----------|
| Account Utilization | `sreport` | GPU Hours | Chargeback billing |
| Top Users | `sreport` | GPU Hours | Usage tracking |
| Job Sizes | `sreport` | GPU Hours | Distribution analysis |
| Cluster Utilization | `sreport` | GPU Hours | Capacity planning |
| Jobs Detailed | `sacct` | Both | Project-ID tracking |
| GPU Count per Job | `sacct` | GPU Count | Job size analysis |
| GPU Count Summary | `sacct` + `gawk` | GPU Count | Team capacity analysis |

:::info GPU Hours vs GPU Count
- **GPU Hours** = GPUs × Duration (e.g., 4 GPUs × 10 hours = 40 GPU-Hours) — used for billing
- **GPU Count** = Raw number of GPUs per job, regardless of duration — used for capacity analysis
:::

## Basic Reports

```bash
# Cluster-wide GPU utilization
sreport cluster utilization Start=2026-01-01 End=2026-01-31 \
    -t Hours -T gres/gpu format=Cluster,Allocated,Down,Idle

# GPU hours by team with user breakdown
sreport cluster AccountUtilizationByUser Start=2026-01-01 End=2026-01-31 \
    -t Hours -T gres/gpu format=Account,Login,Used

# Top 50 GPU consumers
sreport user TopUsage TopCount=50 Start=2026-01-01 End=2026-01-31 \
    -t Hours -T gres/gpu format=Account,Login,Used
```

## Automated Report Generation Script

Create `/fsx/ubuntu/slurmAccounting/scripts/generate_gpu_reports.sh`:

```bash
#!/bin/bash
set -e

REPORT_DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="/fsx/ubuntu/slurmAccounting/reports"
PERIOD="${1:-monthly}"

case $PERIOD in
    weekly)  START_DATE=$(date -d "7 days ago" +%Y-%m-%d) ;;
    monthly) START_DATE=$(date -d "1 month ago" +%Y-%m-%d) ;;
    yearly)  START_DATE=$(date -d "1 year ago" +%Y-%m-%d) ;;
    *) echo "Usage: $0 [weekly|monthly|yearly]"; exit 1 ;;
esac
END_DATE=$(date +%Y-%m-%d)

mkdir -p $OUTPUT_DIR

# Report 1: Account Utilization by User
sreport cluster AccountUtilizationByUser \
    Start=$START_DATE End=$END_DATE \
    -t Hours -T gres/gpu -P -n \
    format=Account,Login,Proper,Used \
    > $OUTPUT_DIR/account_utilization_${PERIOD}_${REPORT_DATE}.csv

# Report 2: Top GPU Users
sreport user TopUsage TopCount=100 \
    Start=$START_DATE End=$END_DATE \
    -t Hours -T gres/gpu -P -n \
    format=Account,Login,Used \
    > $OUTPUT_DIR/top_users_${PERIOD}_${REPORT_DATE}.csv

# Report 3: Job Size Distribution
sreport job SizesByAccount \
    Start=$START_DATE End=$END_DATE \
    -T gres/gpu -P -n \
    > $OUTPUT_DIR/job_sizes_${PERIOD}_${REPORT_DATE}.csv

# Report 4: Cluster Utilization
sreport cluster utilization \
    Start=$START_DATE End=$END_DATE \
    -t Hours -T gres/gpu -P -n \
    format=Cluster,Allocated,Down,Idle,Reserved \
    > $OUTPUT_DIR/cluster_utilization_${PERIOD}_${REPORT_DATE}.csv

# Report 5: Detailed Job Data with Project-ID
sacct -a -X -n -P \
    --starttime=$START_DATE --endtime=$END_DATE \
    --state=COMPLETED,FAILED,CANCELLED,TIMEOUT \
    --format=JobID,JobName,User,Account,Partition,State,Elapsed,AllocTRES,Comment \
    > $OUTPUT_DIR/jobs_detailed_${PERIOD}_${REPORT_DATE}.csv

# Report 6: GPU Count per Job
sacct -a -X -n -P \
    --starttime=$START_DATE --endtime=$END_DATE \
    --state=COMPLETED,FAILED,CANCELLED,TIMEOUT \
    --format=JobID,JobName,User,Account,AllocGRES,Elapsed,State,Start,End \
    > $OUTPUT_DIR/gpu_count_per_job_${PERIOD}_${REPORT_DATE}.csv

# Report 7: GPU Count Summary by Team
sacct -a -X -n -P \
    --starttime=$START_DATE --endtime=$END_DATE \
    --state=COMPLETED,FAILED,CANCELLED,TIMEOUT \
    --format=Account,User,AllocGRES,Elapsed | \
    gawk -F'|' '
    BEGIN { print "Account|User|TotalJobs|TotalGPUsAllocated|AvgGPUsPerJob|MaxGPUs" }
    {
        account=$1; user=$2; gres=$3; gpu_count=0
        if (match(gres, /gpu[=:]([0-9]+)/, arr)) gpu_count=arr[1]
        key=account"|"user; jobs[key]++; gpus[key]+=gpu_count
        if (gpu_count > max_gpus[key]) max_gpus[key]=gpu_count
    }
    END {
        for (key in jobs) {
            avg = (jobs[key] > 0) ? gpus[key]/jobs[key] : 0
            printf "%s|%d|%d|%.1f|%d\n", key, jobs[key], gpus[key], avg, max_gpus[key]
        }
    }' | sort -t'|' -k3 -rn \
    > $OUTPUT_DIR/gpu_count_summary_${PERIOD}_${REPORT_DATE}.csv

echo "Reports generated in $OUTPUT_DIR"
ls -la $OUTPUT_DIR/*_${PERIOD}_${REPORT_DATE}.csv
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/generate_gpu_reports.sh
```

## Key Flags Explained

| Flag | Tool | Meaning |
|------|------|---------|
| `-t Hours` | sreport | Output time in hours |
| `-T gres/gpu` | sreport | Track GPU TRES |
| `-P` | both | Parseable output (pipe-delimited) |
| `-n` | both | No header row |
| `-a` | sacct | All users (admin view) |
| `-X` | sacct | Job allocations only (no steps) |
| `--state=COMPLETED,...` | sacct | Filter by job state |

## Output Files

Each run produces 7 CSV files:

| File | Content | Key Columns |
|------|---------|-------------|
| `account_utilization_*.csv` | GPU hours per user per team | Account, Login, Used |
| `top_users_*.csv` | Ranked GPU consumers | Account, Login, Used |
| `job_sizes_*.csv` | Job size distribution | Account, size buckets |
| `cluster_utilization_*.csv` | Cluster-wide GPU stats | Allocated, Down, Idle |
| `jobs_detailed_*.csv` | All jobs with project-ID | Account, Elapsed, Comment |
| `gpu_count_per_job_*.csv` | Raw GPUs per job | AllocGRES, Start, End |
| `gpu_count_summary_*.csv` | Aggregated GPU count by team | TotalJobs, AvgGPUs |

:::note
All CSVs use pipe (`|`) as the delimiter, not comma. This avoids conflicts with values that may contain commas.
:::
