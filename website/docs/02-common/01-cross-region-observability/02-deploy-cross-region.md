---
title: 2. Deploy Cross-Region Connectivity
sidebar_position: 2
---

# Part 2 — Cross-region connectivity + Grafana (CDK)

This deploys the private network path (VPCs, Transit Gateways, peering,
PrivateLink endpoints, Route 53 hosted zones), the Amazon Managed Grafana
workspace, and the Prometheus data source that queries your AMP workspace
across Regions. Roughly 40 minutes, most of it unattended.

Assumes the environment variables from
[Overview & Prerequisites](./index.md) are set, and `WS_ID` from
[Part 1](./01-enable-observability.md).

## Step 1 — Get the CDK app

Fetch just the CDK folder — no need to clone the repository:

```bash
curl -L https://github.com/awslabs/ai-on-sagemaker-hyperpod/archive/refs/heads/main.tar.gz \
  | tar -xz --strip-components=2 ai-on-sagemaker-hyperpod-main/cdk/cross-region-observability
cd cross-region-observability
python3 -m pip install -r requirements.txt
```

> On a restricted workstation, create a virtualenv first:
> `python3 -m venv .venv && source .venv/bin/activate`.

## Step 2 — Bootstrap both Regions (once per account + Region)

```bash
cdk bootstrap "aws://$ACCOUNT/$REGION_A" "aws://$ACCOUNT/$REGION_B"
```

## Step 3 — Deploy

```bash
cdk deploy --all --require-approval never \
  -c regionA="$REGION_A" \
  -c regionB="$REGION_B" \
  -c ampWorkspaceId="$WS_ID" \
  -c grafanaAdminGuid="$ADMIN_GUID"
```

The default VPC CIDRs are `10.10.0.0/16` (Grafana) and `10.20.0.0/16`
(endpoints). If either collides with your existing networks, override:

```bash
  -c grafanaVpcCidr=10.30.0.0/16 -c ampVpcCidr=10.40.0.0/16
```

## What deploys, in order

| Stack | Region | Creates |
|---|---|---|
| `GrafanaNetworkStack` | A | VPC (two AZ private subnets), security group, Transit Gateway A with a dedicated route table, VPC subnet routes, the **AMG workspace** (outbound-VPC connected) and its IAM role with the six `aps:*` read permissions |
| `AmpEndpointStack` | B | Endpoint VPC, the `aps` and `aps-workspaces` interface endpoints (**Private DNS OFF**), Transit Gateway B, the peering attachment, an **accept-and-wait Lambda** (accepts the peering in Region A, blocks until it is `available`, and **associates the peering with both TGW route tables**), static TGW routes on both sides, VPC subnet routes, and two Route 53 private hosted zones (zone-apex alias records) associated cross-Region with the Grafana VPC |
| `GrafanaConfigStack` | A | A Lambda-backed custom resource that grants your user **ADMIN at the AMG level** (survives Identity Center re-sync), re-asserts the workspace `PROMETHEUS`/`CLOUDWATCH` data-source flags, creates the **Prometheus data source** (SigV4 with the workspace IAM role, pointed at AMP in Region B), **polls the data-source health endpoint and fails the deploy unless Grafana can actually query AMP**, and imports dashboards **1860** and **15757** wired to the data source |

Expected timeline: stack 1 about 8 minutes; stack 2 about 15 minutes (it will
appear to pause roughly 5 minutes at `AcceptAndWaitPeering` — that is the
peering attachment becoming `available`, which is normal); stack 3 about
3 minutes.

**A green deploy is the end-to-end proof** — `GrafanaConfigStack` will not
complete unless the health check passes. Its outputs include
`DataSourceHealth = OK` and `ImportedDashboards`.

## Retrieve your Grafana URL

`cdk deploy --all` prints the last stack's outputs, so the workspace endpoint
(an output of the *first* stack) scrolls off screen. Fetch it directly:

```bash
aws cloudformation describe-stacks --region "$REGION_A" \
  --stack-name GrafanaNetworkStack \
  --query "Stacks[0].Outputs[?OutputKey=='WorkspaceEndpoint'].OutputValue" \
  --output text
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Bootstrap `Access denied` on `PutParameter` or `ecr:PutLifecyclePolicy` | Deployer policy gaps — see the prerequisites. If a bootstrap stack is stuck, recover it (`continue-update-rollback` for `UPDATE_ROLLBACK_FAILED`, `delete-stack` for `ROLLBACK_FAILED`) before retrying |
| VPC create fails "maximum number of VPCs has been reached" | The Region is at its VPC quota. Pick a different Region A or request a quota increase |
| Data-source health `dial tcp <ip>:443: i/o timeout` | The peering attachment is not **associated** with the TGW route tables (routes alone are not enough — return traffic consults no table). The accept Lambda handles this; the [validation script](./03-validate-and-explore.md) checks it explicitly |
| `grafana:UpdatePermissions` → "Unable to update users in managed application" | Missing `sso:*Profile*` / `sso-directory:*` permissions on the deployer — see prerequisites |

When the deploy is green, continue to
[Validate & Explore](./03-validate-and-explore.md).
