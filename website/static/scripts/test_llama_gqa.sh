#!/usr/bin/env bash
source ./train_setup.sh

: ${TRAIN_ITERS:=20000}
: ${INIT_METHOD_STD:=0.021}
: ${LAYERNORM_EPSILON:=1e-5}
: ${WARMUP_STEPS:=10}

: ${SEQ_LENGTH:=2048}
: ${HS:=4096}
: ${TP:=8}
: ${PP:=1}
: ${N_LAYERS:=32}
: ${N_AH:=32}
: ${UBS:=1}
: ${FFN_HS:=11008}
: ${GBS:=256}
: ${KV_HEADS=8}

: ${TOKENIZER_PATH=/opt/ml/data/tokenizer.model}
: ${DATASET_PATH=/opt/ml/data/megatron-c4-sample_text_document}

echo "SEQ_LEN=$SEQ_LENGTH, HS=$HS, FFN_HS=$FFN_HS TP=$TP PP=$PP N_LAYERS=$N_LAYERS N_AH=$N_AH GBS=$GBS UBS=$UBS TRAIN_ITERS=$TRAIN_ITERS"

LOG_PATH=../logs/$SLURM_JOB_ID/$NODEID/
mkdir -p $LOG_PATH
NEMO_PATH=../Neuron-Nemo-Megatron/nemo/examples/nlp/language_modeling
VENV_PATH=../neuron-nemo-env
TORCHRUN=$VENV_PATH/bin/torchrun

$MAYBE_COMPILE $TORCHRUN $DISTRIBUTED_ARGS $NEMO_PATH/megatron_llama_pretraining.py  \
    --config-path=conf \
    --config-name=megatron_llama_70b_config \
    trainer.devices=$PROCESSES_PER_NODE \
    trainer.num_nodes=$NTASKS \
    trainer.max_epochs=null \
    trainer.max_steps=$TRAIN_ITERS\
    trainer.val_check_interval=$TRAIN_ITERS \
    trainer.log_every_n_steps=1 \
    trainer.limit_val_batches=1 \
    trainer.limit_test_batches=1 \
    trainer.accumulate_grad_batches=1 \
    trainer.precision=32 \
    model.megatron_amp_O2=$megatron_amp_O2 \
    +trainer.num_sanity_val_steps=0 \
    model.tokenizer.library=sentencepiece \
    model.tokenizer.model=/opt/ml/data/tokenizer.model \
    model.micro_batch_size=$UBS \
    model.global_batch_size=$GBS \
    model.tensor_model_parallel_size=$TP \
    model.pipeline_model_parallel_size=$PP \
    model.max_position_embeddings=$SEQ_LENGTH \
    model.encoder_seq_length=$SEQ_LENGTH \
    model.hidden_size=$HS \
    model.ffn_hidden_size=$FFN_HS \
    model.num_layers=$N_LAYERS \
    model.num_attention_heads=$N_AH \
    model.init_method_std=$INIT_METHOD_STD \
    model.hidden_dropout=0 \
    model.num_kv_heads=$KV_HEADS \
    model.layernorm_epsilon=$LAYERNORM_EPSILON \
    model.data.data_prefix=[1.0,$DATASET_PATH] \
    model.data.num_workers=4 \
    model.data.seq_length=$SEQ_LENGTH \
    model.optim.name=adamw \
    model.optim.lr=3e-4 \
    model.optim.betas=[0.9,0.95] \
    model.optim.weight_decay=0.1 \
    model.optim.sched.name=CosineAnnealing \
    model.optim.sched.warmup_steps=$WARMUP_STEPS \
    model.optim.sched.constant_steps=0 \
    model.optim.sched.min_lr=3e-5 \
    model.optim.capturable=True \
    model.sequence_parallel=True  \
    model.activations_checkpoint_granularity=full \
    model.activations_checkpoint_method=uniform \
    model.activations_checkpoint_num_layers=1 \
    +model.save_xser=False \
    exp_manager.create_tensorboard_logger=$CREATE_TB_LOGGER \
    exp_manager.exp_dir=$LOG_PATH/exp_logs \
    exp_manager.resume_if_exists=True \
    exp_manager.resume_ignore_no_checkpoint=True \
    exp_manager.create_checkpoint_callback=$CHECKPOINT_CALLBACK \
    +exp_manager.checkpoint_callback_params.train_time_interval=36000 \
    exp_manager.checkpoint_callback_params.save_last=True \
    exp_manager.explicit_log_dir=$LOG_PATH \
    exp_manager.exp_dir=$LOG_PATH \
    model.use_cpu_initialization=True   2>&1  | tee  $LOG_PATH/log
