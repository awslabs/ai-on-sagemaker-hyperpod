#!/bin/bash -x

# Set up logging
exec > >(tee /var/log/user-data-script.log|logger -t user-data-script -s 2>/dev/console) 2>&1
echo "Starting management instance setup..."

echo "Debug environment variables:"
echo "REGION: $AWSRegion"
echo "BUCKET: $BucketName"
echo "EKS Cluster: $EKSClusterName"
echo "EC2InstanceWaiter: $EC2InstanceWaiter"
echo "SUBNET: $PrivateSubnetId"
echo "SECURITY_GROUP: $SecurityGroupId"
echo "PreDeployGPUInstances: $PreDeployGPUInstances"

# Function to signal failure and exit
# The cfn-signal wrapper at /opt/aws/bin/cfn-signal is created by the UserData
# before this script is invoked, so it is always available.
function signal_failure {
  echo "ERROR: $1"
  /opt/aws/bin/cfn-signal -e 1 -r "$1" "$EC2InstanceWaiter"
  exit 1
}

# Format and mount the 500GB EBS data volume
echo "Setting up data volume..."
lsblk

# Find the largest non-root disk (the 500GB EBS volume)
ROOT_DEVICE=$(lsblk -no PKNAME $(findmnt -n -o SOURCE /) | head -1)
echo "Root device is: $ROOT_DEVICE"
DATA_DEVICE=$(lsblk -dnb -o NAME,SIZE,TYPE | grep disk | grep -v "$ROOT_DEVICE" | sort -k2 -nr | head -1 | awk '{print $1}')
echo "Selected data device: $DATA_DEVICE"

if [ -n "$DATA_DEVICE" ]; then
  if ! mount | grep -q "/dev/$DATA_DEVICE"; then
    echo "Formatting /dev/$DATA_DEVICE..."
    mkfs -t ext4 /dev/$DATA_DEVICE || signal_failure "Failed to format /dev/$DATA_DEVICE"
    mkdir -p /data
    mount /dev/$DATA_DEVICE /data || signal_failure "Failed to mount /dev/$DATA_DEVICE to /data"
    echo "/dev/$DATA_DEVICE /data ext4 defaults 0 0" >> /etc/fstab
    echo "Mounted /dev/$DATA_DEVICE to /data ($(lsblk -dnb -o SIZE /dev/$DATA_DEVICE | awk '{printf "%.0fGB", $1/1024/1024/1024}'))"
  else
    echo "/dev/$DATA_DEVICE is already mounted"
  fi
else
  echo "WARNING: No separate data device found, using root volume for /data"
  mkdir -p /data
fi

# Set up directories on the data volume
mkdir -p /data/docker /data/tmp /data/venv
chmod 1777 /data/tmp

# Set environment variables to use the data volume for temporary files
export TMPDIR=/data/tmp
echo "export TMPDIR=/data/tmp" >> /etc/environment

# Re-activate the venv created by UserData (or create if not present)
if [ -f /data/venv/bin/activate ]; then
  echo "Activating existing venv..."
  . /data/venv/bin/activate
else
  echo "Creating venv..."
  apt-get update
  apt-get install -y python3-venv python3-full
  python3 -m venv /data/venv
  . /data/venv/bin/activate
  pip install --upgrade pip setuptools
fi

# Install required packages
echo "Installing required packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-dev gcc jq git curl apt-transport-https ca-certificates gnupg lsb-release unzip

KUBECTL_VERSION="v1.32.0"
curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mv ./kubectl /usr/local/bin
kubectl version --client

# Install eksctl
echo "Installing eksctl..."
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl

# Install helm
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# AWS CLI is already installed by UserData, verify it's available
echo "Verifying AWS CLI..."
aws --version || signal_failure "AWS CLI not available"

# Configure kubectl for EKS
echo "Configuring kubectl for EKS..."
aws eks update-kubeconfig --name $EKSClusterName --region $AWSRegion

echo "IDENTITY:"
aws sts get-caller-identity

export KUBECONFIG=/root/.kube/config
echo "export KUBECONFIG=/root/.kube/config" >> /etc/environment

# Get the EKS cluster endpoint
echo "Getting EKS cluster endpoint..."
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $EKSClusterName --region $AWSRegion --query "cluster.endpoint" --output text)
echo "Cluster endpoint: $CLUSTER_ENDPOINT"

# Debug: Checking if cluster is accessible
echo "Testing connectivity to the cluster..."
kubectl get ns || echo "Warning: Could not connect to cluster, but continuing anyway"
kubectl --server=$CLUSTER_ENDPOINT get nodes || echo "Warning: Could not connect to cluster, but continuing anyway"

# Install Lustre client
echo "Kernel: $(uname -r)"
wget -O - https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-ubuntu-public-key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/fsx-ubuntu-public-key.gpg >/dev/null
bash -c 'echo "deb [signed-by=/usr/share/keyrings/fsx-ubuntu-public-key.gpg] https://fsx-lustre-client-repo.s3.amazonaws.com/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/fsxlustreclientrepo.list && apt-get update'
# Try original installation first
if ! apt install -y lustre-client-modules-$(uname -r); then
    echo "Initial Lustre client installation failed, trying with --fix-missing"
    if ! apt install --fix-missing -y lustre-client-modules-$(uname -r); then
        signal_failure "Failed to install Lustre client modules"
    fi
fi
echo "Lustre client installed with version: $(modinfo lustre | grep 'version:' | head -n 1 | awk '{print $2}')" || true

# Setup Docker for ECR
echo "Setting up Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker

# Configure Docker to use the data volume (EBS)
mkdir -p /etc/docker
mkdir -p /data/docker   # Move directory creation up here to use EBS for Docker.
docker system prune -af || true 
echo '{"data-root": "/data/docker"}' > /etc/docker/daemon.json
systemctl restart docker
# Verify docker is using the correct data directory
docker info | grep -i "Docker Root Dir"

# Configure containerd to use the data volume as well
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml << EOF
version = 2
root = "/data/containerd"
state = "/data/containerd/state"

[grpc]
  address = "/run/containerd/containerd.sock"

[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"

[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
EOF

# Create containerd directories on EBS
mkdir -p /data/containerd /data/containerd/state

# Restart containerd and docker
systemctl restart containerd
systemctl restart docker

python3 -m pip install --no-cache-dir --ignore-installed accelerate==0.32.1 datasets==2.20.0 pyfastx==2.1.0 transformers==4.42.4 boto3==1.34.144 huggingface_hub==0.23.4 chardet==5.2.0 evaluate==0.4.3 scikit-learn==1.5.1 tqdm transformers requests

# Setup ESM2 environment
echo "Pushing Image to ECR..."

export DOCKER_IMAGE_NAME=esm
export TAG=aws
export AWS_REGION=$AWSRegion
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY=$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/

# Create a temporary directory for Docker build
mkdir -p /data/docker-build
cd /data/docker-build

# Download files from S3
echo "Downloading files from S3..."
curl -f -o train.py https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/train.py || signal_failure "Failed to download train.py script"
curl -f -o requirements.txt https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/requirements.txt || signal_failure "Failed to download requirements.txt script"
curl -f -o Dockerfile https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/Dockerfile || signal_failure "Failed to download Dockerfile"

# Build and push Docker image
echo "Building and pushing Docker image..."
if command -v docker &> /dev/null; then
  # Build image. Clean first. 
  echo "Available disk space on /data:"
  df -Th /data
  docker system prune -af || true 
  docker build -t $REGISTRY$DOCKER_IMAGE_NAME:$TAG . || signal_failure "Docker build failed"
  # Login to ECR
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY || signal_failure "ECR login failed"
  # Create ECR repository if it doesn't exist
  aws ecr describe-repositories --repository-names $DOCKER_IMAGE_NAME --region $AWS_REGION || \
  aws ecr create-repository --repository-name $DOCKER_IMAGE_NAME --region $AWS_REGION
  # Push image
  docker push $REGISTRY$DOCKER_IMAGE_NAME:$TAG
  echo "Docker image built and pushed successfully"
else
  signal_failure "Docker not available, skipping image build"
fi

# DETR-Resnet50 Docker build - DISABLED (NCCL version mismatch with torch>=2.9 on nccl-tests base image)
# To re-enable, uncomment below and ensure Dockerfile.detr pins a compatible torch version.
# echo "################### DETR-RESNET50 #################"
#
# export DOCKER_IMAGE_NAME=detr-resnet50
# export TAG=aws
# export AWS_REGION=$AWSRegion
# export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
# export REGISTRY=$ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/
#
# # Create a temporary directory for Docker build
# mkdir -p /data/docker-build-detr
# cd /data/docker-build-detr
#
# # Download files from S3
# echo "Downloading files from S3..."
# curl -f -o detr_main.py https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/detr_main.py || signal_failure "Failed to download detr_main.py script"
# curl -f -o Dockerfile.detr https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/Dockerfile.detr || signal_failure "Failed to download Dockerfile.detr"
#
# # Build and push Docker image
# echo "Building and pushing Docker image..."
# if command -v docker &> /dev/null; then
#   # Build image. Clean first. 
#   echo "Available disk space on /data:"
#   df -Th /data
#   docker system prune -af || true 
#   docker build -t $REGISTRY$DOCKER_IMAGE_NAME:$TAG -f Dockerfile.detr . || signal_failure "Docker build failed"
#   # Login to ECR
#   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY || signal_failure "ECR login failed"
#   # Create ECR repository if it doesn't exist
#   aws ecr describe-repositories --repository-names $DOCKER_IMAGE_NAME --region $AWS_REGION || \
#   aws ecr create-repository --repository-name $DOCKER_IMAGE_NAME --region $AWS_REGION
#   # Push image
#   docker push $REGISTRY$DOCKER_IMAGE_NAME:$TAG
#   echo "Docker image for detr-resnet50 built and pushed successfully"
# else
#   signal_failure "Docker not available, skipping image build"
# fi

# Install FSx CSI Driver
echo "Installing FSx CSI Driver..."

# Create OIDC provider for EKS
echo "Setting up OIDC provider for EKS..."
eksctl utils associate-iam-oidc-provider --cluster $EKSClusterName --approve

# Install FSx CSI Driver using Helm
echo "Installing FSx CSI Driver using Helm..."
helm repo add aws-fsx-csi-driver https://kubernetes-sigs.github.io/aws-fsx-csi-driver/
helm repo update

helm upgrade --install aws-fsx-csi-driver aws-fsx-csi-driver/aws-fsx-csi-driver --namespace kube-system

# Create service account for FSx CSI Driver
echo "Creating service account for FSx CSI Driver..."
eksctl create iamserviceaccount \
  --name fsx-csi-controller-sa \
  --namespace kube-system \
  --cluster $EKSClusterName \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonFSxFullAccess \
  --approve \
  --role-name AmazonEKSFSxLustreCSIDriverFullAccess \
  --override-existing-serviceaccounts --region $AWSRegion || echo "WARNING: FSx CSI service account may already exist, continuing..."

# Get the role ARN and annotate the service account
echo "Annotating service account with IAM role..."
SA_ROLE_ARN=$(aws iam get-role --role-name AmazonEKSFSxLustreCSIDriverFullAccess --query 'Role.Arn' --output text)
kubectl annotate serviceaccount -n kube-system fsx-csi-controller-sa \
  eks.amazonaws.com/role-arn=$SA_ROLE_ARN --overwrite=true

# Restart the FSx CSI controller deployment to pick up the new service account annotation
echo "Restarting FSx CSI controller deployment..."
kubectl rollout restart deployment fsx-csi-controller -n kube-system

# Setup fsx env vars
export FILESYSTEM_ID=$(aws fsx describe-file-systems --query "FileSystems[0].FileSystemId" --output text)
export FILESYSTEM_DNS=$(aws fsx describe-file-systems --file-system-id $FILESYSTEM_ID --query "FileSystems[0].DNSName" --output text)
export FILESYSTEM_MOUNT=$(aws fsx describe-file-systems --file-system-id $FILESYSTEM_ID --query "FileSystems[0].LustreConfiguration.MountName" --output text)

CURRENT_USER=$(whoami)

# Create mount point
echo "Creating mount point..."
mkdir -p /mnt/fsx

# Wait for FSx for Lustre file system to be available
echo "Waiting for FSx for Lustre file system to be available..."
# Wait until the file system is available
while true; do
  status=$(aws fsx describe-file-systems --file-system-id $FILESYSTEM_ID --region $AWSRegion --query 'FileSystems[0].Lifecycle' --output text)
  echo "FSx for Lustre file system status: $status"
  if [ "$status" = "AVAILABLE" ]; then
    break
  fi
  sleep 30
done

echo "FSx Mount Name: $FILESYSTEM_MOUNT"
# Mount FSx for Lustre with the correct mount name
echo "Mounting FSx for Lustre file system..."
mount -v -t lustre -o noatime,flock $FILESYSTEM_DNS@tcp:/$FILESYSTEM_MOUNT /mnt/fsx

# Check if mount was successful
if mount | grep -q "/mnt/fsx"; then
  echo "Mount successful!"
  df -h | grep "/mnt/fsx"
else
  echo "Mount failed! Trying alternative approach..."
  # Try alternative mount syntax without options
  mount -v -t lustre $FILESYSTEM_DNS@tcp:/$FILESYSTEM_MOUNT /mnt/fsx

  if mount | grep -q "/mnt/fsx"; then
    echo "Alternative mount successful!"
    df -h | grep "/mnt/fsx"
  else
    echo "All mount attempts failed!"
    signal_failure "Failed to mount FSx Lustre filesystem"
  fi
fi

echo "################################### Writing env_vars to file system #########################"
# export STACK_ID=hyperpod-eks-full-stack

mkdir -p /mnt/fsx/shared/

## Download and run the config creation script. 
# curl -O https://ws-assets-prod-iad-r-pdx-f3b3f9f1a7d6a3d0.s3.us-west-2.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/create_config.sh
# chmod +x create_config.sh
# ./create_config.sh

# mv env_vars /mnt/fsx/shared/env_vars

# Clear previously set env_vars
touch /mnt/fsx/shared/env_vars
> /mnt/fsx/shared/env_vars 

# Create env_vars file directly with available parameters
cat > /mnt/fsx/shared/env_vars << EOF
export AWS_REGION=${AWSRegion}
export EKS_CLUSTER_NAME=${EKSClusterName}
export PRIVATE_SUBNET_ID=${PrivateSubnetId}
export SECURITY_GROUP_ID=${SecurityGroupId}
export S3_BUCKET_NAME=${BucketName}
EOF

# Get EKS cluster ARN
export EKS_CLUSTER_ARN=$(aws eks describe-cluster --name ${EKSClusterName} --region ${AWSRegion} --query 'cluster.arn' --output text)
echo "export EKS_CLUSTER_ARN=${EKS_CLUSTER_ARN}" >> /mnt/fsx/shared/env_vars

# Get VPC ID from EKS cluster
export VPC_ID=$(aws eks describe-cluster --name ${EKSClusterName} --region ${AWSRegion} --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "export VPC_ID=${VPC_ID}" >> /mnt/fsx/shared/env_vars

# Get execution role from HyperPod cluster
export HYPERPOD_CLUSTER_NAME=$(aws sagemaker list-clusters --region ${AWSRegion} | jq -r '.ClusterSummaries[0].ClusterName')
export EXECUTION_ROLE=$(aws sagemaker describe-cluster --cluster-name $HYPERPOD_CLUSTER_NAME --region ${AWSRegion} --query 'InstanceGroups[0].ExecutionRole' --output text)
echo "export EXECUTION_ROLE=${EXECUTION_ROLE}" >> /mnt/fsx/shared/env_vars

# Get the actual instance type from the HP cluster
export INSTANCE_TYPE=$(aws sagemaker describe-cluster --cluster-name $HYPERPOD_CLUSTER_NAME --region ${AWSRegion} \
  --query 'InstanceGroups[?contains(InstanceGroupName, `accelerated`)] | [0].InstanceType' --output text)
echo "export INSTANCE_TYPE=${INSTANCE_TYPE}" >> /mnt/fsx/shared/env_vars

# Set Docker network flag for SageMaker Code Editor
echo "export DOCKER_NETWORK=\"--network sagemaker\"" >> /mnt/fsx/shared/env_vars


# Add workshop specific env_vars
echo "export TARGET_PATH=/fsx/esm" >> /mnt/fsx/shared/env_vars
echo "export DOCKER_IMAGE_NAME=esm" >> /mnt/fsx/shared/env_vars
echo "export TAG=aws" >> /mnt/fsx/shared/env_vars
echo "export MODEL=facebook/esm2_t6_8M_UR50D" >> /mnt/fsx/shared/env_vars

# Get AWS Account ID
export ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo "export ACCOUNT=${ACCOUNT}" >> /mnt/fsx/shared/env_vars
echo "export REGISTRY=\${ACCOUNT}.dkr.ecr.\${AWS_REGION}.amazonaws.com/" >> /mnt/fsx/shared/env_vars

# Get GPU and EFA information from the cluster INSTANCE_TYPE
# This is all for GPU instances of the g family, depending on capacity. 
case "$INSTANCE_TYPE" in
  ml.g5.xlarge|ml.g5.2xlarge|ml.g5.4xlarge)
    GPU_PER_NODE=1
    EFA_PER_NODE=0
    ;;
  ml.g5.8xlarge|ml.g5.16xlarge)
    GPU_PER_NODE=1
    EFA_PER_NODE=1
    ;;
  ml.g5.12xlarge|ml.g5.24xlarge)
    GPU_PER_NODE=4
    EFA_PER_NODE=1
    ;;
  ml.g5.48xlarge)
    GPU_PER_NODE=8
    EFA_PER_NODE=1
    ;;
  ml.p4d.24xlarge|ml.p4de.24xlarge)
    GPU_PER_NODE=8
    EFA_PER_NODE=4
    ;;
  ml.p5.48xlarge)
    GPU_PER_NODE=8
    EFA_PER_NODE=32
    ;;
  *)
    GPU_PER_NODE=1
    EFA_PER_NODE=0
    ;;
esac

echo "export GPU_PER_NODE=${GPU_PER_NODE}" >> /mnt/fsx/shared/env_vars
echo "export EFA_PER_NODE=${EFA_PER_NODE}" >> /mnt/fsx/shared/env_vars

# Get number of nodes from HyperPod cluster (worker group)
export NUM_NODES=$(aws sagemaker describe-cluster --cluster-name $HYPERPOD_CLUSTER_NAME --region ${AWSRegion} \
  --query 'InstanceGroups[?contains(InstanceGroupName, `accelerated`)] | [0].CurrentCount' --output text)
echo "export NUM_NODES=${NUM_NODES}" >> /mnt/fsx/shared/env_vars

# Calculate total GPUs
export TOTAL_GPUS=$((NUM_NODES * GPU_PER_NODE))
echo "export TOTAL_GPUS=${TOTAL_GPUS}" >> /mnt/fsx/shared/env_vars

# Add output and dataset directories
echo "export OUTPUT_DIR=/fsx/esm/output" >> /mnt/fsx/shared/env_vars
echo "export DATASET_DIR=/fsx/arrow" >> /mnt/fsx/shared/env_vars

chmod 666 /mnt/fsx/shared/env_vars
echo "Workshop environment variables written to /mnt/fsx/shared/env_vars"
cat /mnt/fsx/shared/env_vars

# Set TARGET_PATH
TARGET_PATH="/mnt/fsx/esm"
mkdir -p $TARGET_PATH
sudo chown -R $CURRENT_USER:$CURRENT_USER $TARGET_PATH

# DETR FSx directories - DISABLED
# TARGET_PATH_2="/mnt/fsx/detr"
# mkdir -p $TARGET_PATH_2/data $TARGET_PATH_2/checkpoint $TARGET_PATH_2/checkpoint_ready
# sudo chown -R $CURRENT_USER:$CURRENT_USER $TARGET_PATH_2

# Download Python scripts from S3
# echo "Downloading Python scripts from S3..."
# curl -f -o /data/download_data.py https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/0.download_data.py || signal_failure "Failed to download download_data.py script"
# curl -f -o /data/tokenize_uniref_csv.py https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/1.tokenize_uniref_csv.py || signal_failure "Failed to download tokenize_uniref_csv.py script"

# Run the data download and processing
echo "Running data download and processing..."

# echo "Step 1: Downloading data..."
# # Modify the download script to use the data volume for temporary files
# sed -i 's|/tmp|/data/tmp|g' /data/download_data.py
# if ! python3 /data/download_data.py --output_dir $TARGET_PATH; then
#   echo "Error: Data download failed"
#   /opt/aws/bin/cfn-signal -e 1 -r "Data download failed" "$EC2InstanceWaiter"
#   exit 1
# fi

# Set up environment variables for Hugging Face datasets to use the data volume
export TMPDIR=/data/tmp
export HF_HOME=/data/huggingface
export HF_DATASETS_CACHE=/data/datasets_cache
export TRANSFORMERS_CACHE=/data/transformers_cache

# Create necessary directories
mkdir -p /data/huggingface /data/datasets_cache /data/transformers_cache

# echo "Step 2: Tokenizing data..."
# if ! TMPDIR=/data/tmp python3 /data/tokenize_uniref_csv.py --input_dir $TARGET_PATH/csv --output_dir $TARGET_PATH/processed; then
#   echo "Error: Data tokenization failed"
#   /opt/aws/bin/cfn-signal -e 1 -r "Data tokenization failed" "$EC2InstanceWaiter"
#   exit 1
# fi

# wget -c -P /mnt/fsx/esm/processed/arrow/ "https://smhp-ws-assets.s3.us-west-2.amazonaws.com/tarball/esmdata.tar.gz"
# aws s3 cp s3://smhp-ws-assets/tarball/esmdata.tar.gz /mnt/fsx/esmdata.tar.gz --no-sign-request
curl -f -o /mnt/fsx/esmdata.tar.part-aa https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/esmdata.tar.part-aa || signal_failure "Failed to download esmdata.tar.part-aa script"
curl -f -o /mnt/fsx/esmdata.tar.part-ab https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/esmdata.tar.part-ab || signal_failure "Failed to download esmdata.tar.part-ab script"
curl -f -o /mnt/fsx/esmdata.tar.part-ac https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/esmdata.tar.part-ac || signal_failure "Failed to download esmdata.tar.part-ac script"
curl -f -o /mnt/fsx/esmdata.tar.part-ad https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/esmdata.tar.part-ad || signal_failure "Failed to download esmdata.tar.part-ad script"
curl -f -o /mnt/fsx/esmdata.tar.part-ae https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/esmdata.tar.part-ae || signal_failure "Failed to download esmdata.tar.part-ae script"

# Copy the supermarketshelf data and pretrained model from the asset bucket - DISABLED
# curl -f -o /mnt/fsx/supermarket-shelves-dataset.tar.gz https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/supermarket-shelves-dataset.tar.gz || signal_failure "Failed to download supermarket-shelf-dataset.tar.gz data"
# curl -f -o $TARGET_PATH_2/checkpoint_ready/detr_resnet50_pretrained_complete.pth https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/detr_resnet50_pretrained_complete.pth || signal_failure "Failed to download detr-resnet50 pretrained model"

pushd /mnt/fsx/
cat esmdata.tar.part-* > esmdata.tar
tar -xzf /mnt/fsx/esmdata.tar
# tar -xzf /mnt/fsx/supermarket-shelves-dataset.tar.gz -C ${TARGET_PATH_2}/data --strip-components=0
# sudo chown -R $CURRENT_USER:$CURRENT_USER $TARGET_PATH_2
popd
# /mnt/fsx/esm/processed/arrow/ should have train,val,etc


# Test FSx CSI Driver

# Create StorageClass for FSx
echo "Creating StorageClass for FSx..."
cat > storageclass.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fsx-sc
provisioner: fsx.csi.aws.com
parameters:
  fileSystemId: $FILESYSTEM_ID
  subnetId: $PrivateSubnetId
  securityGroupIds: $SecurityGroupId
EOF

kubectl apply -f storageclass.yaml

# Create PV for existing FSx
echo "Creating PV for existing FSx..."
cat > pv.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: fsx-pv
spec:
  capacity:
    storage: 1200Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: fsx-sc
  csi:
    driver: fsx.csi.aws.com
    volumeHandle: $FILESYSTEM_ID  # Your FSx file system ID
    volumeAttributes:
      dnsname: $FILESYSTEM_DNS  # Your FSx file system DNS name
      mountname: $FILESYSTEM_MOUNT  # Your FSx file system mountname
EOF
kubectl apply -f pv.yaml

# Create PVC for FSx
echo "Creating PVC for FSx..."
cat > pvc.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fsx-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: fsx-sc
  resources:
    requests:
      storage: 1200Gi
EOF
kubectl apply -f pvc.yaml



# export DOCKER_IMAGE_NAME_RAY=ray
# curl -f -o Dockerfile.ray https://$BucketName.s3.$AWSRegion.amazonaws.com/5344c881-4077-471e-aedf-2944bd6fe8eb/Dockerfile.ray || signal_failure "Failed to download Dockerfile.ray"
# # Build and push Docker image
# echo "Building and pushing Ray Docker image..."
# if command -v docker &> /dev/null; then
#   # Build image
#   docker build -f Dockerfile.ray -t $REGISTRY$DOCKER_IMAGE_NAME_RAY:$TAG . || signal_failure "Ray Docker build failed"

#   # Login to ECR
#   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY || signal_failure "ECR login failed"

#   # Create ECR repository if it doesn't exist
#   aws ecr describe-repositories --repository-names $DOCKER_IMAGE_NAME_RAY --region $AWS_REGION || \
#   aws ecr create-repository --repository-name $DOCKER_IMAGE_NAME_RAY --region $AWS_REGION

#   # Push image
#   docker push $REGISTRY$DOCKER_IMAGE_NAME_RAY:$TAG

#   echo "Docker image built and pushed successfully"
# else
#   signal_failure "Ray Docker not available, skipping image build"
# fi


# Installing HyperPod Training Operator
echo "Installing HyperPod Training Operator..."

# echo "Installing cert manager"
#kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.yaml
#sleep 5
echo "Attaching policy for AssumeRoleForPodIdentity permission to your execution role"
cat << EOF > policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks-auth:AssumeRoleForPodIdentity",
                "sagemaker:DescribeClusterNode"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name TrainingOperatorPolicy \
    --policy-document file://policy.json 2>/dev/null || echo "TrainingOperatorPolicy already exists, continuing..."

export EXECUTION_ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName, `sagemaker-hyperpod-eks-SMHP-Exec-Role`)].Arn' --output text)
if [ -z "$EXECUTION_ROLE" ]; then
  # Try alternate naming pattern
  export EXECUTION_ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName, `ExecutionRole`)].Arn' --output text | head -1)
fi
if [ -z "$EXECUTION_ROLE" ]; then
  signal_failure "Couldn't get execution role for training operator"
fi
export EXECUTION_ROLE_NAME=$(echo $EXECUTION_ROLE | awk -F'/' '{print $NF}')
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam attach-role-policy \
    --role-name $EXECUTION_ROLE_NAME \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TrainingOperatorPolicy || echo "WARNING: Could not attach TrainingOperatorPolicy, may already be attached"

sleep 2

echo "Creating pod identity association between EKS cluster and execution role"
cat << EOF > updated-trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "sagemaker.amazonaws.com",
                    "pods.eks.amazonaws.com"
                ]
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF

# Update the role's trust policy
aws iam update-assume-role-policy \
    --role-name $EXECUTION_ROLE_NAME \
    --policy-document file://updated-trust-policy.json || echo "WARNING: Could not update trust policy on $EXECUTION_ROLE_NAME"

# Now try creating the pod identity association again
aws eks create-pod-identity-association \
    --cluster-name $EKSClusterName \
    --namespace aws-hyperpod \
    --service-account hp-training-operator-controller-manager \
    --role-arn $EXECUTION_ROLE \
    --region $AWSRegion 2>/dev/null || echo "WARNING: Pod identity association may already exist, continuing..."

aws eks list-pod-identity-associations --cluster-name $EKSClusterName
echo "#################################################Installing Inference operator####################################"

echo "######Setup HyperPod Inference Operator in HyperPod Cluster#######"
export HYPERPOD_CLUSTER_NAME=$(aws sagemaker list-clusters | jq -r '.ClusterSummaries[0].ClusterName')
LB_CONTROLLER_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-$HYPERPOD_CLUSTER_NAME"
LB_CONTROLLER_ROLE_NAME="aws-load-balancer-controller-$HYPERPOD_CLUSTER_NAME"
S3_MOUNT_ACCESS_POLICY_NAME="S3MountpointAccessPolicy-$HYPERPOD_CLUSTER_NAME"
S3_CSI_ROLE_NAME="SM_HP_S3_CSI_ROLE"
KEDA_OPERATOR_POLICY_NAME="KedaOperatorPolicy-$HYPERPOD_CLUSTER_NAME"
KEDA_OPERATOR_ROLE_NAME="keda-operator-role-$HYPERPOD_CLUSTER_NAME"
PRESIGNED_URL_ACCESS_POLICY_NAME="PresignedUrlAccessPolicy-$HYPERPOD_CLUSTER_NAME"
HYPERPOD_INFERENCE_ACCESS_POLICY_NAME="HyperpodInferenceAccessPolicy-$HYPERPOD_CLUSTER_NAME"
HYPERPOD_INFERENCE_ROLE_NAME="HyperpodInferenceRole-$HYPERPOD_CLUSTER_NAME"
HYPERPOD_INFERENCE_SA_NAME="hyperpod-inference-operator-controller"
HYPERPOD_INFERENCE_SA_NAMESPACE="hyperpod-inference-system"
JUMPSTART_GATED_ROLE_NAME="JumpstartGatedRole-$HYPERPOD_CLUSTER_NAME"
FSX_CSI_ROLE_NAME="AmazonEKSFSxLustreCSIDriverFullAccess-$HYPERPOD_CLUSTER_NAME"
export EKS_CLUSTER_NAME=$(aws sagemaker describe-cluster --cluster-name $HYPERPOD_CLUSTER_NAME --region $AWS_REGION --query 'Orchestrator.Eks.ClusterArn' --output text |cut -d'/' -f2)
export ROLE_ARN=$(aws eks describe-cluster --region $AWS_REGION --name $EKS_CLUSTER_NAME --query 'cluster.roleArn' --output text)
export ACCOUNT_ID=$(aws sts get-caller-identity --region $AWS_REGION --query 'Account' --output text)
export OIDC_ID=$(aws eks describe-cluster --region $AWS_REGION --name $EKS_CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
export EKS_CLUSTER_ROLE=$(aws eks describe-cluster --region $AWS_REGION --name $EKS_CLUSTER_NAME --query 'cluster.roleArn' --output text)
FSX_CSI_ROLE_ARN=$(aws iam get-role --role-name=AmazonEKSFSxLustreCSIDriverFullAccess --region $AWS_REGION --query "Role.Arn" --output text 2>/dev/null) || echo "WARNING: Could not get FSx CSI role ARN, continuing..."
S3_CSI_ROLE_NAME=SM_HP_S3_CSI_ROLE
BUCKET_NAME=sagemaker-hyperpod-eks-bucket-$ACCOUNT_ID-$AWS_REGION
echo "creating Service account with S3Full access"
eksctl create iamserviceaccount --name s3-csi-driver-sa --namespace kube-system --cluster $EKS_CLUSTER_NAME --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess  --approve  --role-name $S3_CSI_ROLE_NAME --region $AWS_REGION  --role-only || echo "WARNING: S3 CSI service account may already exist, continuing..."
echo "S3 Role created"
#FSX_CSI_ROLE_ARN=$(aws iam get-role --role-name=AmazonEKSFSxLustreCSIDriverFullAccess --region $AWS_REGION --query "Role.Arn" --output text)

#S3 CSI Drivers installation
echo “installing S3 CSI drivers”
S3_CSI_ROLE_ARN=$(aws iam get-role --role-name $S3_CSI_ROLE_NAME  --query 'Role.Arn' --output text)
eksctl create addon --name aws-mountpoint-s3-csi-driver --cluster $EKS_CLUSTER_NAME --version v1.15.0-eksbuild.1 --service-account-role-arn $S3_CSI_ROLE_ARN --force || echo "WARNING: S3 CSI driver addon may already exist, continuing..."

#NOT NEEDED -eksctl create iamserviceaccount --name fsx-csi-controller-sa --namespace kube-system --cluster $EKS_CLUSTER_NAME --attach-policy-arn arn:aws:iam::aws:policy/AmazonFSxFullAccess --approve --role-name FSXLCSI-$EKS_CLUSTER_NAME-$AWS_REGION --region $AWS_REGION --override-existing-serviceaccounts

echo "=== Environment Variables ==="
echo "AWS_REGION: $AWS_REGION"
echo "HYPERPOD_CLUSTER_NAME: $HYPERPOD_CLUSTER_NAME"
echo "BUCKET_NAME: $BUCKET_NAME"
echo "EKS_CLUSTER_NAME: $EKS_CLUSTER_NAME"
echo "ROLE_ARN: $ROLE_ARN"
echo "ACCOUNT_ID: $ACCOUNT_ID"
echo "OIDC_ID: $OIDC_ID"
echo "EKS_CLUSTER_ROLE: $EKS_CLUSTER_ROLE"
echo ""
echo "=== Policy and Role Names ==="
echo "LB_CONTROLLER_POLICY_NAME: $LB_CONTROLLER_POLICY_NAME"
echo "LB_CONTROLLER_ROLE_NAME: $LB_CONTROLLER_ROLE_NAME"
echo "S3_MOUNT_ACCESS_POLICY_NAME: $S3_MOUNT_ACCESS_POLICY_NAME"
echo "S3_CSI_ROLE_NAME: $S3_CSI_ROLE_NAME"
echo "KEDA_OPERATOR_POLICY_NAME: $KEDA_OPERATOR_POLICY_NAME"
echo "KEDA_OPERATOR_ROLE_NAME: $KEDA_OPERATOR_ROLE_NAME"
echo "PRESIGNED_URL_ACCESS_POLICY_NAME: $PRESIGNED_URL_ACCESS_POLICY_NAME"
echo "HYPERPOD_INFERENCE_ACCESS_POLICY_NAME: $HYPERPOD_INFERENCE_ACCESS_POLICY_NAME"
echo "HYPERPOD_INFERENCE_ROLE_NAME: $HYPERPOD_INFERENCE_ROLE_NAME"
echo "HYPERPOD_INFERENCE_SA_NAME: $HYPERPOD_INFERENCE_SA_NAME"
echo "HYPERPOD_INFERENCE_SA_NAMESPACE: $HYPERPOD_INFERENCE_SA_NAMESPACE"
echo "JUMPSTART_GATED_ROLE_NAME: $JUMPSTART_GATED_ROLE_NAME"
echo "FSX_CSI_ROLE_NAME: $FSX_CSI_ROLE_NAME"
echo "=== Environment Variables END ==="
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION
echo "Associating an IAM OIDC provider"
eksctl utils associate-iam-oidc-provider --region=$AWS_REGION --cluster=$EKS_CLUSTER_NAME --approve
kubectl get sa fsx-csi-controller-sa -n kube-system -oyaml
cat << EOF > trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "sagemaker.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
                    "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:*:*"
                }
            }
        }
    ]
}
EOF

cat << EOF > permission-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:ListTagsForResource",
        "ecr:DescribeImageScanFindings"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AssignPrivateIpAddresses",
        "ec2:AttachNetworkInterface",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeSubnets",
        "ec2:DetachNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:UnassignPrivateIpAddresses",
        "ec2:CreateTags",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications",
        "ec2:CreateNetworkInterfacePermission",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "eks:Describe*",
        "eks:List*",
        "eks:AssociateAccessPolicy",
        "eks:AccessKubernetesApi",
        "eks-auth:AssumeRoleForPodIdentity"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:Create*",
        "elasticloadbalancing:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sagemaker:CreateModel",
        "sagemaker:DescribeModel",
        "sagemaker:DeleteModel",
        "sagemaker:ListModels",
        "sagemaker:CreateEndpointConfig",
        "sagemaker:DescribeEndpointConfig",
        "sagemaker:DeleteEndpointConfig",
        "sagemaker:CreateEndpoint",
        "sagemaker:DeleteEndpoint",
        "sagemaker:DescribeEndpoint",
        "sagemaker:UpdateEndpoint",
        "sagemaker:ListTags",
        "sagemaker:EnableClusterInference",
        "sagemaker:DescribeClusterInference",
        "sagemaker:DescribeHubContent",
        "sagemaker:UpdateClusterInference",
        "sagemaker:DescribeCluster",
        "sagemaker:AddTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "acm:ImportCertificate",
        "acm:DeleteCertificate"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowPassRoleToSageMaker",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "sagemaker.amazonaws.com"
        }
      }
    },
    {
      "Sid": "CloudWatchEMFPermissions",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:CreateLogStream",
        "logs:CreateLogGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "fsx:DescribeFileSystems"
      ],
      "Resource": "*"
    }
  ]
}
EOF
aws iam create-policy --policy-name $HYPERPOD_INFERENCE_ACCESS_POLICY_NAME --policy-document file://permission-policy.json 2>/dev/null || echo "$HYPERPOD_INFERENCE_ACCESS_POLICY_NAME already exists, continuing..."
export policy_arn="arn:aws:iam::${ACCOUNT_ID}:policy/$HYPERPOD_INFERENCE_ACCESS_POLICY_NAME"
# ROLE FOR HYPERPOD_INFERENCE
echo "Creating the IAM role for HYPERPOD_INFERENCE"
eksctl create iamserviceaccount --approve --role-only --name=$HYPERPOD_INFERENCE_SA_NAME --namespace=$HYPERPOD_INFERENCE_SA_NAMESPACE --cluster=$EKS_CLUSTER_NAME --attach-policy-arn=$policy_arn --role-name=$HYPERPOD_INFERENCE_ROLE_NAME --region=$AWS_REGION || echo "WARNING: iamserviceaccount for inference may already exist, continuing..."

aws iam put-role-policy --role-name $HYPERPOD_INFERENCE_ROLE_NAME --policy-name InferenceOperatorInlinePolicy --policy-document file://permission-policy.json || echo "WARNING: Could not put inline policy on $HYPERPOD_INFERENCE_ROLE_NAME"
aws iam update-assume-role-policy --role-name $HYPERPOD_INFERENCE_ROLE_NAME --policy-document file://trust-policy.json || echo "WARNING: Could not update trust policy on $HYPERPOD_INFERENCE_ROLE_NAME"


echo "#################################################$HYPERPOD_INFERENCE_ROLE_NAME################################"

#Download and create the IAM policy for the AWS Load Balancer Controller
echo "Downloading and creating the IAM policy for the AWS Load Balancer Controller "
export ALBController_IAM_POLICY_NAME=HyperPodInferenceALBControllerIAMPolicy

curl -o AWSLoadBalancerControllerIAMPolicy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.0/docs/install/iam_policy.json
# Check if the downloaded file is too small (less than 1000 bytes indicates an error page)
if [ $(wc -c < AWSLoadBalancerControllerIAMPolicy.json) -lt 1000 ]; then
    echo "Download failed or returned error page, using embedded policy..."
    cat > AWSLoadBalancerControllerIAMPolicy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "ec2:GetSecurityGroupsForVpc",
                "ec2:DescribeIpamPools",
                "ec2:DescribeRouteTables",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags",
                "elasticloadbalancing:DescribeTrustStores",
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:DescribeCapacityReservation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:CreateProtection",
                "shield:DeleteProtection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:ModifyListenerAttributes",
                "elasticloadbalancing:ModifyCapacityReservation",
                "elasticloadbalancing:ModifyIpPools"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ],
            "Condition": {
                "StringEquals": {
                    "elasticloadbalancing:CreateAction": [
                        "CreateTargetGroup",
                        "CreateLoadBalancer"
                    ]
                },
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule",
                "elasticloadbalancing:SetRulePriorities"
            ],
            "Resource": "*"
        }
    ]
}
EOF
fi
aws iam create-policy --policy-name $ALBController_IAM_POLICY_NAME --policy-document file://AWSLoadBalancerControllerIAMPolicy.json 2>/dev/null || echo "$ALBController_IAM_POLICY_NAME already exists, continuing..."
export ALB_POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$ALBController_IAM_POLICY_NAME"
eksctl create iamserviceaccount   --approve   --override-existing-serviceaccounts   --name=aws-load-balancer-controller   --namespace=kube-system   --cluster=$EKS_CLUSTER_NAME   --attach-policy-arn=$ALB_POLICY_ARN   --region=$AWS_REGION || echo "WARNING: ALB controller service account may already exist, continuing..."
# Tag the private subnets for the EKS cluster with kubernetes.io.role/elb=1.
echo "Tagging the private subnets for the EKS cluster with kubernetes.io/role/elb=1"
export VPC_ID=$(aws --region $AWS_REGION eks describe-cluster --name $EKS_CLUSTER_NAME --query 'cluster.resourcesVpcConfig.vpcId' --output text)
export PRIVATE_ROUTE_TABLE=$(aws ec2 describe-route-tables --filters "Name=tag:aws:cloudformation:logical-id,Values=PrivateRouteTable" --query 'RouteTables[0].RouteTableId' --output text)
aws ec2 describe-subnets   --filters "Name=vpc-id,Values=${VPC_ID}" "Name=map-public-ip-on-launch,Values=false"   --query 'Subnets[*].SubnetId' --output text --region $AWS_REGION | tr '\t' '\n' | xargs -I{} aws ec2 associate-route-table --subnet-id {} --route-table-id $PRIVATE_ROUTE_TABLE --region $AWS_REGION
aws ec2 describe-subnets   --filters "Name=vpc-id,Values=${VPC_ID}" "Name=map-public-ip-on-launch,Values=false"   --query 'Subnets[*].SubnetId' --output text --region $AWS_REGION | tr '\t' '\n' | xargs -I{} aws ec2 create-tags --region $AWS_REGION --resources {} --tags Key=kubernetes.io/role/elb,Value=1
kubectl create namespace keda || true
kubectl create namespace cert-manager || true

echo "Installing cert-manager via Helm first (pre-req for inference operator)..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.1 \
  --set installCRDs=true

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager

#Create policy for Keda
cat <<EOF > keda-trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/oidc.eks.$AWS_REGION.amazonaws.com/id/$OIDC_ID"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.$AWS_REGION.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:keda-operator",
                    "oidc.eks.$AWS_REGION.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

cat <<EOF > keda-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:GetMetricData",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "aps:QueryMetrics",
                "aps:GetLabels",
                "aps:GetSeries",
                "aps:GetMetricMetadata"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-role \
    --role-name keda-operator-role \
    --assume-role-policy-document file://keda-trust-policy.json 2>/dev/null || echo "keda-operator-role already exists, continuing..."

KEDA_POLICY_ARN=$(aws iam create-policy \
    --policy-name KedaOperatorPolicy \
    --policy-document file://keda-policy.json \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || \
aws iam list-policies \
    --scope Local \
    --query 'Policies[?PolicyName==`KedaOperatorPolicy`].Arn' \
    --output text)

aws iam attach-role-policy \
    --role-name keda-operator-role \
    --policy-arn $KEDA_POLICY_ARN || echo "WARNING: Could not attach KedaOperatorPolicy, may already be attached"

cat <<EOF> presignedurl-policy.json
{
   "Version": "2012-10-17",
   "Statement": [
        {
            "Sid": "CreatePresignedUrlAccess",
            "Effect": "Allow",
            "Action": [
                "sagemaker:CreateHubContentPresignedUrls"
            ],
            "Resource": [
                "arn:aws:sagemaker:${AWS_REGION}:aws:hub/SageMakerPublicHub",
                "arn:aws:sagemaker:${AWS_REGION}:aws:hub-content/SageMakerPublicHub/*/*"
            ]
        }
   ]
}
EOF

aws iam create-policy --policy-name PresignedUrlAccessPolicy --policy-document file://presignedurl-policy.json 2>/dev/null || echo "PresignedUrlAccessPolicy already exists, continuing..."

JUMPSTART_GATED_ROLE_NAME="JumpstartGatedRole-$AWS_REGION-${HYPERPOD_CLUSTER_NAME}"

cat <<EOF > jump-trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/oidc.eks.$AWS_REGION.amazonaws.com/id/${OIDC_ID}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.$AWS_REGION.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:*:$HYPERPOD_INFERENCE_SA_NAME",
                    "oidc.eks.$AWS_REGION.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
                }
            }
        },
         {
            "Effect": "Allow",
            "Principal": {
                "Service": "sagemaker.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

aws iam create-role \
    --role-name $JUMPSTART_GATED_ROLE_NAME \
    --assume-role-policy-document file://jump-trust-policy.json 2>/dev/null || echo "$JUMPSTART_GATED_ROLE_NAME already exists, continuing..."

aws iam attach-role-policy \
    --role-name $JUMPSTART_GATED_ROLE_NAME \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/PresignedUrlAccessPolicy || echo "WARNING: Could not attach PresignedUrlAccessPolicy to $JUMPSTART_GATED_ROLE_NAME"

JUMPSTART_GATED_ROLE_ARN=$(aws iam get-role --role-name=$JUMPSTART_GATED_ROLE_NAME --query "Role.Arn" --output text)

aws iam attach-role-policy --role-name=$HYPERPOD_INFERENCE_ROLE_NAME --policy-arn=arn:aws:iam::aws:policy/AmazonSageMakerFullAccess || echo "WARNING: Could not attach AmazonSageMakerFullAccess to $HYPERPOD_INFERENCE_ROLE_NAME"

echo "JumpStart_GATED_ROLE_ARN is $JUMPSTART_GATED_ROLE_ARN"
echo " HyperPod Inference Operator using Helm"
git clone https://github.com/aws/sagemaker-hyperpod-cli
cd sagemaker-hyperpod-cli
# Pin to commit before the breaking change (v1.3.0 introduced tab character bug)
# Using parent of f4fc838 which is 9f496a6
git checkout 9f496a6
cd helm_chart/HyperPodHelmChart
HYPERPOD_INFERENCE_ROLE_ARN=$(aws iam get-role --role-name=$HYPERPOD_INFERENCE_ROLE_NAME --region $AWS_REGION --query "Role.Arn" --output text)
echo $HYPERPOD_INFERENCE_ROLE_ARN

S3_CSI_ROLE_ARN=$(aws iam get-role --role-name=$S3_CSI_ROLE_NAME --region $AWS_REGION --query "Role.Arn" --output text)
echo $S3_CSI_ROLE_ARN

HYPERPOD_CLUSTER_ARN=$(aws sagemaker describe-cluster --region $AWS_REGION --cluster-name $HYPERPOD_CLUSTER_NAME --query "ClusterArn")
FSX_CSI_ROLE_ARN=$(aws iam get-role --role-name=AmazonEKSFSxLustreCSIDriverFullAccess --region $AWS_REGION --query "Role.Arn" --output text 2>/dev/null) || echo "WARNING: Could not get FSx CSI role ARN for inference operator"
echo "Cluster Name: $EKS_CLUSTER_NAME"
echo "Execution Role: $HYPERPOD_INFERENCE_ROLE_ARN"
echo "Hyperpod ARN: $HYPERPOD_CLUSTER_ARN"

helm dependencies update charts/inference-operator || echo "WARNING: helm dependencies update failed for inference-operator"

helm install hyperpod-inference-operator charts/inference-operator \
-n kube-system \
--set region=$AWS_REGION \
--set eksClusterName=$EKS_CLUSTER_NAME \
--set hyperpodClusterArn=$HYPERPOD_CLUSTER_ARN \
--set executionRoleArn=$HYPERPOD_INFERENCE_ROLE_ARN \
--set s3.serviceAccountRoleArn=$S3_CSI_ROLE_ARN \
--set s3.node.serviceAccount.create=false \
--set fsx.enabled=false \
--set s3.enabled=false \
--set cert-manager.enabled=false \
--set keda.enabled=true \
--set keda.podIdentity.aws.irsa.roleArn="arn:aws:iam::$ACCOUNT_ID:role/keda-operator-role" \
--set tlsCertificateS3Bucket="s3://$BUCKET_NAME" \
--set alb.region=$AWS_REGION \
--set alb.clusterName=$EKS_CLUSTER_NAME \
--set alb.vpcId=$VPC_ID \
--set jumpstartGatedModelDownloadRoleArn=$JUMPSTART_GATED_ROLE_ARN || echo "WARNING: Inference operator helm install failed, but continuing..."

echo "###################################End of HyperPod inference operator #########################"

echo "###################################Installing HyperPod training operator #########################"
aws eks create-addon \
  --cluster-name $EKS_CLUSTER_NAME \
  --addon-name amazon-sagemaker-hyperpod-training-operator \
  --resolve-conflicts OVERWRITE || echo "WARNING: Training operator addon may already exist, continuing..."

echo "Validating"
kubectl get pods -n aws-hyperpod || echo "WARNING: Training operator pods not yet ready, but addon was created successfully"

echo "###################################End of HyperPod training operator #########################"


if [ "$PreDeployGPUInstances" = "true" ]; then
  echo "###################################Scaling up GPU instances #########################"
  
  aws sagemaker describe-cluster --cluster-name $HYPERPOD_CLUSTER_NAME --region $AWSRegion \
    --query '[InstanceGroups[?contains(InstanceGroupName, `accelerated`)] | [0] | {InstanceGroupName:InstanceGroupName,InstanceType:InstanceType,InstanceCount:`2`,LifeCycleConfig:LifeCycleConfig,ExecutionRole:ExecutionRole,ThreadsPerCore:ThreadsPerCore,InstanceStorageConfigs:InstanceStorageConfigs}]' \
    --output json > update_api_payload.json
  
  aws sagemaker update-cluster --cluster-name $HYPERPOD_CLUSTER_NAME --region $AWSRegion --instance-groups file://update_api_payload.json
else
  echo "WARNING: PreDeployGPUInstances is false - GPU instance group is still at 0. If you plan to use GPUs in your workshop, please make sure your participants scale manually!"
fi

# Create a file to indicate processing is complete
echo "Data processing completed at $(date)" > $TARGET_PATH/processing_complete.txt

# Copy logs to FSx for visibility
cp /var/log/user-data-script.log /mnt/fsx/user-data-script.log || true

# Script completed successfully
echo "management-instance-script.sh completed successfully!"
# Note: cfn-signal is handled by the UserData wrapper that invokes this script.
# Exit 0 to indicate success to the calling UserData.
