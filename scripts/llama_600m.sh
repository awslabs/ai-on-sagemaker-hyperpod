#!/usr/bin/env bash

source /scratch/ubuntu/builder_session/neuron-nemo-env/bin/activate

export SEQ_LENGTH=4096
export HS=2048
export TP=1
export PP=1
export N_LAYERS=8
export N_AH=16
export FFN_HS=5504
export GBS=128
export TRAIN_ITERS=20000

export INIT_METHOD_STD=0.021
export LAYERNORM_EPSILON=1e-5
export WARMUP_STEPS=10

./test_llama.sh
