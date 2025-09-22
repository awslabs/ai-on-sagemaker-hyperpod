#!/usr/bin/env bash
set -o pipefail
set -e

ulimit -n 65535

export FI_EFA_USE_DEVICE_RDMA=1
export FI_PROVIDER=efa
export FI_EFA_FORK_SAFE=1

echo "NODELIST="${SLURM_NODELIST}
master_addr=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
export MASTER_ADDR=$master_addr
echo "MASTER_ADDR="$MASTER_ADDR
NODEID=$SLURM_NODEID
NTASKS=$SLURM_NTASKS

export HYDRA_FULL_ERROR=1
export PROCESSES_PER_NODE=32
export MASTER_PORT=41000

export NEURON_RT_EXEC_TIMEOUT=10
export DISTRIBUTED_ARGS="--nproc_per_node $PROCESSES_PER_NODE --nnodes $NTASKS --node_rank $NODEID --master_addr $MASTER_ADDR --master_port $MASTER_PORT"
echo $DISTRIBUTED_ARGS

export BUCKET_CAP_MB=1024
export NEURON_RT_ASYNC_EXEC_MAX_INFLIGHT_REQUESTS=5
export NEURON_TRANSFER_WITH_STATIC_RING_OPS=""
export MALLOC_ARENA_MAX=128
export TF_NUM_INTEROP_THREADS=1024
export XLA_THREAD_POOL_SIZE=4
export XLA_IO_THREAD_POOL_SIZE=4


export NEURON_RT_STOCHASTIC_ROUNDING_EN=1

#training_precision is one of 'bf16SR', 'megatron_amp_O2', 'fp32_OptStates'
#training_precision = "bf16SR", uses BF16 + Stochastic Rounding
#training_precision = "megatron_amp_O2", master weights and optimizer states are stored in fp32, model weights in bf16
#training_precision = "fp32_OptStates", optimizer states are stored in fp32, model weights in bf16
training_precision="bf16SR"
if [[ $training_precision == "bf16SR" ]];then
    echo using BF16 SR
    export XLA_USE_BF16=1
    export NEURON_CC_FLAGS="--model-type transformer --distribution-strategy=nemo --enable-mixed-precision-accumulation --optlevel 1"
    export OPTIM_NAME=adamw
    export megatron_amp_O2=false
elif [[ $training_precision == "megatron_amp_O2" ]]; then
    echo using megatron_amp_O2
    export XLA_DOWNCAST_BF16=1
    export NEURON_CC_FLAGS="--model-type transformer --distribution-strategy=nemo --enable-mixed-precision-accumulation --optlevel 1"
    export OPTIM_NAME=adamw
    export megatron_amp_O2=true
elif [[ $training_precision == "fp32_OptStates" ]]; then
    echo using FP32 Optimizer States
    export XLA_DOWNCAST_BF16=1
    export NEURON_CC_FLAGS="--model-type transformer --distribution-strategy=nemo --enable-mixed-precision-accumulation --optlevel 1"
    export OPTIM_NAME=adamw_fp32OptState
    export megatron_amp_O2=false
else
    echo Incorrect Training Precision Provided
fi

export NEURON_COMPILE_CACHE_URL="/scratch/ubuntu/builder_session/neuron_cache" # Place cache on shared storage to reduce redundant compilations


export CREATE_TB_LOGGER=True
export CHECKPOINT_CALLBACK=True

export COMPILE=

if [ "$COMPILE" = "1" ]; then
    echo "compiling only run"
    MAYBE_COMPILE="neuron_parallel_compile"
    export TRAIN_ITERS=3
    CREATE_TB_LOGGER=False
    CHECKPOINT_CALLBACK=False
fi
