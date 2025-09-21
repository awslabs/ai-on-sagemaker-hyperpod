#!/bin/bash
# deploy.sh

# Set your bucket name
# BUCKET_NAME=ws-assets-us-east-1/2433d39e-ccfe-4c00-9d3d-9917b729258e

# Create a directory for the output
mkdir -p output

# Build the Lambda layer using Docker
./run-docker-build.sh

# Package the Lambda function with dependencies
./package-function.sh

# Upload both ZIPs to S3
# aws s3 cp output/lambda-layer.zip s3://${BUCKET_NAME}/lambda-layer.zip
# aws s3 cp output/function.zip s3://${BUCKET_NAME}/function.zip

cp output/* ../../../assets/
