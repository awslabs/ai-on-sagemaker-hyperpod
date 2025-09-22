#!/usr/bin/env bash

BASE_DIR=/scratch/ubuntu/builder_session

IMAGE=$BASE_DIR/enroot_images/neuronx-nemo-2.14.sqsh

srun -N 8 \
--exclusive \
--partition trn1-benchmarking \
--container-image=${IMAGE} \
--container-mounts $BASE_DIR/scripts:/workspace/scripts,\
$BASE_DIR/data:/opt/ml/data,\
$BASE_DIR/logs:/workspace/logs,\
$BASE_DIR/neuron_cache:/workspace/neuron_cache \
--container-env FI_PROVIDER=efa,\
FI_EFA_USE_DEVICE_RDMA=1,\
FI_EFA_FORK_SAFE=1,\
NCCL_SOCKET_IFNAME="^lo,docker" \
bash -c "cd /workspace/scripts && ./llama_70b.sh"
