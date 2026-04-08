---
title: "Upload files to Amazon s3"
weight: 55
---

You may wish to move files from your hyperpod cluster to an s3 bucket within your account for any number of reasons, including:

* **Data Backup and Recovery**: Storing files in s3 ensures reliable backup and recovery (11 9's of durability for s3 standard Storage).

* **Data Sharing and Collaboration**: S3 enables easy data access and sharing across AWS services, applications, and users, as well as the ability to easily download to an object to a local machine to facilitate collaboration.

1. Add s3 full access IAM Policy to your SageMaker Cluster Execution Role.

Find your cluster execution role in the IAM Console > Roles > YourClusterExecutionRole

![cluster execution role](/img/03-advanced/cluster-execution-role.png)


Add the Amazon Managed Policy "Amazon S3 Full Access" to your cluster exectuion role. **NOTE** will give full permissions for your cluster nodes to access S3 buckets within your account. For more granular access, create a custom policy and just give S3 PUT permissions.

![Amazon S3 Access Policy](/img/03-advanced/s3-full-access.png)


2. Upload the file to your s3 bucket:

```bash
aws s3 cp <your-local-file> s3://your-bucket
```
Congratulations! You can now send files from your cluster nodes directly to an S3 bucket in your account. 

