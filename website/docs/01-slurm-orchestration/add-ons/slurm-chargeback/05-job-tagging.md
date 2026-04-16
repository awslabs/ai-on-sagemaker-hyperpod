---
title: Job Tagging Strategy
sidebar_position: 5
---

# Job Tagging Strategy (Project-ID)

While Slurm accounts track **which team** uses GPUs, job tagging tracks **which project or model version** consumes capacity. This enables cost allocation per model version beyond team-level tracking.

## How It Works

The `--comment` field in `sbatch` stores free-text metadata with each job. We use a structured format to embed the project identifier:

```bash
sbatch --account=team-a-research \
       --comment="project-id:model-v2.1-pretrain" \
       --gres=gpu:8 \
       train.sh
```

The `project-id` is later extracted from Slurm's accounting database using `sacct` and parsed in Athena for cost attribution.

## Project-ID Naming Convention

Recommended format: `<product>-<version>-<stage>`

| Team | Example Project-IDs |
|------|---------------------|
| Research | `speech-model-v1.0`, `nlp-bert-v2.0` |
| Pretraining | `llm-v2.1-pretrain`, `llm-v3.0-base` |
| Post-training | `llm-v2.1-sft`, `llm-v2.1-rlhf` |
| Evaluation | `llm-v2.1-eval`, `benchmark-2026q1` |
| Data Pipelines | `pipeline-silver-v1.0`, `dataset-clean-v2` |

:::tip Consistency Matters
The `--comment` field is free-text — Slurm doesn't validate it. Consistent naming is critical for accurate downstream reporting. Use the wrapper script below to enforce it.
:::

## Job Submission Examples

```bash
# Standard submission
sbatch --account=team-b-pretraining \
       --comment="project-id:llm-v2.1-pretrain" \
       --gres=gpu:8 --time=72:00:00 \
       train.sh

# With QoS
sbatch --account=team-a-research \
       --qos=high \
       --comment="project-id:speech-model-v1.0" \
       --gres=gpu:4 --time=24:00:00 \
       train_speech.sh
```

## Submission Wrapper Script

Create `/fsx/ubuntu/slurmAccounting/scripts/submit_job.sh` to enforce account and project-id:

```bash
#!/bin/bash
set -e

usage() {
    echo "Usage: $0 -a <account> -p <project-id> [-q <qos>] [sbatch options] <script>"
    exit 1
}

ACCOUNT=""
PROJECT_ID=""
QOS=""
SBATCH_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--account) ACCOUNT="$2"; shift 2 ;;
        -p|--project-id) PROJECT_ID="$2"; shift 2 ;;
        -q|--qos) QOS="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) SBATCH_ARGS+=("$1"); shift ;;
    esac
done

[ -z "$ACCOUNT" ] && echo "ERROR: --account is required" && usage
[ -z "$PROJECT_ID" ] && echo "ERROR: --project-id is required" && usage

COMMENT="project-id:${PROJECT_ID},submitted:$(date -u +%Y-%m-%dT%H:%M:%SZ)"
QOS_ARG=""
[ -n "$QOS" ] && QOS_ARG="--qos=$QOS"

sbatch --account="$ACCOUNT" --comment="$COMMENT" $QOS_ARG "${SBATCH_ARGS[@]}"
```

Make it available system-wide:

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/submit_job.sh
ln -s /fsx/ubuntu/slurmAccounting/scripts/submit_job.sh /usr/local/bin/submit_job
```

Usage:

```bash
submit_job -a team-b-pretraining -p llm-v2.1-pretrain --gres=gpu:8 train.sh
submit_job -a team-a-research -p speech-v1.0 -q high --gres=gpu:4 train_speech.sh
```

## Verify Tags Are Stored

```bash
# After job starts
scontrol show job <jobid> | grep Comment

# After job completes
sacct -j <jobid> --format=JobID,Account,Comment
```

## Query by Project-ID

Since `sacct` doesn't have a native `--comment` filter, use grep:

```bash
sacct -a -X -n -P --format=JobID,User,Account,Elapsed,Comment | \
    grep "project-id:llm-v2.1"
```

:::note Native vs Wrapper
Users can always use `sbatch --comment="project-id:..."` directly — the wrapper is optional convenience that enforces the convention. See [Cost Allocation from CUR](./08-cost-allocation-from-cur.md) for how project-IDs are used in cost queries.
:::
