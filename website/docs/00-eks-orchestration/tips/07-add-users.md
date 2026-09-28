---
title : "Add users to your EKS HyperPod cluster"
weight : 48
---

If you have multiple users trying to get access to your EKS cluster, you would need to set up [IAM Access Entries for EKS](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html). This section details the steps you can use for this purpose. 

:::note{header="Note:"}
There are different IAM entities that you can give access to. This section covers:
1. Granting Direct Access to [IAM users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users.html)
2. Granting Access to assumed [IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html)

Process 2 is recommended as part of [AWS Security Best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#bp-workloads-use-roles). The reason is simple: with IAM roles, you get temporary credentials, so you don’t have to worry about things like stolen credentials, rotating credentials etc. Additionally, you can use roles to give AWS services access to each other. For example, you can have an EC2 instance assume a role to write to S3 buckets — so rather than having a user do that using their credentials, you can use your service credentials. 
:::

## How to get IAM Access Entries for your EKS HyperPod cluster
1. Navigate to your [EKS console](https://us-east-2.console.aws.amazon.com/eks/home?region=us-east-2#/home)
2. Select “Clusters” and choose the hyperlink of your deployed cluster
3. Switch to the “Access” tab
4. Under “IAM access entries”, you’ll see all of your access entries

To get a list of all available access policies for your IAM users and roles, run the following from an admin user account
```bash
aws eks list-access-policies --output table
```
An example output is as follows:
```bash
---------------------------------------------------------------------------------------------------------
|                                          ListAccessPolicies                                           |
+-------------------------------------------------------------------------------------------------------+
||                                           accessPolicies                                            ||
|+---------------------------------------------------------------------+-------------------------------+|
||                                 arn                                 |             name              ||
|+---------------------------------------------------------------------+-------------------------------+|
||  {arn-aws}eks::aws:cluster-access-policy/AmazonEKSAdminPolicy        |  AmazonEKSAdminPolicy         ||
||  {arn-aws}eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy |  AmazonEKSClusterAdminPolicy  ||
||  {arn-aws}eks::aws:cluster-access-policy/AmazonEKSEditPolicy         |  AmazonEKSEditPolicy          ||
||  {arn-aws}eks::aws:cluster-access-policy/AmazonEKSViewPolicy         |  AmazonEKSViewPolicy          ||
|+---------------------------------------------------------------------+-------------------------------+|
```

## 1. Granting Direct Access to IAM users
You can either do this programatically (for adding in multiple users at once), or manually (one user at a time). 

#### Add multiple users in at once (programatically)
On a .txt file, list out all your users, separated by line. For example:
```bash
user1
user2
user3
```
Note: These have to be valid *IAM users*.

Then, run the following on your terminal to write a bash script that will add in users for you. This bash script by default contains the `AmazonEKSClusterAdminPolicy`. Feel free to change that to whatever permission you'd like to give your user(s).

```bash
cat << 'EOF' > add_eks_users.sh
#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <cluster-name> <users-file>"
    echo "Example: $0 my-cluster users.txt"
    exit 1
fi

CLUSTER_NAME=$1
USERS_FILE=$2
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if users file exists
if [ ! -f "$USERS_FILE" ]; then
    echo "Error: Users file $USERS_FILE not found"
    exit 1
fi

# Process each user
while read username; do
    echo "Adding user: $username"
    
    # Create access entry
    aws eks create-access-entry \
        --cluster-name "$EKS_CLUSTER_NAME" \
        --principal-arn "arn:aws:iam::${ACCOUNT_ID}:user/${username}" \
        --type "STANDARD"

    # Associate admin policy
    aws eks associate-access-policy \
        --cluster-name "$EKS_CLUSTER_NAME" \
        --principal-arn "arn:aws:iam::${ACCOUNT_ID}:user/${username}" \
        --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
        --access-scope '{"type": "cluster"}'

    echo "Successfully added user $username to cluster $EKS_CLUSTER_NAME"
done < "$USERS_FILE"

echo "All users have been added to the cluster!"
EOF

chmod +x add_eks_users.sh
```

You can then run this script!
```bash
# Example
./add_eks_users.sh example_cluster users.txt
```

#### Add users in one at a time (manually)
1. On your IAM console, navigate to your users
2. Select the hyperlink of user you’d like to give access to your EKS cluster
3. On there, grab the ARN of that user. It should look something like `arn:aws:iam::<account id>:user/<user name>`
4. Switch over to your IAM Access Entries tab and hit “Create access entry”
5. For IAM principal ARN, paste in the ARN of the IAM user you grabbed earlier
6. You can leave Type as Standard
7. On the next page, under Policy name select the most relevant policy for the user. If you’d like to give them admin access to your cluster, select `AmazonEKSClusterAdminPolicy`.
8. Select the scope of access for that user (i.e., entire cluster vs a namespace)
9. Review and Create!
10. You’ll have to do this for every user that you want to add. 

## 2. Granting Access to IAM roles
1. On your [IAM console](https://us-east-1.console.aws.amazon.com/iam/home?region=us-east-2#/policies), navigate to your policies
2. **[One time step]** Hit Create policy -- these instructions describe adding full Admin permissions to EKS. Modify this accordingly. 
    1. Select “Visual” (default) for your policy editor, and choose "EKS" for "Service".
    2. Once you select EKS, hit the check box for "All EKS actions (eks *)".  Under "Resources", select "All".
    3. On the next page, name your policy `EKSFullAccessPolicy`
    4. Hit Create policy. 
3. **[One time step]** Navigate to roles, and hit Create role
    1. Select “AWS account” to allow your users to assume this role. Note: this means that only people using your account will be able to assume the role. 
    2. On the next page, select the newly created `EKSFullAccessPolicy`
    3. Name the role `EKSFullAccessRole` and add in a description.
    4. Hit "Create role". Grab the `ARN` of the role. It should looks something like `arn:aws:iam::<account id>:role/<role name>`
4. Now, your users can assume this role, and you’ll only be managing a single EKS access entry! First things first, add this role in as an access entry. 
    1. Navigate to your Access Entries page and hit “Create access entry”
    2. For IAM principal ARN, paste in the ARN of the *IAM role* you grabbed earlier
    3. You can leave Type as "Standard".
    4. On the next page, under Policy name select the most relevant policy for the user. If you’d like to give them admin access to your cluster, select `AmazonEKSClusterAdminPolicy`.
    5. Select the scope of access for that user (i.e., entire cluster vs a namespace)
    6. Review and Create!

:::::note{header="Note:"}
How can a user assume this role?
1. As a configured user in the account where the EKS cluster is added, run `aws sts assume-role —role-arn <role arn you grabbed earlier> —role-session-name <anything you want to name your session>`
2. This will return an `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`. Copy these and set them as environment variables like `export AWS_ACCESS_KEY_ID=ABCD1234`.
3. Remember these are temporary credentials. This is a faster admin set up, but your user may need to restart their sessions by running the `sts` command. 
:::::