---
title: 4. Costs & Teardown
sidebar_position: 4
---

# Part 4 — Costs and teardown

## Cost (ballpark, `us-east-2` rates)

Fixed, roughly **$185/month**:

| Component | Approx. monthly |
|---|---|
| 4 × Transit Gateway attachments (2 VPC + 2 peering; **both** peering sides bill) | ~$146 |
| 2 interface endpoints × 2 AZs | ~$29 |
| 2 Route 53 private hosted zones | ~$1 |
| AMG (minimum one editor) | ~$9 |

Variable and typically small for dashboard use: TGW data processing
(~$0.02/GB), PrivateLink (~$0.01/GB), and inter-Region transfer — a few GB of
PromQL a month, so single-digit dollars. **AMP ingestion** (~$0.90 per 10M
samples) dominates at scale, but it exists regardless of the cross-region
setup.

> Cost lever: the four TGW hourly charges are the bulk of the fixed cost. For a
> simple two-VPC test, **inter-Region VPC peering** instead of two Transit
> Gateways removes all of them (VPC peering has no hourly fee); the PrivateLink
> endpoints, hosted zones, and DNS are unchanged. Transit Gateway earns its
> cost when more VPCs or Regions join later.

Everything here bills hourly whether or not queries flow — **tear down when
you are done testing.**

## Teardown

Order matters: **CDK stacks first**, then the observability side.
`GrafanaConfigStack` references the AMP workspace, so destroying AMP first would
strand its custom resource.

### 1. CDK stacks

```bash
cd cross-region-observability
cdk destroy --all --force \
  -c regionA="$REGION_A" -c regionB="$REGION_B" \
  -c ampWorkspaceId="$WS_ID" -c grafanaAdminGuid="$ADMIN_GUID"
```

> Pass the **same** context values used at deploy time — context determines the
> stack set, so a mismatched destroy silently skips stacks.

If a TGW route table reports `DELETE_FAILED` with "tgw-attach-… is in invalid
state", the peering attachment was still tearing down. Wait until it shows
`deleted`, then re-run the destroy — the second attempt succeeds. (The accept
Lambda disassociates on delete to prevent this; the case above only arises for
associations made out of band.)

### 2. Observability side (managed)

Disable observability in the HyperPod console (cluster → observability →
remove), which uninstalls the add-on and its collectors. Or by CLI:

```bash
aws eks delete-addon --region "$REGION_B" --cluster-name "$EKS_CLUSTER" \
  --addon-name amazon-sagemaker-hyperpod-observability
```

The **AMP workspace is not deleted automatically** — your metrics are kept. To
remove it as well (this destroys all stored metrics, with no undo):

```bash
aws amp delete-workspace --region "$REGION_B" --workspace-id "$WS_ID"
```

### 3. Verify nothing keeps billing

Filtered to this solution's own resource names so pre-existing resources in a
shared account do not raise false alarms:

```bash
for r in "$REGION_A" "$REGION_B"; do
  aws ec2 describe-transit-gateways --region "$r" \
    --filters "Name=tag:Name,Values=amg-cross-region-*" "Name=state,Values=available,pending" \
    --query 'TransitGateways[].TransitGatewayId' --output text
done
aws ec2 describe-vpc-endpoints --region "$REGION_B" \
  --filters "Name=service-name,Values=com.amazonaws.$REGION_B.aps,com.amazonaws.$REGION_B.aps-workspaces" \
  --query 'VpcEndpoints[].VpcEndpointId' --output text
aws route53 list-hosted-zones \
  --query "HostedZones[?contains(Name,\`$REGION_B\`)].Name" --output text
aws grafana list-workspaces --region "$REGION_A" --query 'workspaces[].id' --output text
```

Empty output (or only resources you recognize as pre-existing) means the
teardown is clean.
