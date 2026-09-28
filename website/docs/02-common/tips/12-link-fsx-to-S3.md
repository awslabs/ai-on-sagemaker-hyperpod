---
title : "Linking your FSx for Lustre file system to an Amazon S3 bucket"
sidebar_label: "Link FSx to Amazon S3 - Data Repository Association"
sidebar_position: 1
---

## Using AWS Console

Once a filesystem has been created in Amazon FSx, you can now link it to an S3 Bucket. This allows you to sync data back and forth between the filesystem and S3. It also allows you to delete the filesystem and preserve it’s content on S3.

1. Navigate to the [FSx Console](https://console.aws.amazon.com/fsx/home) > Filesystem > Data repositories > Click Create data repository association.

![Create DRA](/img/03-advanced/create-dra.png)

2. Link to an S3 bucket in the same region:

| Field                | Description                                        |
|----------------------|----------------------------------------------------|
| Filesystem Path      | Path of the FSx Filesystem to sync back to S3 i.e. `/`             |
| Data Repository Path | Path on S3 to store synced content i.e. `s3://bucket` |

![Link DRA](/img/03-advanced/link-dra.png)

3. Now you can select your import & export settings:

![DRA Import / Export](/img/03-advanced/import-export.png)

## Using AWS CLI

1. Before creating the association, make sure that the following environmental variables are defined in your terminal environment:

```
export FSX_ID=YOUR_FSX_ID
export AWS_REGION=YOUR_FSX_REGION
export S3_BUCKET=YOUR_S3_BUCKET_NAME
```

2. Now, create a data repository association between your S3 bucket and your FSx for Lustre Filesystem. Before doing this step, please make sure that your FSx Lustre Filesystem is created and available in the region of your preference.

```
aws fsx create-data-repository-association \
    --file-system-id ${FSX_ID} \
    --file-system-path "/hsmtest" \
    --data-repository-path s3://${S3_BUCKET} \
    --s3 AutoImportPolicy='{Events=[NEW,CHANGED,DELETED]},AutoExportPolicy={Events=[NEW,CHANGED,DELETED]}' \
    --batch-import-meta-data-on-create \
    --region ${AWS_REGION}
```

3. You can query the status of the data repository association creation process as below:
```
aws fsx describe-data-repository-associations --filters "Name=file-system-id,Values=${FSX_ID}" --query "Associations[0].Lifecycle" --output text
```

The status is going to be changed from `CREATING` to `AVAILABLE` once the process is finished. It is expected to take few minutes for the process to create the association.
