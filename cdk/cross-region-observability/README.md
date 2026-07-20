# Cross Region Observability — CDK

AWS CDK app that privately connects **Amazon Managed Grafana** in one Region to
a **SageMaker HyperPod** cluster's **Amazon Managed Service for Prometheus**
metrics in another Region (Transit Gateway peering + PrivateLink + Route 53).

**Full step-by-step guide:**
https://awslabs.github.io/ai-on-sagemaker-hyperpod/docs/common/cross-region-observability/

## Quick start

```bash
python3 -m pip install -r requirements.txt
npm install -g aws-cdk

cdk bootstrap aws://<account>/<regionA> aws://<account>/<regionB>
cdk deploy --all --require-approval never \
  -c regionA=<amg-region> \
  -c regionB=<amp-region> \
  -c ampWorkspaceId=ws-... \
  -c grafanaAdminGuid=<identity-center-user-guid>
```

Post-deploy validation (no UI login required):

```bash
./validate.sh <regionA> <regionB> ws-...
```

## Files

| File | Purpose |
|---|---|
| `app.py` | Entry point; context parameters and guardrails |
| `grafana_stack.py` | Region A: VPC, Transit Gateway, AMG workspace |
| `amp_endpoint_stack.py` | Region B: PrivateLink endpoints, TGW peering (+ accept/associate Lambda), Route 53 PHZs |
| `grafana_config_stack.py` | Region A: admin grant, data source, health-check gate, dashboard import |
| `deployer-permissions.json` | Reference IAM policy for the deploying principal |
| `validate.sh` | End-to-end verification script |
| `cdk.json` | Defaults and CDK feature flags |

Context parameters (all overridable with `-c`): `regionA`, `regionB`,
`ampWorkspaceId`, `grafanaAdminGuid` (or `grafanaAdminUsername` + `ssoRegion`),
`grafanaVpcCidr`, `ampVpcCidr`. See the header of `app.py` for details.
