---
title: Build Grafana Dashboards
sidebar_position: 3
---

# Build Grafana Dashboards

With authentication and data sources setup, within your Grafana workspace, select **Dashboards > New > Import**.

To display metrics for the exporter services, import the following open source Grafana Dashboards by copying and pasting the URLs below:

## Slurm Exporter Dashboard

```
https://grafana.com/grafana/dashboards/4323-slurm-dashboard/
```

## Node Exporter Dashboard

```
https://grafana.com/grafana/dashboards/1860-node-exporter-full/
```

## DCGM Exporter Dashboard

```
https://grafana.com/grafana/dashboards/12239-nvidia-dcgm-exporter-dashboard/
```

## FSx for Lustre Dashboard

For the Amazon FSx for Lustre dashboard, you need to create an additional data source for Amazon CloudWatch.

```
https://grafana.com/grafana/dashboards/20906-fsx/
```

---

🎉 **Congratulations!** You can now view real-time metrics about your SageMaker HyperPod Cluster and compute nodes in Grafana!
