"""Region B: AMP PrivateLink endpoints, TGW-B, peering + acceptance, DNS."""
import jsii

import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_iam as iam,
    aws_lambda as _lambda,
    aws_route53 as route53,
    custom_resources as cr,
)
from constructs import Construct


class AmpEndpointStack(Stack):
    def __init__(self, scope: Construct, cid: str, *, vpc_cidr: str,
                 grafana_vpc: ec2.IVpc, grafana_vpc_cidr: str,
                 grafana_tgw_id: str, grafana_tgw_route_table_id: str,
                 grafana_region: str, grafana_subnet_route_tables: list,
                 **kwargs) -> None:
        super().__init__(scope, cid, **kwargs)
        region_b = self.region

        vpc = ec2.Vpc(
            self, "AmpEndpointVpc",
            ip_addresses=ec2.IpAddresses.cidr(vpc_cidr),
            max_azs=2,
            nat_gateways=0,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="amp-endpoints",
                    subnet_type=ec2.SubnetType.PRIVATE_ISOLATED,
                    cidr_mask=24,
                ),
            ],
        )

        endpoint_sg = ec2.SecurityGroup(
            self, "AmpEndpointSg",
            vpc=vpc,
            description="Allow 443 from Grafana outbound VPC",
            allow_all_outbound=False,
        )
        endpoint_sg.add_ingress_rule(
            ec2.Peer.ipv4(grafana_vpc_cidr), ec2.Port.tcp(443),
            "PromQL queries from AMG outbound VPC",
        )

        subnet_selection = ec2.SubnetSelection(
            subnet_type=ec2.SubnetType.PRIVATE_ISOLATED)

        # Private DNS OFF on both endpoints — we provide DNS via PHZs below.
        aps_workspaces_ep = ec2.InterfaceVpcEndpoint(
            self, "ApsWorkspacesEndpoint",
            vpc=vpc,
            service=ec2.InterfaceVpcEndpointService(
                f"com.amazonaws.{region_b}.aps-workspaces", 443),
            private_dns_enabled=False,
            subnets=subnet_selection,
            security_groups=[endpoint_sg],
        )
        aps_ep = ec2.InterfaceVpcEndpoint(
            self, "ApsEndpoint",
            vpc=vpc,
            service=ec2.InterfaceVpcEndpointService(
                f"com.amazonaws.{region_b}.aps", 443),
            private_dns_enabled=False,
            subnets=subnet_selection,
            security_groups=[endpoint_sg],
        )

        # Same as TgwA: disable default association/propagation so the
        # explicit route-table association below doesn't collide.
        tgw = ec2.CfnTransitGateway(
            self, "TgwB",
            description="AMP-endpoint-side TGW",
            default_route_table_association="disable",
            default_route_table_propagation="disable",
            tags=[cdk.CfnTag(key="Name", value="amg-cross-region-tgw-b")],
        )
        attachment = ec2.CfnTransitGatewayAttachment(
            self, "TgwBVpcAttachment",
            transit_gateway_id=tgw.ref,
            vpc_id=vpc.vpc_id,
            subnet_ids=[s.subnet_id for s in vpc.isolated_subnets],
        )
        tgw_rt = ec2.CfnTransitGatewayRouteTable(
            self, "TgwBRouteTable",
            transit_gateway_id=tgw.ref,
            tags=[cdk.CfnTag(key="Name", value="amg-cross-region-tgw-b-rt")],
        )
        ec2.CfnTransitGatewayRouteTableAssociation(
            self, "TgwBRtAssoc",
            transit_gateway_attachment_id=attachment.ref,
            transit_gateway_route_table_id=tgw_rt.ref,
        )
        ec2.CfnTransitGatewayRouteTablePropagation(
            self, "TgwBRtProp",
            transit_gateway_attachment_id=attachment.ref,
            transit_gateway_route_table_id=tgw_rt.ref,
        )

        peering = ec2.CfnTransitGatewayPeeringAttachment(
            self, "TgwPeering",
            transit_gateway_id=tgw.ref,
            peer_transit_gateway_id=grafana_tgw_id,
            peer_account_id=self.account,
            peer_region=grafana_region,
        )

        # CloudFormation cannot accept a peering attachment, and an
        # AwsCustomResource cannot poll (its SDK call runs exactly once and
        # "succeeds" even on an empty describe result — routes then race the
        # attachment and fail with "is in invalid state"). Use a Lambda that
        # accepts the peering in Region A and blocks until it is 'available'
        # (acceptance -> available typically takes ~5 minutes).
        accept_fn = _lambda.Function(
            self, "AcceptPeeringFn",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="index.handler",
            timeout=cdk.Duration.minutes(15),
            code=_lambda.Code.from_inline(
                "import boto3, json, time, urllib.request\n"
                "def send(event, ctx, status, reason=''):\n"
                "    body = json.dumps({'Status': status, 'Reason': reason or 'ok',\n"
                "        'PhysicalResourceId': event.get('PhysicalResourceId')\n"
                "            or event['ResourceProperties']['AttachmentId'],\n"
                "        'StackId': event['StackId'], 'RequestId': event['RequestId'],\n"
                "        'LogicalResourceId': event['LogicalResourceId']}).encode()\n"
                "    req = urllib.request.Request(event['ResponseURL'], data=body,\n"
                "        method='PUT', headers={'Content-Type': ''})\n"
                "    urllib.request.urlopen(req)\n"
                "def handler(event, ctx):\n"
                "    try:\n"
                "        props = event['ResourceProperties']\n"
                "        att, region = props['AttachmentId'], props['PeerRegion']\n"
                "        if event['RequestType'] == 'Delete':\n"
                "            # Disassociate the peering from both TGW route tables\n"
                "            # BEFORE CloudFormation deletes them, else route-table\n"
                "            # deletion fails: 'tgw-attach-... is in invalid state'\n"
                "            # (hit live 2026-07-13). Then wait until disassociated.\n"
                "            local = boto3.client('ec2')\n"
                "            peer = boto3.client('ec2', region_name=region)\n"
                "            pairs = ((local, props.get('LocalRouteTableId')),\n"
                "                     (peer, props.get('PeerRouteTableId')))\n"
                "            for c, rt in pairs:\n"
                "                if not rt:\n"
                "                    continue\n"
                "                try:\n"
                "                    c.disassociate_transit_gateway_route_table(\n"
                "                        TransitGatewayRouteTableId=rt,\n"
                "                        TransitGatewayAttachmentId=att)\n"
                "                except Exception:\n"
                "                    pass\n"
                "            for c, rt in pairs:\n"
                "                if not rt:\n"
                "                    continue\n"
                "                for _ in range(30):\n"
                "                    try:\n"
                "                        a = c.get_transit_gateway_route_table_associations(\n"
                "                            TransitGatewayRouteTableId=rt,\n"
                "                            Filters=[{'Name': 'transit-gateway-attachment-id',\n"
                "                                      'Values': [att]}])['Associations']\n"
                "                        if not a or a[0]['State'] == 'disassociated':\n"
                "                            break\n"
                "                    except Exception:\n"
                "                        break\n"
                "                    time.sleep(10)\n"
                "            return send(event, ctx, 'SUCCESS')\n"
                "        ec2 = boto3.client('ec2', region_name=region)\n"
                "        state = ec2.describe_transit_gateway_peering_attachments(\n"
                "            TransitGatewayAttachmentIds=[att]\n"
                "        )['TransitGatewayPeeringAttachments'][0]['State']\n"
                "        if state == 'pendingAcceptance':\n"
                "            ec2.accept_transit_gateway_peering_attachment(\n"
                "                TransitGatewayAttachmentId=att)\n"
                "        while True:\n"
                "            state = ec2.describe_transit_gateway_peering_attachments(\n"
                "                TransitGatewayAttachmentIds=[att]\n"
                "            )['TransitGatewayPeeringAttachments'][0]['State']\n"
                "            if state == 'available':\n"
                "                break\n"
                "            if state in ('failed', 'rejected', 'deleted'):\n"
                "                return send(event, ctx, 'FAILED', f'state={state}')\n"
                "            time.sleep(15)\n"
                "        # Associate the peering attachment with both TGW route\n"
                "        # tables (idempotently). Without the association, return\n"
                "        # traffic arriving over the peering consults no route\n"
                "        # table and the path times out (hit live 2026-07-10).\n"
                "        local = boto3.client('ec2')\n"
                "        pairs = ((local, props['LocalRouteTableId']),\n"
                "                 (ec2, props['PeerRouteTableId']))\n"
                "        for c, rt in pairs:\n"
                "            try:\n"
                "                c.associate_transit_gateway_route_table(\n"
                "                    TransitGatewayRouteTableId=rt,\n"
                "                    TransitGatewayAttachmentId=att)\n"
                "            except Exception as e:\n"
                "                if 'ssociated' not in str(e):\n"
                "                    raise\n"
                "        for c, rt in pairs:\n"
                "            while True:\n"
                "                a = c.get_transit_gateway_route_table_associations(\n"
                "                    TransitGatewayRouteTableId=rt,\n"
                "                    Filters=[{'Name': 'transit-gateway-attachment-id',\n"
                "                              'Values': [att]}])['Associations']\n"
                "                if a and a[0]['State'] == 'associated':\n"
                "                    break\n"
                "                time.sleep(10)\n"
                "        return send(event, ctx, 'SUCCESS')\n"
                "    except Exception as e:\n"
                "        send(event, ctx, 'FAILED', str(e)[:300])\n"
            ),
        )
        accept_fn.add_to_role_policy(iam.PolicyStatement(
            actions=[
                "ec2:AcceptTransitGatewayPeeringAttachment",
                "ec2:DescribeTransitGatewayPeeringAttachments",
                "ec2:AssociateTransitGatewayRouteTable",
                "ec2:DisassociateTransitGatewayRouteTable",
                "ec2:GetTransitGatewayRouteTableAssociations",
            ],
            resources=["*"],
        ))

        waiter = cdk.CustomResource(
            self, "AcceptAndWaitPeering",
            service_token=accept_fn.function_arn,
            properties={
                "AttachmentId": peering.attr_transit_gateway_attachment_id,
                "PeerRegion": grafana_region,
                "LocalRouteTableId": tgw_rt.ref,
                "PeerRouteTableId": grafana_tgw_route_table_id,
            },
        )
        waiter.node.add_dependency(peering)
        waiter.node.add_dependency(tgw_rt)

        # Static routes across the peering (no propagation over peering).
        route_b = ec2.CfnTransitGatewayRoute(
            self, "TgwBRouteToGrafana",
            transit_gateway_route_table_id=tgw_rt.ref,
            destination_cidr_block=grafana_vpc_cidr,
            transit_gateway_attachment_id=
                peering.attr_transit_gateway_attachment_id,
        )
        route_b.node.add_dependency(waiter)

        # The Region A TGW route table lives in Region A, out of reach of this
        # stack's CFN resources — create that route via the EC2 API instead.
        route_a_cr = cr.AwsCustomResource(
            self, "TgwARouteToAmpCr",
            # createTransitGatewayRoute exists in Lambda's built-in SDK;
            # skipping the latest-SDK install avoids a slow npm fetch at
            # deploy time (and the CDK warning about it).
            install_latest_aws_sdk=False,
            on_create=cr.AwsSdkCall(
                service="EC2",
                action="createTransitGatewayRoute",
                region=grafana_region,
                parameters={
                    "TransitGatewayRouteTableId": grafana_tgw_route_table_id,
                    "DestinationCidrBlock": vpc_cidr,
                    "TransitGatewayAttachmentId":
                        peering.attr_transit_gateway_attachment_id,
                },
                physical_resource_id=cr.PhysicalResourceId.of(
                    f"tgwa-route-{vpc_cidr}"),
            ),
            on_delete=cr.AwsSdkCall(
                service="EC2",
                action="deleteTransitGatewayRoute",
                region=grafana_region,
                parameters={
                    "TransitGatewayRouteTableId": grafana_tgw_route_table_id,
                    "DestinationCidrBlock": vpc_cidr,
                },
            ),
            policy=cr.AwsCustomResourcePolicy.from_sdk_calls(
                resources=cr.AwsCustomResourcePolicy.ANY_RESOURCE),
        )
        route_a_cr.node.add_dependency(waiter)

        # VPC subnet routes in Region B: Grafana CIDR -> TGW-B
        for i, subnet in enumerate(vpc.isolated_subnets):
            r = ec2.CfnRoute(
                self, f"ToGrafanaVpc{i}",
                route_table_id=subnet.route_table.route_table_id,
                destination_cidr_block=grafana_vpc_cidr,
                transit_gateway_id=tgw.ref,
            )
            r.add_dependency(attachment)

        # PHZs for the two AMP hostnames, associated with the Region A VPC.
        # Zone-apex A/alias records point at the endpoints' regional DNS names.
        for name, ep, zid in [
            (f"aps-workspaces.{region_b}.amazonaws.com", aps_workspaces_ep, "Query"),
            (f"aps.{region_b}.amazonaws.com", aps_ep, "Mgmt"),
        ]:
            zone = route53.PrivateHostedZone(
                self, f"Phz{zid}",
                zone_name=name,
                vpc=grafana_vpc,  # cross-region association, CDK handles it
            )
            # DnsEntries[0] is the regional entry: "<hosted zone id>:<dns name>"
            entry = cdk.Fn.select(0, ep.vpc_endpoint_dns_entries)
            route53.ARecord(
                self, f"Apex{zid}",
                zone=zone,
                # empty record name = zone apex
                target=route53.RecordTarget.from_alias(
                    _EndpointAliasTarget(
                        cdk.Fn.select(1, cdk.Fn.split(":", entry)),
                        cdk.Fn.select(0, cdk.Fn.split(":", entry)),
                    )
                ),
            )

        cdk.CfnOutput(self, "ApsWorkspacesEndpointId",
                      value=aps_workspaces_ep.vpc_endpoint_id)
        cdk.CfnOutput(self, "PeeringAttachmentId",
                      value=peering.attr_transit_gateway_attachment_id)


@jsii.implements(route53.IAliasRecordTarget)
class _EndpointAliasTarget:
    """Alias a PHZ apex record to an interface endpoint's regional DNS name."""

    def __init__(self, dns_name: str, hosted_zone_id: str) -> None:
        self._dns = dns_name
        self._zone = hosted_zone_id

    def bind(self, _record, _zone=None):
        return route53.AliasRecordTargetConfig(
            dns_name=self._dns, hosted_zone_id=self._zone)
