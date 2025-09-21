import json
import boto3
import cfnresponse

ec2 = boto3.client('ec2')

def lambda_handler(event, context):              
    if 'RequestType' in event and event['RequestType'] == 'Create':
        vpc_id = get_default_vpc_id()
        cidr_block = get_cidr_block(vpc_id)
        subnet_id =  get_subnets_for_vpc(vpc_id)
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {'VpcId': vpc_id , "SubnetId" : subnet_id, "CidrBlock": cidr_block}, '')
    else:
        cfnresponse.send(event, context, cfnresponse.SUCCESS, {},'')

def get_default_vpc_id():
    vpcs = ec2.describe_vpcs(Filters=[{'Name': 'is-default', 'Values': ['true']}])
    vpcs = vpcs['Vpcs']
    vpc_id = vpcs[0]['VpcId']
    return vpc_id


def get_subnets_for_vpc(vpcId):
    response = ec2.describe_subnets(
        Filters=[
            {
                'Name': 'vpc-id',
                'Values': [vpcId]
            }
        ]
    )
    subnet_id = [subnet['SubnetId'] for subnet in response['Subnets'] if subnet.get('AvailabilityZoneId') == 'use1-az5']
    return subnet_id[0]

def get_cidr_block(vpcId):
    vpcs = ec2.describe_vpcs(Filters=[{'Name': 'is-default', 'Values': ['true']}])
    cidr_block = vpcs['Vpcs'][0]['CidrBlock']
    return cidr_block

vpc_id = get_default_vpc_id()
cidr_block = get_cidr_block(vpc_id)
subnet_id =  get_subnets_for_vpc(vpc_id)
print({'VpcId': vpc_id , "SubnetId" : subnet_id, "CidrBlock": cidr_block})