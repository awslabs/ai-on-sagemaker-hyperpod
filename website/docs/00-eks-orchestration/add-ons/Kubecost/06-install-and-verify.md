---
title: Install & Verify Deployment
sidebar_position: 6
---

# Install & Verify Deployment

This section installs Kubecost v2.8.4 via Helm and validates that all components — cost-analyzer, Aggregator, Prometheus, node exporter, and network costs — are running correctly with CSV pricing and CUR integration active.

## Install Kubecost v2.8.4 via Helm

```bash
aws ecr-public get-login-password --region us-east-1 \
    | helm registry login --username AWS --password-stdin public.ecr.aws

helm upgrade --install kubecost \
    oci://public.ecr.aws/kubecost/cost-analyzer \
    --version 2.8.4 \
    --namespace kubecost \
    --values kubecost-values.yaml \
    --timeout 10m --wait

echo "✅ Kubecost v2.8.4 installed"
```

## Verify Deployment

### Check Pod & PVC Status

```bash
# All pods should be Running — note the NEW aggregator pod
kubectl get pods -n kubecost

# Expected pods for v2.8.4:
#   kubecost-cost-analyzer-xxxxx          (cost-model + frontend)
#   kubecost-aggregator-xxxxx             (NEW — DuckDB aggregator)
#   kubecost-prometheus-server-xxxxx      (Prometheus)
#   kubecost-kube-state-metrics-xxxxx     (kube-state-metrics)
#   kubecost-prometheus-node-exporter-xxxxx (per-node DaemonSet)
#   kubecost-network-costs-xxxxx          (per-node DaemonSet)

# PVCs should be Bound
kubectl get pvc -n kubecost

# Service should be ClusterIP
kubectl get svc kubecost-cost-analyzer -n kubecost
```

:::info
If the PVC is stuck in pending, create DB PVC manually following the below command 
:::

## Create DB PVC (if chart doesn't auto-create)

```bash
cat <<'EOF' | kubectl apply -n kubecost -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kubecost-cost-analyzer-db
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 32Gi
EOF
```

### Verify CSV Mount

```bash
kubectl exec -n kubecost deployment/kubecost-cost-analyzer -c cost-model -- \
    head -3 /var/kubecost-csv/hyperpod-pricing.csv
```

### Verify Aggregator is Running

```bash
# Check aggregator pod
kubectl get pods -n kubecost -l app=aggregator
kubectl logs -n kubecost -l app=aggregator --tail=20 2>/dev/null || \
kubectl logs -n kubecost -l app.kubernetes.io/name=aggregator --tail=20 2>/dev/null || \
echo "Check aggregator pod name with: kubectl get pods -n kubecost"

# Aggregator PVC
kubectl get pvc -n kubecost | grep aggregator
```

## Access Dashboard via Port-Forward

```bash
# Start port-forward (run in background or separate terminal)
kubectl port-forward -n kubecost deployment/kubecost-cost-analyzer 9090:9090 &
sleep 3

export KUBECOST_URL="http://localhost:9090"
echo "Dashboard: $KUBECOST_URL"

# Open in browser
open $KUBECOST_URL 2>/dev/null || echo "Open http://localhost:9090 in your browser"
```

:::tip Production Tip
For team access, consider using an internal ALB with Amazon Cognito authentication instead of a public NLB. See [AWS blog: ALB + Cognito for K8s apps](https://aws.amazon.com/blogs/containers/how-to-use-application-load-balancer-and-amazon-cognito-to-authenticate-users-for-your-kubernetes-web-apps).
:::

## Validate Health & Integrations

```bash
# Health check
curl -s "${KUBECOST_URL}/healthz"

# CUR integration status (should show "connected")
curl -s "${KUBECOST_URL}/model/cloudCost/status" | jq '.'

# CSV pricing source validation
curl -s "${KUBECOST_URL}/model/pricingSourceCounts" | jq '.'
# Expected: should show "custom" or "csv" pricing source with count > 0
```

## Verify Node Pricing

```bash
curl -s "${KUBECOST_URL}/model/assets?window=today&filterTypes=Node&accumulate=true" \
    | jq '.data[0] | to_entries[] | {node: .key, hourlyRate: ((.value.totalCost / .value.minutes) * 60 | . * 100 | round / 100)}'

# Stop port-forward when done
kill %1 2>/dev/null
```
