# Workshop Data Assets

The following large data files are required for the EKS workshop but are NOT stored in this repository due to size constraints.

## ESM2 Training Dataset (UniRef50)

The primary training dataset is ~2 GB, split into 5 parts:

| File | Size |
|------|------|
| `esmdata.tar.part-aa` | 500 MB |
| `esmdata.tar.part-ab` | 500 MB |
| `esmdata.tar.part-ac` | 500 MB |
| `esmdata.tar.part-ad` | 500 MB |
| `esmdata.tar.part-ae` | 39 MB |

To reassemble after download:

```bash
cat esmdata.tar.part-* | tar xf -
```

## Optional: DETR Object Detection Assets

These are only needed if running the optional DETR (object detection) exercise:

| File | Size |
|------|------|
| `supermarket-shelves-dataset.tar.gz` | 131 MB |
| `detr_resnet50_pretrained_complete.pth` | 169 MB |

## Original S3 Location

```
s3://ws-assets-us-east-1/5344c881-4077-471e-aedf-2944bd6fe8eb/
```

## Deployment Instructions

1. Upload these files to your own S3 bucket:

```bash
aws s3 cp esmdata.tar.part-aa s3://YOUR-BUCKET/workshop-data/
aws s3 cp esmdata.tar.part-ab s3://YOUR-BUCKET/workshop-data/
aws s3 cp esmdata.tar.part-ac s3://YOUR-BUCKET/workshop-data/
aws s3 cp esmdata.tar.part-ad s3://YOUR-BUCKET/workshop-data/
aws s3 cp esmdata.tar.part-ae s3://YOUR-BUCKET/workshop-data/
```

2. Configure an FSx for Lustre data repository association to make the data available at `/fsx` on your HyperPod cluster nodes. The CloudFormation templates in `../cloudformation/` handle this automatically when you provide your S3 bucket name as a parameter.
