---
title: Training Operator Observability
sidebar_position: 4
---

# HyperPod Training Operator Observability

:::info Informational Only
This section is informational and not hands-on. Due to Workshop Studio limitations on Identity Center, we cannot access the Grafana dashboard directly. This section shows what it would look like in production.
:::

With the **one-click observability add-on**, you get a dedicated **Training** dashboard that shows training-application-specific metrics:

- Auto Restart Count
- Training Task Resiliency
- Process-level recovery metrics
- Job health status

## Observability with Managed Prometheus & Grafana

1. Open your Grafana workspace
2. Select **Dashboards**
3. Select the **Training** dashboard

From here, you'll have insights into resiliency metrics at the process level of your jobs — including restart counts, recovery times, and overall job health.
