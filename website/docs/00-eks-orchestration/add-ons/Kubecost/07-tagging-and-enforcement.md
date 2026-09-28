---
title: Tagging, Enforcement & Job Submission
sidebar_position: 7
---

# Tagging, Enforcement & Job Submission

This section covers the complete cost attribution workflow — enabling AWS cost allocation tags, defining a label schema, applying labels to nodes and pods, enforcing labels with OPA Gatekeeper, configuring priority classes, and submitting jobs with full cost attribution.

## Enable AWS Cost Allocation Tags

```bash
aws ce update-cost-allocation-tags-status \
    --cost-allocation-tags-status Key=project,Status=Active Key=team,Status=Active \
    2>/dev/null && echo "✅ Tags activated" || echo "Check AWS Billing Console"
```

:::warning HyperPod node tagging
The `aws ec2 create-tags` approach used for standard EKS clusters **may not work on HyperPod nodes**, since the underlying compute is managed by SageMaker and may not expose valid EC2 instance IDs via `providerID`. For cost attribution, **pod-level labels** (covered below) are what Kubecost reads for the Allocations view. Node labels set via `kubectl label` work for the Assets view. To tag the HyperPod cluster itself at the AWS level, use `aws sagemaker add-tags --resource-arn <cluster-arn>`.
:::

## Tagging Strategy & Label Schema (sample)

| Label | Required | Purpose | Examples |
|-------|----------|---------|---------|
| `team` | ✅ | Team ownership | `ml-platform`, `research`, `production` |
| `project` | ✅ | Project/initiative | `llm-training`, `fraud-detection` |
| `environment` | ✅ | Deployment stage | `dev`, `staging`, `prod` |
| `workload-type` | Optional | Workload category | `training`, `inference`, `data-prep` |
| `owner` | Optional | Job submitter | `user@company.com` |

**Key rules:**
- **Pod labels are what Kubecost reads** for the Allocations view
- **Node labels** matter for the Assets view
- Labels on the **Job object** don't automatically flow to pods — you must set them in `template.metadata.labels`

## Apply Labels to Nodes, Pods & Jobs

### Label Nodes

```bash
kubectl label nodes --all team=shared project=infrastructure --overwrite
kubectl get nodes -L team,project
```

### Label Pods via HyperPodPyTorchJob

```yaml
apiVersion: sagemaker.amazonaws.com/v1
kind: HyperPodPyTorchJob
metadata:
  name: llm-training-job
spec:
  nprocPerNode: "8"
  replicaSpecs:
    - name: pods
      replicas: 4
      template:
        metadata:
          labels:
            project: llm-training      # ← Kubecost reads these
            team: ml-platform           # ← And these
            environment: prod
            workload-type: training
        spec:
          containers:
            - name: pytorch
              image: your-image:latest
              resources:
                requests: { nvidia.com/gpu: 8 }
                limits: { nvidia.com/gpu: 8 }
```

## Label Enforcement with OPA Gatekeeper

### Install Gatekeeper

```bash
if kubectl get namespace gatekeeper-system &>/dev/null; then
    echo "✅ Already installed"
else
    kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.15.1/deploy/gatekeeper.yaml
    kubectl wait --for=condition=Ready pods --all -n gatekeeper-system --timeout=300s
fi
```

### Create ConstraintTemplate

:::info IMPORTANT
The ConstraintTemplate and Constraint must be applied in **two separate steps**. Gatekeeper needs time to register the new CRD before the Constraint can be created.
:::

**Step 1 — Apply the ConstraintTemplate:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items: { type: string }
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {l | input.review.object.metadata.labels[l]}
          required := {l | l := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }
EOF

echo "Waiting for CRD to register..."
sleep 10
kubectl get constrainttemplates k8srequiredlabels && echo "✅ ConstraintTemplate ready"
```

### Create Constraint

**Step 2 — Apply the Constraint (must run AFTER the ConstraintTemplate is ready):**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-cost-labels
spec:
  match:
    kinds: [{apiGroups: [""], kinds: ["Pod"]}]
    excludedNamespaces: ["kube-system","kubecost","gatekeeper-system","sagemaker-hyperpod-system"]
  parameters:
    labels: ["project","team"]
EOF

# Verify constraint exists
kubectl get k8srequiredlabels require-cost-labels && echo "✅ Label enforcement active"
```

### Test Enforcement

```bash
kubectl run test-bad --image=nginx 2>&1 | grep -q "denied" && echo "✅ Unlabeled pod rejected"
kubectl run test-good --image=nginx --labels="project=test,team=platform" && \
    kubectl delete pod test-good && echo "✅ Labeled pod accepted"
```

## Priority Classes (Without Task Governance Only)

<details>
<summary><strong>⚠️ SKIP if using Task Governance — click to expand only if NOT using Task Governance</strong></summary>

Task Governance installs its own `WorkloadPriorityClasses` via Kueue. Creating custom PriorityClasses alongside Task Governance's may cause scheduling conflicts. Only use the section below if you are **not** using the Task Governance add-on (`amazon-sagemaker-hyperpod-taskgovernance`).

```bash
cat <<'EOF' | kubectl apply -f -
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: critical-priority }
value: 1000000
globalDefault: false
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: high-priority }
value: 100000
globalDefault: false
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: medium-priority }
value: 10000
globalDefault: true
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: low-priority }
value: 1000
globalDefault: false
EOF
```

</details>

## Job Submission with Cost Attribution (Example only)

:::info
This is an optional wrapper script. You can submit jobs any way you prefer (HyperPod CLI, Training Operator, raw `kubectl apply`) — just ensure your pod templates include the required `project` and `team` labels.
:::

```bash
cat > submit-job.sh <<'SCRIPT_EOF'
#!/bin/bash
set -e
TEAM=${1:?"Usage: $0 <team> <project> <env> [priority] [workers]"}
PROJECT=${2:?"Project required"}; ENV=${3:?"Env required"}
PRIORITY=${4:-medium}; WORKERS=${5:-3}
JOB_ID="job-$(date +%Y%m%d-%H%M%S)-$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"

case $PRIORITY in
    critical) PC="critical-priority";; high) PC="high-priority";;
    medium) PC="medium-priority";; low) PC="low-priority";; *) echo "Bad priority"; exit 1;;
esac

echo "Submitting: $PROJECT-$JOB_ID (team=$TEAM, env=$ENV, priority=$PRIORITY, workers=$WORKERS)"

cat > ${JOB_ID}.yaml <<EOF
apiVersion: sagemaker.amazonaws.com/v1
kind: HyperPodPyTorchJob
metadata:
  name: ${PROJECT}-${JOB_ID}
  labels: { project: "${PROJECT}", team: "${TEAM}", environment: "${ENV}", job_id: "${JOB_ID}" }
spec:
  nprocPerNode: "8"
  replicaSpecs:
    - name: pods
      replicas: ${WORKERS}
      template:
        metadata:
          labels: { project: "${PROJECT}", team: "${TEAM}", environment: "${ENV}", workload-type: training, job_id: "${JOB_ID}", "kueue.x-k8s.io/queue-name": "${TEAM}-queue" }
        spec:
          priorityClassName: ${PC}
          nodeSelector: { sagemaker.amazonaws.com/node-health-status: Schedulable }
          containers:
            - name: pytorch
              image: your-image:latest
              resources: { requests: { nvidia.com/gpu: 8 }, limits: { nvidia.com/gpu: 8 } }
              volumeMounts: [{ mountPath: /fsx, name: fsx }]
          volumes: [{ name: fsx, persistentVolumeClaim: { claimName: fsx-claim } }]
EOF

kubectl apply -f ${JOB_ID}.yaml
echo "✅ Submitted. Monitor: kubectl get pods -l job_id=${JOB_ID}"
SCRIPT_EOF
chmod +x submit-job.sh
```

:::info Kueue integration
The `kueue.x-k8s.io/queue-name` label in the pod template integrates with the HyperPod Task Governance add-on (Kueue). If you're not using Task Governance, this label is safely ignored.
:::

## Finish
Kubecost using CUR for accurate per node pricing with tagging enforcement deployment is now complete. You'll now be able to see the per job/project/team level costing in Kubecost.
#### Things to keep in mind:
- While creating the constraint, make sure you update/provide the labels you would like to enforce
- Always submit your job with the required labels, else it'll fail
- Make sure to use the Athena query to get the correct per node pricing to get accurate costing
- If you just deployed your CUR, wait for 24-48 hours for CUR data to populate
