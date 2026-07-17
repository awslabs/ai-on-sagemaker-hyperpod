#!/usr/bin/env python3
"""Cross-region Amazon Managed Grafana (Region A) -> AMP (Region B), private
connectivity via TGW peering + PrivateLink + Route 53 PHZs.

All parameters are CDK context values (cdk.json or -c overrides):

  required for full deploy:
    -c ampWorkspaceId=ws-...        AMP workspace in Region B (create it first
                                    by enabling HyperPod observability; see the
                                    Cross Region Observability guide). Omit to
                                    deploy networking only (2 stacks).
  regions:
    -c regionA=<amg-region>         where Grafana lives (MUST be AMG-supported)
    -c regionB=<amp-region>         where AMP + workload live
  networking:
    -c grafanaVpcCidr=10.10.0.0/16  must not overlap ampVpcCidr
    -c ampVpcCidr=10.20.0.0/16
  Grafana admin (pick ONE):
    -c grafanaAdminGuid=<guid>      IAM Identity Center user GUID (preferred)
    -c grafanaAdminUsername=<name> + -c ssoRegion=<identity-center-home-region>

Deploy order (automatic): GrafanaNetworkStack -> AmpEndpointStack ->
GrafanaConfigStack. The last stack FAILS THE DEPLOY unless Grafana can
actually query AMP end-to-end — a green deploy is the proof.
"""
import ipaddress
import re

import aws_cdk as cdk

from grafana_stack import GrafanaNetworkStack
from amp_endpoint_stack import AmpEndpointStack
from grafana_config_stack import GrafanaConfigStack

# Regions where Amazon Managed Grafana is offered (verify against
# https://docs.aws.amazon.com/general/latest/gr/grafana-service.html if this
# list looks stale — AMG expands slowly).
AMG_REGIONS = {
    "us-east-1", "us-east-2", "us-west-2",
    "ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
    "eu-central-1", "eu-west-1", "eu-west-2",
    "us-gov-east-1", "us-gov-west-1",
}

app = cdk.App()
ctx = app.node.try_get_context

region_a = ctx("regionA") or "us-east-2"
region_b = ctx("regionB") or "ap-south-2"
grafana_cidr = ctx("grafanaVpcCidr") or "10.10.0.0/16"
amp_cidr = ctx("ampVpcCidr") or "10.20.0.0/16"
amp_workspace_id = ctx("ampWorkspaceId")

if region_a not in AMG_REGIONS:
    raise ValueError(
        f"regionA={region_a} is not an AMG-supported region. "
        f"Pick one of: {sorted(AMG_REGIONS)}")
if region_a == region_b:
    raise ValueError("regionA and regionB must differ (same-region setups "
                     "need none of this — use the AMP data source directly)")
if ipaddress.ip_network(grafana_cidr).overlaps(ipaddress.ip_network(amp_cidr)):
    raise ValueError(f"grafanaVpcCidr ({grafana_cidr}) and ampVpcCidr "
                     f"({amp_cidr}) must not overlap")
if amp_workspace_id and not re.match(r"^ws-[0-9a-f-]+$", amp_workspace_id):
    raise ValueError(f"ampWorkspaceId '{amp_workspace_id}' does not look "
                     "like an AMP workspace id (ws-...)")

account = ctx("account") or app.account

grafana_stack = GrafanaNetworkStack(
    app, "GrafanaNetworkStack",
    env=cdk.Environment(account=account, region=region_a),
    vpc_cidr=grafana_cidr,
    peer_vpc_cidr=amp_cidr,
    cross_region_references=True,
)

amp_stack = AmpEndpointStack(
    app, "AmpEndpointStack",
    env=cdk.Environment(account=account, region=region_b),
    vpc_cidr=amp_cidr,
    grafana_vpc=grafana_stack.vpc,
    grafana_vpc_cidr=grafana_cidr,
    grafana_tgw_id=grafana_stack.tgw_id,
    grafana_tgw_route_table_id=grafana_stack.tgw_route_table_id,
    grafana_region=region_a,
    grafana_subnet_route_tables=grafana_stack.private_route_table_ids,
    cross_region_references=True,
)

if amp_workspace_id:
    config_stack = GrafanaConfigStack(
        app, "GrafanaConfigStack",
        env=cdk.Environment(account=account, region=region_a),
        workspace_id=grafana_stack.workspace.attr_id,
        amp_workspace_id=amp_workspace_id,
        amp_region=region_b,
        admin_user_guid=ctx("grafanaAdminGuid") or "",
        admin_username=ctx("grafanaAdminUsername") or "",
        sso_region=ctx("ssoRegion") or "",
    )
    config_stack.add_dependency(grafana_stack)
    config_stack.add_dependency(amp_stack)

app.synth()
