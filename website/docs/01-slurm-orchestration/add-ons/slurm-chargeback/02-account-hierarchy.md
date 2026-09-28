---
title: Account Hierarchy Setup
sidebar_position: 2
---

# Account Hierarchy Setup

Slurm's accounting system tracks GPU usage by **account** — a hierarchical label that maps to your organization structure. Every user belongs to one or more accounts, and every job is charged to an account.

## Example Organization Structure

Adapt this to match your own teams and sub-teams:

```
org-root (Organization)
├── team-a (Team A)
│   ├── team-a-research      (Research sub-team)
│   ├── team-a-training      (Training sub-team)
│   └── team-a-evaluation    (Evaluation sub-team)
│
├── team-b (Team B)
│   ├── team-b-pretraining   (Pretraining sub-team)
│   └── team-b-posttraining  (Post-training sub-team)
│
├── team-c (Team C)
│   └── team-c-pipelines     (Data pipelines)
│
└── platform (Platform/Shared Services)
    └── platform-shared      (Shared infrastructure)
```

## Create the Account Hierarchy

Create script `/fsx/ubuntu/slurmAccounting/scripts/setup_accounts.sh`:

```bash
#!/bin/bash
set -e

# Top-level organization
sacctmgr -i add account org-root \
    Description="Organization Root" \
    Organization="MyOrg"

# Team A
sacctmgr -i add account team-a \
    Description="Team A" Organization="MyOrg" Parent=org-root
sacctmgr -i add account team-a-research \
    Description="Team A Research" Organization="MyOrg" Parent=team-a
sacctmgr -i add account team-a-training \
    Description="Team A Training" Organization="MyOrg" Parent=team-a
sacctmgr -i add account team-a-evaluation \
    Description="Team A Evaluation" Organization="MyOrg" Parent=team-a

# Team B
sacctmgr -i add account team-b \
    Description="Team B" Organization="MyOrg" Parent=org-root
sacctmgr -i add account team-b-pretraining \
    Description="Team B Pretraining" Organization="MyOrg" Parent=team-b
sacctmgr -i add account team-b-posttraining \
    Description="Team B Post-training" Organization="MyOrg" Parent=team-b

# Team C
sacctmgr -i add account team-c \
    Description="Team C" Organization="MyOrg" Parent=org-root
sacctmgr -i add account team-c-pipelines \
    Description="Team C Data Pipelines" Organization="MyOrg" Parent=team-c

# Platform
sacctmgr -i add account platform \
    Description="Platform Team" Organization="MyOrg" Parent=org-root
sacctmgr -i add account platform-shared \
    Description="Shared Services" Organization="MyOrg" Parent=platform

# Verify
sacctmgr show account WithAssoc Tree format=Account,Description,Organization
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/setup_accounts.sh
./fsx/ubuntu/slurmAccounting/scripts/setup_accounts.sh
```

## Add Users to Accounts

:::info 
If you are using LDAP, skip this section and look at the [Sync LDAP page](./04-ldap-integration.md)
:::

### Option 1 - manually
```bash
# Add user to a single account
sacctmgr add user alice Account=team-a-research DefaultAccount=team-a-research

# Add user with access to multiple accounts
sacctmgr add user bob Account=team-a-research,team-b-pretraining DefaultAccount=team-a-research

# Verify
sacctmgr show user -s
```

### Option 2 - Bulk User Import

Create `/fsx/ubuntu/slurmAccounting/scripts/import_users.sh`:

```bash
#!/bin/bash
CSV_FILE="${1:-users.csv}"
[ ! -f "$CSV_FILE" ] && echo "Usage: $0 <users.csv>" && exit 1

while IFS=',' read -r username account; do
    [[ "$username" == "username" ]] && continue
    if sacctmgr -i add user "$username" Account="$account" DefaultAccount="$account" 2>/dev/null; then
        echo "✓ Added $username → $account"
    else
        echo "⚠ $username may already exist"
    fi
done < "$CSV_FILE"
```

CSV format (`users.csv`):
```csv
username,account
alice,team-a-research
bob,team-b-pretraining
carol,team-c-pipelines
```

```bash
chmod +x /fsx/ubuntu/slurmAccounting/scripts/import_users.sh
/fsx/ubuntu/slurmAccounting/scripts/import_users.sh users.csv
```

## Modify Accounts after creation

```bash
# Add a new account
sacctmgr -i add account new-team Description="New Team" Parent=org-root

# Delete an account
sacctmgr -i delete account old-team

# Change a user's default account
sacctmgr -i modify user alice set DefaultAccount=team-a-training

# Remove user from an account
sacctmgr -i delete user alice Account=team-a-research
```

:::tip Enforce Account Usage
To enforce and require users to specify `--account` when submitting jobs, add this to `/opt/slurm/etc/slurm.conf`:
```ini
AccountingStorageEnforce=associations
```
Then run `scontrol reconfigure`. Once set, jobs without a valid account will be rejected.

**Note:** This value is cumulative. If you later configure QoS and resource limits (in the [QoS page](./03-qos-priority-preemption.md)), you'll update this line to `associations,qos,limits` — each value supersedes the previous. You only need to run `scontrol reconfigure` once with the final value.
:::

:::info
We will optionally be setting fair-share, QoS, priority and preemption in the next section. 
:::

