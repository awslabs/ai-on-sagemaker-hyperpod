---
title: Adding a Data Repository Association
sidebar_position: 6
---

#### Amazon S3 Data Repository Association

You can link your Amazon FSx for Lustre file system to data repositories in Amazon S3. You can create the link when creating the file system or at any time after the file system has been created.

A link between a directory on the file system and an S3 bucket or prefix is called a data repository association ([DRA](https://docs.aws.amazon.com/fsx/latest/LustreGuide/create-dra-linked-data-repo.html)). You can configure a maximum of 8 data repository associations on an FSx for Lustre file system. A maximum of 8 DRA requests can be queued, but only one request can be worked on at a time for the file system. Each DRA must have a unique FSx for Lustre file system directory and a unique S3 bucket or prefix associated with it. The File system path and Data repository path settings provide a 1:1 mapping between paths in Amazon FSx and object keys in S3.

#### 1. Open the [Amazon FSx console.](https://console.aws.amazon.com/fsx)

#### 2. Select File System
From the dashboard, choose File systems and then select the file system that you want to create a data repository association for.

#### 3. Create Data Repository Association
- Choose the Data repository tab.

- In the Data repository associations pane, choose Create data repository association.
![Console Screenshot](/img/01-cluster/dra01-2.png)

- In the Data repository association information dialog, provide information for the following fields.

    a. File system path: `/fsx`

    b. Data repository path: `s3://<<BUCKET-NAME>>`
    -  Please see the S3 console or run `echo $S3_BUCKET_NAME` in the terminal to see the name of your S3 bucket. It should be `hyperpod-eks-bucket-xxx-us-west-2`

    c. Import metadata from repository: Select all to import and export automatically any changes between Amazon S3 bucket and Amazon FSxL filesystem.

    ![Console Screenshot](/img/01-cluster/dra-updated.png)



#### 4. Additional Settings [OPTIONAL]
- For **Import settings** - optional, set an Import Policy that determines how your file and directory listings are kept up to date as you add, change, or delete objects in your S3 bucket. For example, choose New to import metadata to your file system for new objects created in the S3 bucket. For more information about import policies, see Automatically import updates from your S3 bucket.

- For **Export settings**, set an export policy that determines how your files are exported to your linked S3 bucket as you add, change, or delete objects in your file system. For example, choose Changed to export objects whose content or metadata has been changed on your file system. For more information about export policies, see Automatically export updates to your S3 bucket.

#### 5. Choose Create

![Console Screenshot](/img/01-cluster/dra03.png)