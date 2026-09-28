---
title: Sync LDAP Users to Slurm Accounting (Optional)
sidebar_position: 4
---

# Sync LDAP Users to Slurm Accounting

:::info Optional
This page is optional. If you manage users manually or via CSV import (see [Account Hierarchy](./02-account-hierarchy.md)), skip this section.
:::

:::warning Prerequisite: SSSD Configuration
This guide assumes your HyperPod Slurm cluster is already configured with **SSSD (System Security Services Daemon)** for LDAP authentication via lifecycle scripts. SSSD handles user authentication and group resolution — this page only covers syncing those SSSD-resolved users into **Slurm accounting** for chargeback tracking.

If SSSD is not configured, see the [SageMaker HyperPod documentation on SSSD/Active Directory integration](https://docs.aws.amazon.com/sagemaker/latest/dg/smcluster-getting-started-slurm.html) first.
:::

## Why This Is Needed

SSSD handles **authentication** — users can log in and submit jobs. But Slurm accounting requires **explicit `sacctmgr` entries** to track usage by team. Without them:

| With SSSD Only | With SSSD + Slurm Accounting |
|----------------|------------------------------|
| ✅ Users can log in (SSH) | ✅ Users can log in |
| ✅ Users can submit jobs (`sbatch`) | ✅ Users can submit jobs |
| ❌ Jobs tracked as "unknown" account | ✅ Jobs tracked by team account |
| ❌ No fair-share enforcement | ✅ Fair-share works |
| ❌ No QoS access control | ✅ QoS limits enforced |
| ❌ No chargeback | ✅ Full chargeback |

:::note HyperPod Lifecycle Scripts
The lifecycle script `setup_user_associations.sh` automatically creates a flat `root` account and adds the `ubuntu` user (plus any users in `shared_users.txt`) to it. However, it does **not** create team-based account associations needed for chargeback. The sync scripts below (Option 1 or Option 2) are required to map SSSD-resolved users to your organization's team accounts.
:::

## How It Works

```
┌─────────────┐     ┌──────────┐     ┌───────────────┐     ┌─────────────────┐
│    LDAP     │────▶│   SSSD   │────▶│  Linux (NSS)  │────▶│ Slurm Accounting│
│  (directory)│     │ (cached) │     │ getent group   │     │  sacctmgr       │
└─────────────┘     └──────────┘     └───────────────┘     └─────────────────┘
```

Since SSSD caches LDAP groups locally, we use `getent group <name>` to resolve group members — no direct LDAP queries (`ldapsearch`) are needed.

## Verify SSSD Is Working

Before proceeding, confirm SSSD resolves your users and groups:

```bash
# Check SSSD service
sudo systemctl status sssd

# Resolve a user
id alice

# List members of an LDAP group
getent group team-a-research
```

If `getent group` returns members, SSSD is working and you can proceed.

## Option 1: One-Time Sync

Best for initial setup or periodic manual sync.

Create `/fsx/ubuntu/slurmAccounting/scripts/sync_sssd_to_slurm.sh`:

```bash
#!/bin/bash
# sync_sssd_to_slurm.sh
# Sync SSSD-resolved LDAP groups to Slurm accounting entries
# Prerequisite: SSSD configured via HyperPod lifecycle scripts

set -e

# Map LDAP/SSSD group names to Slurm account names
# Modify this to match your organization's groups and accounts
declare -A GROUP_MAPPING=(
    ["team-a-research"]="team-a-research"
    ["team-a-training"]="team-a-training"
    ["team-b-pretraining"]="team-b-pretraining"
    ["team-b-posttraining"]="team-b-posttraining"
    ["team-c-pipelines"]="team-c-pipelines"
    ["platform-shared"]="platform-shared"
)

ADDED=0
SKIPPED=0

for group in "${!GROUP_MAPPING[@]}"; do
    account="${GROUP_MAPPING[$group]}"
    # getent resolves via SSSD — no ldapsearch needed
    MEMBERS=$(getent group "$group" 2>/dev/null | cut -d: -f4 | tr ',' '\n')

    if [ -z "$MEMBERS" ]; then
        echo "⚠ Group '$group' not found or empty (check SSSD config)"
        continue
    fi

    for user in $MEMBERS; do
        if sacctmgr -i add user "$user" Account="$account" DefaultAccount="$account" 2>/dev/null; then
            echo "✓ $user → $account"
            ((ADDED++))
        else
            echo "  $user already exists in $account"
            ((SKIPPED++))
        fi
    done
done

echo ""
echo "Sync complete: $ADDED added, $SKIPPED skipped"
sacctmgr show user -s | head -30
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/sync_sssd_to_slurm.sh
./fsx/ubuntu/slurmAccounting/scripts/sync_sssd_to_slurm.sh
```

## Option 2: Automatic Scheduled Sync

For teams with frequent onboarding/offboarding.

Create `/fsx/ubuntu/slurmAccounting/scripts/auto_sync_sssd_slurm.sh`:

```bash
#!/bin/bash
# auto_sync_sssd_slurm.sh
# Automatically sync SSSD groups to Slurm accounting on a schedule
# Prerequisite: SSSD configured via HyperPod lifecycle scripts

set -e

LOG_FILE="/var/log/slurm/sssd_slurm_sync.log"
REMOVE_ORPHANS="false"  # Set "true" to remove users no longer in LDAP groups

declare -A GROUP_MAPPING=(
    ["team-a-research"]="team-a-research"
    ["team-a-training"]="team-a-training"
    ["team-b-pretraining"]="team-b-pretraining"
    ["team-b-posttraining"]="team-b-posttraining"
    ["team-c-pipelines"]="team-c-pipelines"
    ["platform-shared"]="platform-shared"
)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE; }

log "=== Starting SSSD→Slurm Sync ==="

SLURM_USERS=$(sacctmgr -n -P show user format=User | sort -u)
ALL_SSSD_USERS=""

for group in "${!GROUP_MAPPING[@]}"; do
    account="${GROUP_MAPPING[$group]}"
    MEMBERS=$(getent group "$group" 2>/dev/null | cut -d: -f4 | tr ',' '\n')

    [ -z "$MEMBERS" ] && log "  ⚠ Group '$group' empty or not found" && continue

    for user in $MEMBERS; do
        ALL_SSSD_USERS="$ALL_SSSD_USERS $user"
        if echo "$SLURM_USERS" | grep -qw "$user"; then
            USER_ACCOUNTS=$(sacctmgr -n -P show assoc where user=$user format=Account)
            if ! echo "$USER_ACCOUNTS" | grep -qw "$account"; then
                log "  Adding $user to $account"
                sacctmgr -i add user $user Account=$account 2>/dev/null || true
            fi
        else
            log "  NEW: $user → $account"
            sacctmgr -i add user $user Account=$account DefaultAccount=$account 2>/dev/null || true
        fi
    done
done

if [ "$REMOVE_ORPHANS" = "true" ]; then
    UNIQUE_SSSD=$(echo $ALL_SSSD_USERS | tr ' ' '\n' | sort -u)
    for slurm_user in $SLURM_USERS; do
        [[ "$slurm_user" == "root" ]] && continue
        if ! echo "$UNIQUE_SSSD" | grep -qw "$slurm_user"; then
            log "  ORPHAN: Removing $slurm_user"
            sacctmgr -i delete user $slurm_user 2>/dev/null || true
        fi
    done
fi

log "=== Sync Complete ($(echo $ALL_SSSD_USERS | wc -w) users processed) ==="
```

### Schedule with Cron

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/auto_sync_sssd_slurm.sh

sudo crontab -e
# Daily at 6 AM
0 6 * * * /fsx/ubuntu/slurmAccounting/scripts/auto_sync_sssd_slurm.sh >> /var/log/slurm/sssd_slurm_sync.log 2>&1
```

## Which Option?

| Feature | One-Time Sync | Automatic Sync |
|---------|---------------|----------------|
| Setup effort | Low | Low |
| Maintenance | Manual re-run | Automatic |
| Best for | Initial setup, stable teams | Dynamic teams |
| Orphan removal | Manual | Optional auto |

## Modify Sync Configuration

```bash
# Add a new group mapping — edit the GROUP_MAPPING in the script:
["new-group"]="new-slurm-account"

# Enable orphan removal — edit auto_sync_sssd_slurm.sh:
REMOVE_ORPHANS="true"

# Change sync schedule — edit crontab:
# Every 6 hours: 0 */6 * * *
# Every hour: 0 * * * *

# Force SSSD cache refresh before sync
sudo sss_cache -E
./fsx/ubuntu/slurmAccounting/scripts/sync_sssd_to_slurm.sh
```

## Troubleshooting

```bash
# Check SSSD status
sudo systemctl status sssd

# Force SSSD cache refresh
sudo sss_cache -E

# Verify group resolution via SSSD
getent group team-a-research

# Verify user resolution via SSSD
id alice

# Check Slurm user entry
sacctmgr show user alice -s
sacctmgr show assoc where user=alice format=User,Account,DefaultAccount

# View sync logs
tail -f /var/log/slurm/sssd_slurm_sync.log

# If getent returns empty but user exists in LDAP:
# Check SSSD config
sudo cat /etc/sssd/sssd.conf
# Restart SSSD
sudo systemctl restart sssd
```
