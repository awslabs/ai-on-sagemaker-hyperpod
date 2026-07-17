"""Region A: in-Grafana configuration as code.

CloudFormation has no resources for AMG user assignments, service accounts,
or Grafana data sources — so this stack owns them via one idempotent
Lambda-backed custom resource that:
  1. grants the given IAM Identity Center user ADMIN on the workspace
     (durable AMG-level grant via grafana:UpdatePermissions — survives SSO
     re-sync, unlike an in-Grafana org-role patch),
  2. re-asserts the workspace-level PROMETHEUS/CLOUDWATCH data-source flags
     (self-heals the AMG bug where CreateWorkspace silently drops them),
  3. creates a 'cdk-provisioner' ADMIN service account and an EPHEMERAL
     token (15 min TTL, deleted after use — no long-lived secret stored),
  4. provisions the Prometheus data source (SigV4, workspace IAM role,
     pointed at the AMP workspace in Region B),
  5. VERIFIES: calls the data source health endpoint and FAILS THE DEPLOY
     unless Grafana can actually query AMP through the cross-region path.

Re-running `cdk deploy` reconciles drift (update-in-place, same names).
"""
import json

import aws_cdk as cdk
from aws_cdk import (
    Stack,
    aws_iam as iam,
    aws_lambda as _lambda,
)
from constructs import Construct

PROVISIONER_CODE = r'''
import boto3, json, time, urllib.request, urllib.parse, urllib.error

def send(event, status, reason='', data=None):
    body = json.dumps({
        'Status': status, 'Reason': (reason or 'ok')[:400],
        'PhysicalResourceId': 'grafana-config-' + event['ResourceProperties']['WorkspaceId'],
        'StackId': event['StackId'], 'RequestId': event['RequestId'],
        'LogicalResourceId': event['LogicalResourceId'], 'Data': data or {}}).encode()
    urllib.request.urlopen(urllib.request.Request(
        event['ResponseURL'], data=body, method='PUT',
        headers={'Content-Type': ''}))

def handler(event, ctx):
    try:
        p = event['ResourceProperties']
        ws, region = p['WorkspaceId'], p['WorkspaceRegion']
        g = boto3.client('grafana', region_name=region)

        if event['RequestType'] == 'Delete':
            try:
                for sa in g.list_workspace_service_accounts(
                        workspaceId=ws)['serviceAccounts']:
                    if sa['name'] == 'cdk-provisioner':
                        g.delete_workspace_service_account(
                            workspaceId=ws, serviceAccountId=sa['id'])
            except Exception:
                pass
            return send(event, 'SUCCESS')

        # -- 1. durable ADMIN grant via AMG permissions API ----------------
        guid = p.get('AdminUserGuid') or ''
        if not guid and p.get('AdminUsername') and p.get('SsoRegion'):
            sso = boto3.client('sso-admin', region_name=p['SsoRegion'])
            store = sso.list_instances()['Instances'][0]['IdentityStoreId']
            ids = boto3.client('identitystore', region_name=p['SsoRegion'])
            guid = ids.get_user_id(
                IdentityStoreId=store,
                AlternateIdentifier={'UniqueAttribute': {
                    'AttributePath': 'userName',
                    'AttributeValue': p['AdminUsername']}})['UserId']
        granted = 'skipped (no AdminUserGuid/AdminUsername+SsoRegion)'
        if guid:
            g.update_permissions(workspaceId=ws, updateInstructionBatch=[
                {'action': 'ADD', 'role': 'ADMIN',
                 'users': [{'id': guid, 'type': 'SSO_USER'}]}])
            granted = guid

        # -- 2. self-heal workspace data-source flags ----------------------
        w = g.describe_workspace(workspaceId=ws)['workspace']
        have = set(w.get('dataSources') or [])
        if not {'PROMETHEUS', 'CLOUDWATCH'} <= have:
            g.update_workspace(workspaceId=ws, workspaceDataSources=sorted(
                have | {'PROMETHEUS', 'CLOUDWATCH'}))
            for _ in range(40):
                time.sleep(15)
                w = g.describe_workspace(workspaceId=ws)['workspace']
                if w['status'] == 'ACTIVE':
                    break

        # -- 3. service account + ephemeral token --------------------------
        said = next((sa['id'] for sa in g.list_workspace_service_accounts(
            workspaceId=ws)['serviceAccounts']
            if sa['name'] == 'cdk-provisioner'), None)
        if not said:
            said = g.create_workspace_service_account(
                workspaceId=ws, grafanaRole='ADMIN',
                name='cdk-provisioner')['id']
        tok = g.create_workspace_service_account_token(
            workspaceId=ws, serviceAccountId=said,
            name='deploy-' + event['RequestId'][:8],
            secondsToLive=900)['serviceAccountToken']
        base = 'https://' + w['endpoint']
        hdrs = {'Authorization': 'Bearer ' + tok['key'],
                'Content-Type': 'application/json'}

        def api(method, path, body=None):
            req = urllib.request.Request(
                base + path,
                data=json.dumps(body).encode() if body else None,
                method=method, headers=hdrs)
            try:
                with urllib.request.urlopen(req) as r:
                    return r.status, json.loads(r.read() or '{}')
            except urllib.error.HTTPError as e:
                return e.code, json.loads(e.read() or '{}')

        try:
            # -- 4. provision the data source (idempotent by name) ---------
            name = p['DataSourceName']
            payload = {
                'name': name, 'type': 'prometheus', 'access': 'proxy',
                'url': p['AmpUrl'],
                # sigV4AuthType MUST be 'default' (= AMG workspace IAM role);
                # 'workspace-iam-role' is not a valid Grafana value and fails
                # health with 'invalid auth type' (hit live 2026-07-10)
                'jsonData': {'httpMethod': 'POST', 'sigV4Auth': True,
                             'sigV4AuthType': 'default',
                             'sigV4Region': p['AmpRegion']}}
            st, existing = api(
                'GET', '/api/datasources/name/' + urllib.parse.quote(name))
            if st == 200:
                uid = existing['uid']
                api('PUT', '/api/datasources/uid/' + uid, payload)
            else:
                st2, created = api('POST', '/api/datasources', payload)
                if st2 != 200:
                    return send(event, 'FAILED',
                                f'datasource create: {st2} {created}')
                uid = created['datasource']['uid']

            # -- 5. VERIFY: health check through the cross-region path -----
            ok, last = False, ''
            for _ in range(12):
                st3, h = api('GET', f'/api/datasources/uid/{uid}/health')
                last = f'{st3} {json.dumps(h)[:200]}'
                if st3 == 200 and h.get('status') == 'OK':
                    ok = True
                    break
                time.sleep(10)
        finally:
            g.delete_workspace_service_account_token(
                workspaceId=ws, serviceAccountId=said, tokenId=tok['id'])

        if not ok:
            return send(event, 'FAILED',
                        'data source health check never passed: ' + last)

        # -- 6. import community dashboards, wired to the data source. ----
        # Must happen HERE (Lambda has internet): the workspace's own
        # import-by-ID fetch of grafana.com dies silently because all its
        # egress goes via the no-internet outbound VPC (hit live 2026-07-13).
        # Needs its own token: the health-check token was deleted above.
        dashboards = json.loads(p.get('DashboardIds') or '[]')
        imported = []
        if dashboards:
            tok2 = g.create_workspace_service_account_token(
                workspaceId=ws, serviceAccountId=said,
                name='dash-' + event['RequestId'][:8],
                secondsToLive=900)['serviceAccountToken']
            hdrs2 = {'Authorization': 'Bearer ' + tok2['key'],
                     'Content-Type': 'application/json'}
            try:
                for db_id in dashboards:
                    with urllib.request.urlopen(
                            'https://grafana.com/api/dashboards/'
                            f'{db_id}/revisions/latest/download') as r:
                        dash = json.loads(r.read())
                    dash.pop('__inputs', None)
                    dash.pop('__requires', None)

                    def rewrite(o):
                        if isinstance(o, dict):
                            if o.get('type') == 'prometheus' and 'uid' in o:
                                o['uid'] = uid
                            for v in o.values():
                                rewrite(v)
                        elif isinstance(o, list):
                            for v in o:
                                rewrite(v)
                    rewrite(dash)
                    s = json.dumps(dash)
                    for token in ('${DS_PROMETHEUS}', '$DS_PROMETHEUS'):
                        s = s.replace(token, uid)
                    body = {'dashboard': json.loads(s), 'overwrite': True,
                            'inputs': [{'name': 'DS_PROMETHEUS',
                                        'type': 'datasource',
                                        'pluginId': 'prometheus',
                                        'value': uid}]}
                    req = urllib.request.Request(
                        base + '/api/dashboards/import',
                        data=json.dumps(body).encode(),
                        headers=hdrs2, method='POST')
                    with urllib.request.urlopen(req) as r:
                        imported.append(str(db_id))
            finally:
                g.delete_workspace_service_account_token(
                    workspaceId=ws, serviceAccountId=said,
                    tokenId=tok2['id'])

        send(event, 'SUCCESS', data={
            'DataSourceUid': uid, 'Health': 'OK', 'AdminGrant': granted,
            'Dashboards': ','.join(imported) or 'none'})
    except Exception as e:
        send(event, 'FAILED', repr(e))
'''


class GrafanaConfigStack(Stack):
    def __init__(self, scope: Construct, cid: str, *, workspace_id: str,
                 amp_workspace_id: str, amp_region: str,
                 admin_user_guid: str = "", admin_username: str = "",
                 sso_region: str = "",
                 dashboard_ids: list = (1860, 15757),
                 **kwargs) -> None:
        super().__init__(scope, cid, **kwargs)

        fn = _lambda.Function(
            self, "GrafanaProvisionerFn",
            runtime=_lambda.Runtime.PYTHON_3_12,
            handler="index.handler",
            timeout=cdk.Duration.minutes(15),
            code=_lambda.Code.from_inline(PROVISIONER_CODE),
        )
        fn.add_to_role_policy(iam.PolicyStatement(
            actions=[
                "grafana:DescribeWorkspace", "grafana:UpdateWorkspace",
                "grafana:UpdatePermissions",
                "grafana:ListWorkspaceServiceAccounts",
                "grafana:CreateWorkspaceServiceAccount",
                "grafana:DeleteWorkspaceServiceAccount",
                "grafana:CreateWorkspaceServiceAccountToken",
                "grafana:DeleteWorkspaceServiceAccountToken",
            ],
            resources=["*"],
        ))
        # update_permissions manipulates the Identity Center "managed
        # application" behind the workspace — without the sso:*Profile*
        # actions it fails with "Unable to update users in managed
        # application" (root-caused live 2026-07-10; set mirrors the
        # AWSGrafanaWorkspacePermissionManagementV2 managed policy).
        fn.add_to_role_policy(iam.PolicyStatement(
            actions=[
                "sso:ListInstances", "identitystore:GetUserId",
                "sso:DescribeRegisteredRegions",
                "sso:GetSharedSsoConfiguration",
                "sso:ListDirectoryAssociations",
                "sso:GetManagedApplicationInstance",
                "sso:ListProfiles", "sso:GetProfile",
                "sso:ListProfileAssociations",
                "sso:AssociateProfile", "sso:DisassociateProfile",
                "sso-directory:DescribeUser", "sso-directory:DescribeGroup",
            ],
            resources=["*"],
        ))

        config = cdk.CustomResource(
            self, "GrafanaConfig",
            service_token=fn.function_arn,
            properties={
                "WorkspaceId": workspace_id,
                "WorkspaceRegion": self.region,
                "AmpUrl": f"https://aps-workspaces.{amp_region}.amazonaws.com"
                          f"/workspaces/{amp_workspace_id}",
                "AmpRegion": amp_region,
                "DataSourceName": f"AMP {amp_workspace_id} ({amp_region})",
                "AdminUserGuid": admin_user_guid,
                "AdminUsername": admin_username,
                "SsoRegion": sso_region,
                "DashboardIds": json.dumps(list(dashboard_ids)),
                # bump to force re-reconcile on demand
                "ConfigVersion": "2",
            },
        )

        cdk.CfnOutput(self, "DataSourceUid",
                      value=config.get_att_string("DataSourceUid"))
        cdk.CfnOutput(self, "ImportedDashboards",
                      value=config.get_att_string("Dashboards"))
        cdk.CfnOutput(self, "DataSourceHealth",
                      value=config.get_att_string("Health"))
