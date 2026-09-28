---
title: CSV Pricing & ConfigMap
sidebar_position: 3
---

# Create Custom Pricing CSV & ConfigMap

Using the effective hourly rates derived from your CUR data via Athena, this section creates the CSV pricing file and Kubernetes ConfigMap that Kubecost uses as its primary pricing source for HyperPod nodes.

## Create the CSV (OpenCost Format)

Using the rates from the [Athena query](./02-cur-and-athena-setup.md#query-effective-hourly-rates), create the pricing file:

```bash
cat > hyperpod-pricing.csv <<EOF
EndTimestamp,InstanceID,Region,AssetClass,InstanceIDField,InstanceType,MarketPriceHourly,Version
,ml.g6.12xlarge,${AWS_REGION},node,metadata.labels.node.kubernetes.io/instance-type,ml.g6.12xlarge,13.9860,v1
,ml.m5.12xlarge,${AWS_REGION},node,metadata.labels.node.kubernetes.io/instance-type,ml.m5.12xlarge,2.6496,v1
,ml.g5.12xlarge,${AWS_REGION},node,metadata.labels.node.kubernetes.io/instance-type,ml.g5.12xlarge,7.0900,v1
EOF
```

:::warning IMPORTANT
- Replace the `MarketPriceHourly` values with **YOUR** rates from the Athena query
- Add a row for **EVERY** instance type in your cluster
- Both `InstanceID` and `InstanceType` must contain the full `ml.*` instance type (HyperPod nodes use the `ml.` prefix)
- `InstanceIDField` must be exactly `metadata.labels.node.kubernetes.io/instance-type`
:::

## Create Kubecost Namespace & ConfigMap

The namespace and ConfigMap must exist **before** Helm install (so the volume mount works on first deploy):

```bash
kubectl create namespace kubecost --dry-run=client -o yaml | kubectl apply -f -

kubectl delete configmap kubecost-custom-pricing -n kubecost --ignore-not-found
kubectl create configmap kubecost-custom-pricing -n kubecost --from-file=hyperpod-pricing.csv

# Verify
kubectl get configmap kubecost-custom-pricing -n kubecost
kubectl get configmap kubecost-custom-pricing -n kubecost \
    -o jsonpath='{.data.hyperpod-pricing\.csv}' | head -5
```
