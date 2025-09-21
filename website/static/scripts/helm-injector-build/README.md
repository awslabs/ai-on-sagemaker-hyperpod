# Helm Injector Build 

## Directory Structure

```bash
.
├── README.md                         <-- this instructions file
├── deploy.sh                         <-- main bash script to kick off a new build
├── run-docker-build.md               <-- sub-script that builds the Lambda layer using Docker
├── Dockerfile                        <-- used to deploy a local AL23 container for layer building
├── build-layer.sh                    <-- script to install kubectl, helm, and aws-iam-authenticator
├── package-function.sh               <-- sub-script to pip install lambda dependencies and zip it up
└── lambda_function                   <-- sub-directory for lambda function code an requirements
    └── lambda_function.py            <-- lambda function code
    └── requirements.txt              <-- lambda function requirements
```

## Executing a build of the Helm Injector Lambda
```bash 
## execute the main script
./deploy.sh 

## navigate to root
cd ../../../

## set creds from Workshop Studio console (click the Credentials button)
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCESS_KEY_ID="........."
export AWS_SECRET_ACCESS_KEY="........."
export AWS_SESSION_TOKEN="........."

## Sync function.zip and lambda-layer.zip with S3 bucket for the Workshop
aws s3 sync ./assets s3://ws-assets-us-east-1/2433d39e-ccfe-4c00-9d3d-9917b729258e --delete
```