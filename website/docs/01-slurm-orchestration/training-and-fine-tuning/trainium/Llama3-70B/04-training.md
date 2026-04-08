---
title: "Running Continual Pre-training with NeuronX Distributed"
sidebar_position: 5
weight: 34
---

Okay, now that we've pre-processed the data and the model checkpoints, we are ready to submit a continual pre-training job. We have two sub-directories under `/fsx/ubuntu/llama`:
- `tp_pp_llama_hf_pretrain`: [link](https://github.com/aws-neuron/neuronx-distributed/tree/main/examples/training/llama/tp_pp_llama_hf_pretrain)
- `tp_zero1_llama_hf_pretrain`: [link](https://github.com/aws-neuron/neuronx-distributed/tree/main/examples/training/llama/tp_zero1_llama_hf_pretrain)

These are two parallelism strategies [ZeRO-1](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/frameworks/torch/torch-neuronx/tutorials/training/zero1_gpt2.html) and Model Parallelism. For this test case, let's use the model parallelism strategy. Copy the relevant files:
```bash
mv tp_pp_llama_hf_pretrain/* .
```

Running `ls /fsx/ubuntu/llama`, you should see template scripts per model inside the directory:
```
13B_config_llama2  __pycache__               convert_checkpoints.py  llama3-70B-save.py  lr.py                  requirements_ptl.txt     run_llama2_70B_tp_pp.sh  save-llama3-70B-model.py  tp_pp_llama_hf_pretrain
70B_config_llama2  activation_checkpoint.py  get_dataset.py          logger.py           modeling_llama_nxd.py  results.json             run_llama3_70B_tp_pp.sh  tokenizer.json            tp_zero1_llama_hf_pretrain
70B_config_llama3  checkpoint_converter.py   lightning               logs                requirements.txt       run_llama2_13B_tp_pp.sh  run_llama_nxd.py         tokenizer_config.json     training_utils.py
```

For this test case, we only need to modify a few lines of the `run_llama2_70B_tp_pp.sh` script. 

1. Firstly, let's modify the path to the shared file system (default is `/shared`, we want to use `/fsx/ubuntu`), which we can do in place:
```bash
sed -i 's/\/shared/\/fsx\/ubuntu/g' run_llama3_70B_tp_pp.sh
```

2. Let's modify the `torchrun` args.
- **Enable Pretrained Weights**: Neuron Distributed default initiates training without using pretrained weights. To enable the use of pretrained weights, set the value of the `--pretrained_weight` argument to 1.
- **Change Checkpoint Frequency**: Modify the value of the `--checkpoint_freq` argument to `m` (an integer) to save checkpoints every `m` steps.
- **Manage Checkpoint Storage**: The current version of Neuron Distributed generates checkpoints roughly 850 GB in size for the 70B model training. Saving all historical checkpoints can consume too much space. Modify the value of the `--num_kept_checkpoint` argument to `n` (an integer) to keep only the latest `n` checkpoints.
- **Ensure Latest Checkpoint Loading**: To ensure the training process always starts from the latest checkpoint, set the value of the `--loading_step argument` to `latest_if_exists`. This is crucial in the event of hardware failure. HyperPod also provides an `auto-resume` functionality. If a job fails due to hardware issues, HyperPod initiates node replacement and restarts the job using the same script. This script must load the latest checkpoints when training resumes. We will set `--auto-resume=1` in the `sbatch` file.

```bash
torchrun $DISTRIBUTED_ARGS run_llama_nxd.py \
        ...
        --fuse_qkv 1 \
        --pretrained_weight 1 \ # Change value
        ...
        --checkpoint_freq 5 \ # change value
        --num_kept_checkpoint 2 \ # Change value
        --loading_step latest_if_exists \ # Change value
        --tb_dir $tb_dir |& tee $LOG_PATH/log
exit ${PIPESTATUS[0]}        
```

Using this new `run_llama3_70B_tp_pp.sh` script, let's first pre-compile the graphs (since Neuron is xla based) using the `neuron_parallel_compile`.
```bash
sbatch --job-name run_llama3_70B \
       --output logs/run_llama3_70B.out \
       --exclusive --nodes 16 \
       --cpus-per-task 64 \
       --wrap="srun neuron_parallel_compile bash $(pwd)/run_llama3_70B_tp_pp.sh"
```

This step takes ~25 min. Remember the idea is to pre-compile the model to build graphs, so that when you start your actual training (`torchrun your_model.py`), your model's graphs are built and stored in a cache, so training will start a lot faster.

You know that the compilation step is complete when you see the following in `logs/run_llama3_70B.out`
```
.........
Compiler status PASS
2025-01-17 01:16:07.000934:  42821  INFO ||NEURON_PARALLEL_COMPILE||: worker 6 finished with num of tasks 1....
2025-01-17 01:16:07.000970:  42821  INFO ||NEURON_CACHE||: Current remaining items are 0, locked are 2, failed are 0, done are 32, total is 34
2025-01-17 01:16:07.000981:  32201  INFO ||NEURON_PARALLEL_COMPILE||: {
    "compilation_summary": {
        "true": 2
    },
    "compilation_report": {
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_9993940051196728623+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 9.770226240158081
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_7470829644182149778+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 192.86727905273438
        }
    },
    "start_time": 1737076372.654127,
    "compilation_time": 195.32730412483215
}
2025-01-17 01:16:07.000981:  32201  INFO ||NEURON_PARALLEL_COMPILE||: Total graphs: 2
2025-01-17 01:16:07.000981:  32201  INFO ||NEURON_PARALLEL_COMPILE||: Total successful compilations: 2
2025-01-17 01:16:07.000981:  32201  INFO ||NEURON_PARALLEL_COMPILE||: Total failed compilations: 0
..............
Compiler status PASS
2025-01-17 01:16:20.000242:  48243  INFO ||NEURON_PARALLEL_COMPILE||: worker 0 finished with num of tasks 1....
2025-01-17 01:16:20.000264:  48243  INFO ||NEURON_CACHE||: Current remaining items are 0, locked are 1, failed are 0, done are 33, total is 34
.
Compiler status PASS
2025-01-17 01:16:38.000143:  48247  INFO ||NEURON_PARALLEL_COMPILE||: worker 4 finished with num of tasks 1....
2025-01-17 01:16:38.000162:  48247  INFO ||NEURON_CACHE||: Current remaining items are 0, locked are 0, failed are 0, done are 34, total is 34
2025-01-17 01:16:38.000177:  37654  INFO ||NEURON_PARALLEL_COMPILE||: {
    "compilation_summary": {
        "true": 8
    },
    "compilation_report": {
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_13896381258680072431+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 207.77499103546143
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_15605214078085204741+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 62.078277826309204
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_17180165851576277373+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 13.69736123085022
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_17186493308924889042+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 13.605631828308105
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_17656286827372360109+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 224.9934914112091
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_15118541367256155893+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 69.67782711982727
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_6234946551864249267+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 73.62903022766113
        },
        "/fsx/ubuntu/cache_dir_neuron/neuronxcc-2.16.372.0+4a9b2326/MODULE_2285528399009206869+3cc9a3cb/model.hlo_module.pb": {
            "status": true,
            "retry": 0,
            "compile_time": 52.13106894493103
        }
    },
    "start_time": 1737076372.4143333,
    "compilation_time": 225.76303887367249
}
2025-01-17 01:16:38.000177:  37654  INFO ||NEURON_PARALLEL_COMPILE||: Total graphs: 8
2025-01-17 01:16:38.000177:  37654  INFO ||NEURON_PARALLEL_COMPILE||: Total successful compilations: 8
2025-01-17 01:16:38.000177:  37654  INFO ||NEURON_PARALLEL_COMPILE||: Total failed compilations: 0
```

Now, let's submit the real training job:
```bash
sbatch --job-name run_llama3_70B \
       --output logs/run_llama3_70B.out \
       --exclusive --nodes 16 \
       --wrap="srun --auto-resume=1 bash $(pwd)/run_llama3_70B_tp_pp.sh"
```

Once submitted, you can track the logs
```bash
tail -f logs/run_llama3_70B.out
```

You will eventually see
```
step 1 step_time 244.7649691104889s throughput 3.935193537274158 seq/s loss 13.412860887125134 grad norm 1.9788274765014648
step 2 step_time 243.86105298995972s throughput 3.9816862016317915 seq/s loss 13.413119042292237 grad norm 1.9752838611602783
step 3 step_time 243.8063349723816s throughput 4.004761851017232 seq/s loss 13.412440737709403 grad norm 1.976004958152771
step 4 step_time 243.819584608078s throughput 4.018679872757218 seq/s loss 13.4128421805799 grad norm 1.9743479490280151
step 5 step_time 243.8718819618225s throughput 4.027843716250589 seq/s loss 13.411852965131402 grad norm 1.970628261566162
```
which shows that training is running!

Additionally, you will see checkpoints being written. You directory structure would now look like
```
/fsx/ubuntu/llama3_70B/
├── pretrained_weight
│   └── model
└── step_5
    ├── checkpoint
    ├── done
    ├── model
    ├── optim
    ├── scheduler.pt
    └── user_content.pt
```




