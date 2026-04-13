---
title: Cloud Integration & Helm Values
sidebar_position: 5
---

# Cloud Integration & Helm Values

This section creates the Kubernetes secret that connects Kubecost to your CUR data via Athena, and prepares the complete Helm values file for deploying Kubecost v2.8.4.

## Create Cloud Integration Secret

```bash
cat > cloud-integration.json <<EOF
{
    "aws": [{
        "athenaBucketName": "s3://${ATHENA_RESULTS_BUCKET}",
        "athenaRegion": "${CUR_REGION}",
        "athenaDatabase": "${ATHENA_DATABASE}",
        "athenaTable": "${ATHENA_TABLE}",
        "athenaWorkgroup": "${ATHENA_WORKGROUP}",
        "projectID": "${AWS_ACCOUNT_ID}",
        "serviceAccountName": "kubecost-serviceaccount",
        "serviceKeyName": ""
    }]
}
EOF

cat cloud-integration.json | jq '.'

kubectl delete secret cloud-integration -n kubecost --ignore-not-found
kubectl create secret generic cloud-integration -n kubecost --from-file=cloud-integration.json
echo "✅ Cloud integration secret created"
```

## Prepare Helm Values

```bash
cat > kubecost-values.yaml <<'VALUESEOF'
# ==========================================================
# Kubecost v2.8.4 for SageMaker HyperPod EKS — Production
# ==========================================================

global:
  clusterId: "CLUSTER_NAME_PLACEHOLDER"

serviceAccount:
  create: false
  name: kubecost-serviceaccount

persistentVolume:
  enabled: true
  size: 32Gi
  storageClass: "gp2"
  dbPVEnabled: true

# --- Cost Analyzer: DB PVC + CSV pricing volume ---
costAnalyzer:
  persistentVolume:
    enabled: true
    size: 32Gi
    storageClass: "gp2"
  dbPVEnabled: true
  extraVolumes:
    - name: kubecost-cost-analyzer-db
      persistentVolumeClaim:
        claimName: kubecost-cost-analyzer-db
    - name: kubecost-csv-pricing
      configMap:
        name: kubecost-custom-pricing
  extraVolumeMounts:
    - name: kubecost-cost-analyzer-db
      mountPath: /var/lib/cost-analyzer-db
    - name: kubecost-csv-pricing
      mountPath: /var/kubecost-csv
      readOnly: true

# --- Aggregator (DuckDB backend) — Enterprise-only feature ---
# Disabled for EKS bundle; enable when you have an Enterprise license
kubecostAggregator:
  enabled: false

prometheus:
  server:
    persistentVolume:
      enabled: true
      size: 32Gi
      storageClass: "gp2"
    retention: "30d"
    resources:
      requests: { cpu: "1000m", memory: "2Gi" }
      limits: { cpu: "4000m", memory: "8Gi" }
    service:
      type: ClusterIP
  alertmanager: { enabled: false }
  pushgateway: { enabled: false }
  nodeExporter:
    enabled: true
    hostPort: 9111
    hostNetwork: true
  kubeStateMetrics:
    enabled: true

service:
  type: ClusterIP
  port: 9090
  targetPort: 9090

kubecostProductConfigs:
  clusterName: "CLUSTER_NAME_PLACEHOLDER"
  createServiceKeySecret: false
  cloudIntegrationSecret: "cloud-integration"
  cloudCostEnabled: true
  labelMappingConfigs:
    enabled: true
    owner_label: "team"
    product_label: "project"
    environment_label: "environment"
    department_label: "team"
  productKey:
    enabled: false
    key: ""

pricingCsv:
  enabled: true
  location:
    URI: /var/kubecost-csv/hyperpod-pricing.csv
    csvAccessCredentials: ""

kubecostModel:
  resources:
    requests: { cpu: "1000m", memory: "2Gi" }
    limits: { cpu: "4000m", memory: "8Gi" }

kubecostDeployment: { replicas: 1 }
ingress: { enabled: false }
grafana: { enabled: false }

networkCosts:
  enabled: true
  podMonitor: { enabled: false }
  resources:
    requests: { cpu: "50m", memory: "64Mi" }
    limits: { cpu: "200m", memory: "256Mi" }

reporting: { errorReporting: false, logCollection: false, productAnalytics: false }
VALUESEOF

# Replace placeholders
sed -i.bak "s|CLUSTER_NAME_PLACEHOLDER|${CLUSTER_NAME}|g" kubecost-values.yaml
rm -f kubecost-values.yaml.bak

# Verify
grep -q "PLACEHOLDER" kubecost-values.yaml && echo "❌ Placeholders remaining!" || echo "✅ All values set"
```
:::tip 
We created the kubecost as service: ClusterIP. Therefore, use port-forward to access the UI.
- Access via: **kubectl port-forward -n kubecost deployment/kubecost-cost-analyzer 9090:9090**
:::
### Key Helm Values Explained

| Setting | Purpose |
|---------|---------|
| `kubecostAggregator.enabled: false` | Aggregator is Enterprise-only; disabled for EKS bundle |
| `persistentVolume.storageClass: "gp2"` | Explicit StorageClass — PVC immutability prevents changing later |
| `costAnalyzer.extraVolumes` | Mounts CSV pricing ConfigMap into the cost-model container |
| `kubecostProductConfigs.cloudIntegrationSecret` | Points to the K8s secret with Athena/CUR config |
| `kubecostProductConfigs.labelMappingConfigs` | Maps `project`→product, `team`→owner for Kubecost allocation |
| `pricingCsv.enabled: true` | Enables CSV custom pricing as the primary pricing source |
| `service.type: ClusterIP` | Production-safe — no public exposure; use port-forward |
| `networkCosts.enabled: true` | Enables per-pod network cost tracking |
| `nodeExporter.enabled: true` | Required for node-level CPU/RAM/GPU metrics |
| `kubeStateMetrics.enabled: true` | Required for pod/deployment/job state metrics |

:::warning v2 mutual exclusivity
Do **NOT** set inline `athena*` values (like `athenaProjectID`, `athenaBucketName`) inside `kubecostProductConfigs`. Kubecost v2 enforces mutual exclusivity — use `cloudIntegrationSecret` **only**. Setting both causes silent failures.
:::
