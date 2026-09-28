#!/usr/bin/env bash
# Post-deploy validation: proves AMG (Region A) can query AMP (Region B)
# through the private path, without any UI login.
#
# Usage: ./validate.sh <REGION_A> <REGION_B> <AMP_WS_ID>
set -uo pipefail
RA=${1:?usage: validate.sh REGION_A REGION_B AMP_WS_ID}
RB=${2:?}; WS=${3:?}
FAIL=0
say() { printf '%-58s %s\n' "$1" "$2"; }
bad() { say "$1" "FAIL: $2"; FAIL=1; }

# 1. stacks
for pair in "$RA GrafanaNetworkStack" "$RB AmpEndpointStack" "$RA GrafanaConfigStack"; do
  set -- $pair
  st=$(aws cloudformation describe-stacks --region "$1" --stack-name "$2" \
       --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
  [ "$st" = "CREATE_COMPLETE" ] || [ "$st" = "UPDATE_COMPLETE" ] \
    && say "stack $2" "OK ($st)" || bad "stack $2" "${st:-ABSENT}"
done

# 2. peering available + associated both sides
GWID=$(aws cloudformation describe-stacks --region "$RA" --stack-name GrafanaNetworkStack \
  --query "Stacks[0].Outputs[?OutputKey=='TgwIdOut'].OutputValue" --output text 2>/dev/null)
PEER=$(aws ec2 describe-transit-gateway-peering-attachments --region "$RB" \
  --filters "Name=state,Values=available" \
  --query "TransitGatewayPeeringAttachments[?AccepterTgwInfo.TransitGatewayId=='$GWID' || RequesterTgwInfo.TransitGatewayId=='$GWID'] | [0].TransitGatewayAttachmentId" \
  --output text 2>/dev/null)
[ -n "$PEER" ] && [ "$PEER" != "None" ] \
  && say "TGW peering available" "OK ($PEER)" || bad "TGW peering available" "not found"
for r in "$RA" "$RB"; do
  n=$(aws ec2 get-transit-gateway-route-table-associations --region "$r" \
      --transit-gateway-route-table-id "$(aws ec2 describe-transit-gateway-route-tables \
        --region "$r" --filters "Name=tag:Name,Values=amg-cross-region-tgw-*" \
        --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' --output text)" \
      --query "length(Associations[?TransitGatewayAttachmentId=='$PEER' && State=='associated'])" \
      --output text 2>/dev/null)
  [ "$n" = "1" ] && say "peering associated to route table ($r)" "OK" \
    || bad "peering associated to route table ($r)" "missing"
done

# 3. workspace + data source health + live query via ephemeral token
WSID=$(aws grafana list-workspaces --region "$RA" \
  --query 'workspaces[?status==`ACTIVE`]|[0].id' --output text 2>/dev/null)
# prefer the workspace the config stack created (has the cdk-provisioner SA)
for cand in $(aws grafana list-workspaces --region "$RA" --query 'workspaces[?status==`ACTIVE`].id' --output text); do
  SAID=$(aws grafana list-workspace-service-accounts --region "$RA" --workspace-id "$cand" \
    --query "serviceAccounts[?name=='cdk-provisioner'].id|[0]" --output text 2>/dev/null)
  [ -n "$SAID" ] && [ "$SAID" != "None" ] && WSID=$cand && break
done
say "Grafana workspace" "${WSID:-NOT FOUND}"
TOK=$(aws grafana create-workspace-service-account-token --region "$RA" \
  --workspace-id "$WSID" --service-account-id "$SAID" \
  --name "validate-$$" --seconds-to-live 600 \
  --query 'serviceAccountToken.key' --output text 2>/dev/null)
BASE="https://$(aws grafana describe-workspace --region "$RA" --workspace-id "$WSID" \
  --query 'workspace.endpoint' --output text)"
DS_UID=$(curl -s -H "Authorization: Bearer $TOK" "$BASE/api/datasources" \
  | python3 -c "import json,sys; ds=json.load(sys.stdin); print(next((d['uid'] for d in ds if d['type']=='prometheus' and d['url']), ''))")
[ -n "$DS_UID" ] && say "AMP data source exists" "OK (uid $DS_UID)" || bad "AMP data source exists" "none configured"

H=$(curl -s -H "Authorization: Bearer $TOK" "$BASE/api/datasources/uid/$DS_UID/health" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))")
[ "$H" = "OK" ] && say "data source health (Save&Test equivalent)" "OK" \
  || bad "data source health" "$H"

N=$(curl -s -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" \
  -X POST "$BASE/api/ds/query" \
  -d "{\"queries\":[{\"refId\":\"A\",\"datasource\":{\"uid\":\"$DS_UID\"},\"expr\":\"count(up)\",\"instant\":true}],\"from\":\"now-5m\",\"to\":\"now\"}" \
  | python3 -c "
import json,sys
try: print(json.load(sys.stdin)['results']['A']['frames'][0]['data']['values'][-1][-1])
except Exception: print(0)")
[ "${N:-0}" -ge 1 ] 2>/dev/null && say "live count(up) through cross-region path" "OK ($N targets)" \
  || bad "live count(up)" "no data — is the Region B agent shipping? (amp-setup step 5)"

echo
[ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED — end-to-end path verified." \
  || echo "SOME CHECKS FAILED — see HANDBOOK.md troubleshooting table."
exit $FAIL
