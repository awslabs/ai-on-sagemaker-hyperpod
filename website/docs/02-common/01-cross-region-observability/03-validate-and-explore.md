---
title: 3. Validate & Explore
sidebar_position: 3
---

# Part 3 — Validate the path and view metrics

## Automated validation (recommended)

The CDK folder ships a script that verifies the whole chain from outside,
without a UI login. It uses a short-lived (10-minute) Grafana service-account
token that it cleans up afterward.

```bash
./validate.sh "$REGION_A" "$REGION_B" "$WS_ID"
```

It checks, in order:

- all three CloudFormation stacks are `CREATE_COMPLETE`
- the TGW peering attachment is `available` **and associated with both** route
  tables
- the Prometheus data source exists in Grafana
- the data-source health check returns `OK` (the API equivalent of the console
  "Save & Test")
- a live `count(up)` query returns at least one target through the
  cross-region path

A clean run ends with `ALL CHECKS PASSED — end-to-end path verified.`

## Log in to Grafana

Open `https://<WorkspaceEndpoint>` (from the end of
[Part 2](./02-deploy-cross-region.md)) and sign in with IAM Identity Center.
You land as **Admin** — the CDK granted your user that role at the AMG level,
so it persists across logout/login.

> If Explore or the Apps menu is missing, your Grafana role is Viewer, not
> Admin. Re-run `GrafanaConfigStack` (its custom resource re-asserts the ADMIN
> grant), or set the role in the AMG console's Authentication tab with the
> "Make admin" action.

## Explore the data

Left menu → **Explore** (compass icon). Confirm the data source picker shows
the AMP data source, switch the query editor to **Code**, and run:

```promql
up
```

You should see roughly a dozen targets carrying HyperPod labels such as
`sagemaker_amazonaws_com_cluster_name`. A few useful queries:

```promql
# CPU utilization per node
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))

# a specific training job's pods (adjust the pod name pattern)
sum by (pod) (rate(container_cpu_usage_seconds_total{pod=~"my-job.*"}[2m]))

# pod lifecycle from kube-state-metrics
kube_pod_status_phase{phase=~"Running|Succeeded"}
```

> Seeing empty graphs even though data exists? Widen the time-range picker
> (top-right) — short jobs are only a few scrape intervals wide; try Last 6–24 h.

## Dashboards

`GrafanaConfigStack` pre-imports two dashboards, already wired to the AMP data
source — see **Dashboards** in the left menu:

- **1860** — Node Exporter Full (per-node CPU / memory / disk / network)
- **15757** — Kubernetes / Views / Global

### Adding more dashboards

Do **not** use "Import via grafana.com" and the ID field: the Grafana *server*
performs that fetch, and its egress goes through the no-internet outbound VPC,
so the request hangs silently. Instead:

1. In your own browser, download the dashboard JSON, e.g.
   `https://grafana.com/api/dashboards/12239/revisions/latest/download`
   (12239 is NVIDIA DCGM, for GPU clusters).
2. In Grafana: **Dashboards → New → Import → Import via dashboard JSON model**,
   paste the JSON, and select the AMP data source when prompted.

When you are satisfied, review [Costs & Teardown](./04-costs-and-teardown.md).
