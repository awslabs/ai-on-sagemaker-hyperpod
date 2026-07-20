"""Region A: Grafana outbound VPC, Transit Gateway, and AMG workspace."""
import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_grafana as grafana,
    aws_iam as iam,
)
from constructs import Construct


class GrafanaNetworkStack(Stack):
    def __init__(self, scope: Construct, cid: str, *, vpc_cidr: str,
                 peer_vpc_cidr: str, peer_region_name: str,
                 **kwargs) -> None:
        super().__init__(scope, cid, **kwargs)

        # AMG outbound VPC requirements: >=2 AZs, one private subnet each,
        # >=15 free IPs per subnet, DNS support enabled (VPC default).
        self.vpc = ec2.Vpc(
            self, "GrafanaVpc",
            ip_addresses=ec2.IpAddresses.cidr(vpc_cidr),
            max_azs=2,
            nat_gateways=0,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="grafana-private",
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED,
                    cidr_mask=24,
                ),
            ],
        )

        self.grafana_sg = ec2.SecurityGroup(
            self, "GrafanaOutboundSg",
            vpc=self.vpc,
            description="AMG outbound VPC connection",
            allow_all_outbound=True,
        )

        # Default association/propagation must be OFF: we associate the
        # attachment to our own route table below, and an attachment can only
        # be associated with one route table.
        tgw = ec2.CfnTransitGateway(
            self, "TgwA",
            description="Grafana-side TGW",
            default_route_table_association="disable",
            default_route_table_propagation="disable",
            tags=[cdk.CfnTag(key="Name", value="amg-cross-region-tgw-a")],
        )
        self.tgw_id = tgw.ref

        attachment = ec2.CfnTransitGatewayAttachment(
            self, "TgwAVpcAttachment",
            transit_gateway_id=tgw.ref,
            vpc_id=self.vpc.vpc_id,
            subnet_ids=[s.subnet_id for s in self.vpc.isolated_subnets],
        )

        # Default TGW route table id isn't exposed as a CFN attribute; use a
        # dedicated route table so Region B can add the static peering route to it.
        tgw_rt = ec2.CfnTransitGatewayRouteTable(
            self, "TgwARouteTable",
            transit_gateway_id=tgw.ref,
            tags=[cdk.CfnTag(key="Name", value="amg-cross-region-tgw-a-rt")],
        )
        self.tgw_route_table_id = tgw_rt.ref

        ec2.CfnTransitGatewayRouteTableAssociation(
            self, "TgwARtAssoc",
            transit_gateway_attachment_id=attachment.ref,
            transit_gateway_route_table_id=tgw_rt.ref,
        )
        ec2.CfnTransitGatewayRouteTablePropagation(
            self, "TgwARtProp",
            transit_gateway_attachment_id=attachment.ref,
            transit_gateway_route_table_id=tgw_rt.ref,
        )

        # VPC subnet routes: AMP VPC CIDR -> TGW
        self.private_route_table_ids = []
        for i, subnet in enumerate(self.vpc.isolated_subnets):
            rt_id = subnet.route_table.route_table_id
            self.private_route_table_ids.append(rt_id)
            route = ec2.CfnRoute(
                self, f"ToAmpVpc{i}",
                route_table_id=rt_id,
                destination_cidr_block=peer_vpc_cidr,
                transit_gateway_id=tgw.ref,
            )
            route.add_dependency(attachment)

        workspace_role = iam.Role(
            self, "GrafanaWorkspaceRole",
            assumed_by=iam.ServicePrincipal("grafana.amazonaws.com"),
        )
        # Scope the query actions to AMP workspaces in the metrics Region /
        # this account. aps:ListWorkspaces does not support resource-level
        # permissions (it enumerates the account), so it stays "*"; the
        # per-workspace read actions are scoped to workspace ARNs. We scope to
        # workspace/* rather than one id because the HyperPod observability
        # add-on regenerates the workspace id on each enable — pinning a single
        # ARN would silently break queries after a re-enable.
        amp_workspaces_arn = (
            f"arn:aws:aps:{peer_region_name}:{self.account}:workspace/*")
        workspace_role.add_to_policy(iam.PolicyStatement(
            sid="AmpList",
            actions=["aps:ListWorkspaces"],
            resources=["*"],
        ))
        workspace_role.add_to_policy(iam.PolicyStatement(
            sid="AmpQuery",
            actions=[
                "aps:DescribeWorkspace",
                "aps:QueryMetrics",
                "aps:GetLabels",
                "aps:GetSeries",
                "aps:GetMetricMetadata",
            ],
            resources=[amp_workspaces_arn],
        ))

        self.workspace = grafana.CfnWorkspace(
            self, "AmgWorkspace",
            account_access_type="CURRENT_ACCOUNT",
            authentication_providers=["AWS_SSO"],
            permission_type="SERVICE_MANAGED",
            role_arn=workspace_role.role_arn,
            data_sources=["PROMETHEUS", "CLOUDWATCH"],
            vpc_configuration=grafana.CfnWorkspace.VpcConfigurationProperty(
                security_group_ids=[self.grafana_sg.security_group_id],
                subnet_ids=[s.subnet_id for s in self.vpc.isolated_subnets],
            ),
        )

        cdk.CfnOutput(self, "WorkspaceEndpoint", value=self.workspace.attr_endpoint)
        cdk.CfnOutput(self, "TgwIdOut", value=self.tgw_id)
