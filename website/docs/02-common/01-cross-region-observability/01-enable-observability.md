---
title: 1. Enable Observability (Region B)
sidebar_position: 1
---

# Part 1 — Enable HyperPod-integrated observability

HyperPod observability is a managed EKS add-on
(`amazon-sagemaker-hyperpod-observability`). Enabling it provisions the **AMP
workspace**, deploys the collectors and exporters (node, kube-state, cadvisor,
plus DCGM/EFA on GPU nodes and the health-monitoring agent), and wires
`remote_write` — with **no Helm, no `kubectl`, and no Pod Identity role to
create**. This replaces the older manual setup entirely.

Assumes the environment variables from
[Overview & Prerequisites](./index.md) are set in your shell.

## Step 1 — Confirm the add-on exists in your Region

```bash
aws eks describe-addon-versions --region "$REGION_B" \
  --addon-name amazon-sagemaker-hyperpod-observability \
  --query 'addons[].addonVersions[0].addonVersion' --output text
```

- A version string (e.g. `v1.0.9-eksbuild.1`) → supported here; continue.
- Empty output / `[]` → **not rolled out to this Region yet**. Fall back to a
  manual AMP + Prometheus-agent setup (create an AMP workspace, deploy
  node-exporter / kube-state-metrics and a Prometheus agent in `--enable-feature=agent`
  mode with SigV4 `remote_write`), then resume at
  [Deploy Cross-Region](./02-deploy-cross-region.md).

> **Why this check matters:** in Regions where the add-on is absent, the
> HyperPod console "enable observability" action is **silently ignored** — no
> error, nothing created. Always verify with the CLI first.

## Step 2 — Enable observability on the cluster

**Console (recommended).** SageMaker AI console (Region B) → **HyperPod
Clusters → Cluster management →** your cluster → **Dashboard → Amazon SageMaker
HyperPod observability → Custom install**. This one action creates the AMP
workspace, installs the EKS add-on, and configures metric collection. Wait for
the add-on to reach `ACTIVE` (about five minutes):

```bash
aws eks describe-addon --region "$REGION_B" --cluster-name "$EKS_CLUSTER" \
  --addon-name amazon-sagemaker-hyperpod-observability \
  --query 'addon.status' --output text
```

**CLI alternative** (if you manage add-ons yourself; requires the
observability IAM role and AMP workspace to be pre-created per the HyperPod
docs):

```bash
aws eks create-addon --region "$REGION_B" --cluster-name "$EKS_CLUSTER" \
  --addon-name amazon-sagemaker-hyperpod-observability
```

## Step 3 — Capture the AMP workspace it created

The add-on generates a workspace with a name like
`hyperpod-prometheus-workspace-<timestamp>`. Capture its ID — Part 2 needs it:

```bash
export WS_ID=$(aws amp list-workspaces --region "$REGION_B" \
  --query 'workspaces[?status.statusCode==`ACTIVE`]|[0].workspaceId' --output text)
echo "WS_ID=$WS_ID"

# if more than one workspace exists, pick by alias instead:
aws amp list-workspaces --region "$REGION_B" \
  --query 'workspaces[].{Id:workspaceId,Alias:alias}' --output table
```

## Step 4 — Verify ingestion

```bash
pip install awscurl   # one-time
awscurl --service aps --region "$REGION_B" \
  "https://aps-workspaces.${REGION_B}.amazonaws.com/workspaces/${WS_ID}/api/v1/query?query=up"
```

Expect `"status":"success"` with a list of targets whose value is `"1"` — node
exporters, kube-state-metrics, cadvisor, the health-monitoring agent, and
(on GPU nodes) DCGM/EFA all report within a couple of minutes. An idle cluster
with zero running jobs still reports these; a missing *job* only leaves
job-specific panels empty, it does not make `up` return nothing.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `aps:QueryMetrics` AccessDenied | Grant your principal the four `aps:*` query actions (`QueryMetrics`, `GetLabels`, `GetSeries`, `GetMetricMetadata`). Scope to `workspace/*`, not a specific ARN — see next row. IAM changes can take 1–2 minutes to propagate |
| AccessDenied against the **new** workspace after re-enabling observability | Each enable generates a **fresh** workspace ID; an IAM grant pinned to the old workspace ARN goes stale. Scope query grants to `arn:aws:aps:<region>:<account>:workspace/*` |
| awscurl fails with a SigV4 signature mismatch | awscurl mangles PromQL containing spaces or parentheses. Keep verification queries simple (`up`); run richer queries from Grafana later |
| Add-on stuck `CREATE_FAILED` with a kueue webhook error | The cluster has **zero schedulable nodes** (e.g. the instance type is unavailable in the Region), so the observability pods cannot start and kueue's fail-closed webhook then blocks Deployments. Fix node provisioning, then delete and recreate the add-on |
| DCGM/EFA panels empty | Expected on CPU-only clusters — those exporters only produce data on GPU/EFA hardware. They light up automatically when a GPU cluster reports, with no further changes |

With `WS_ID` captured and `up` returning targets, continue to
[Deploy Cross-Region](./02-deploy-cross-region.md).
