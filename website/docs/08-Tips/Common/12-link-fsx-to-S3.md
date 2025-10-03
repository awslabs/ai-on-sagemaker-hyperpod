---
title : "Link FSx Filesystems to Amazon S3 (Data Repository Association)"
weight : 52
---

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
