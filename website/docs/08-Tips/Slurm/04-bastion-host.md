---
title : "Bastion Host"
weight : 44
---

> Ok so what if we want to access our cluster with *normal ssh* and not ssm?

To do that we need to use a bastion host, this host runs in the same VPC as your filesystem however it's in the *Public Subnet* so that you can SSH into the host.

Make sure you're in your *Local Environment*:

```bash
exit # exit the cluster to local environment
```

1. Spin up a new t3 instance running *Ubuntu 20.04* in the *Public Subnet* we created in [0. Prerequisites](/docs/00-getting-started/orchestrated-by-slurm/initial-cluster-setup.md):

```bash
# create keypair if it doesn't exist and import it
if [ -f $HOME/.ssh/id_rsa.pub ]; then
    aws ec2 import-key-pair --key-name ssh_key --public-key-material fileb://$HOME/.ssh/id_rsa.pub
else
    ssh-keygen -t rsa -q -f "$HOME/.ssh/id_rsa" -N ""
    aws ec2 import-key-pair --key-name ssh_key --public-key-material fileb://$HOME/.ssh/id_rsa.pub
fi

source env_vars
ubuntu_ami=$(aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id | jq '.Parameters[0].Value' | tr -d '"')

# launch the instance
aws ec2 run-instances \
    --image-id ${ubuntu_ami} \
    --instance-type t3.small \
    --key-name ssh_key \
    --security-group-ids ${SECURITY_GROUP} \
    --subnet-id ${PUBLIC_SUBNET_ID} \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bastion}]'
```

2. Next add this jump host info to your `~/.ssh/config`

```bash
# grab the public ip from the following command:
public_ip=$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=bastion' --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)

# add the hostname to the ~/.ssh/config
cat <<EOF >> ~/.ssh/config
Host bastion
  User ubuntu
  Hostname ${public_ip}
EOF
```

Next modify your security group to allow SSH traffic:

```bash
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP} \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/32
```

Confirm that you can ssh in:

```bash
ssh bastion
# then exit back to local environment
exit
```

3. Next we're going to mount the `/fsx` filesystem from the cluster, in order to do this we'll need to first [install Lustre client](https://docs.aws.amazon.com/fsx/latest/LustreGuide/install-lustre-client.html#lustre-client-ubuntu):

```bash
wget -O - https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-ubuntu-public-key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/fsx-ubuntu-public-key.gpg >/dev/null
sudo bash -c 'echo "deb [signed-by=/usr/share/keyrings/fsx-ubuntu-public-key.gpg] https://fsx-lustre-client-repo.s3.amazonaws.com/ubuntu focal main" > /etc/apt/sources.list.d/fsxlustreclientrepo.list && apt-get update'
sudo apt install -y lustre-client-modules-$(uname -r)
```

4. Next, navigate to the [FSx Console](https://console.aws.amazon.com/fsx/home?) and click on your fsx filesystem. Click attach to get the mount commands. They will look similar to the following:

```
sudo mkdir /fsx
sudo mount -t lustre -o relatime,flock fs-007d09da6ab2684eg.fsx.us-west-2.amazonaws.com@tcp:/4gb3nbem /fsx
```

5. Next we need to re-map `ubuntu` to `/fsx/ubuntu` so we can ssh directly into the bastion:

```bash
# allow ssh to root user temporarily:
sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys
exit # go back to local machine
# ssh into root directly
ssh root@bastion
# move the directory to the fsx directory, this adds the correct ssh key to access the cluster:
usermod -d /fsx/ubuntu ubuntu
rm /root/.ssh/authorized_keys
exit
```

6. Next add the cluster's private ip address to your local ssh config. To do this we'll connect to the cluster and grab the ip address then exit and add it to our *local* ~/.ssh/config.

```bash
# grab the private ip address:
Admin:~ $ ./easy-ssh.sh -c controller-machine ml-cluster
....
root@ip-10-1-100-227:/usr/bin# hostname -I
10.1.84.107 169.254.0.1
root@ip-10-1-100-227:/usr/bin# exit

# add the ip to the ~/.ssh/config where 10.1.84.107 is the ip from hostname -I
cat <<EOF >> ~/.ssh/config
Host ml-cluster
  User ubuntu
  Hostname 10.1.84.107
EOF
```

5. Now we can ssh into this host and use it as a jump host with the command:

```bash
ssh -J bastion ml-cluster
```

Voila! in the next section we'll show an alternate way to use SSM to connect similar to SSH.