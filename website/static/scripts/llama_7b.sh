#!/usr/bin/env bash

source ../neuron-nemo-env/bin/activate

export SEQ_LENGTH=4096
export HS=4096
export TP=8
export PP=1
export N_LAYERS=32
export N_AH=32
export FFN_HS=11008
export GBS=64
export TRAIN_ITERS=20000

export INIT_METHOD_STD=0.021
export LAYERNORM_EPSILON=1e-5
export WARMUP_STEPS=10

./test_llama.sh
