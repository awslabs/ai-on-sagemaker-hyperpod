---
title: Setup OS Grafana
sidebar_position: 2
---

# Setup OS Grafana

## 1. Get the Grafana Instance Address

Navigate to the [AWS CloudFormation Console](https://us-west-2.console.aws.amazon.com/cloudformation/home?region=us-west-2#/getting-started) and fetch the **GrafanaInstanceAddress** output from the `os-observability` stack.

Open the Grafana link in your browser. The default credentials are `admin/admin`. Please change the password after the first login.

## 2. Set Prometheus Workspace as Data Source

Connect the Prometheus workspace with the Grafana dashboard by setting it as a data source.

1. Navigate to **"Data Sources"** in Grafana and select **"Prometheus"**.

2. Set the **"Prometheus server URL"** with the value retrieved from the AWS console.

:::caution Important
Don't forget to remove the `/api/v1/query` part of the URL. The correct URL format is:
`https://aps-workspaces.us-west-2.amazonaws.com/workspaces/ws-123456-1234-1234-1234/`
:::

3. For authentication:
   - Choose **"SigV4"**
   - Set **"Authentication Provider"** to **"AWS SDK Default"**
   - Set **"Default Region"** to `us-west-2`

4. Click **"Save & Test"** to verify the connection.

Once the datasource configuration test has passed, you can advance to building dashboards.
