---
title: "Downloading the Llama3-70b model"
sidebar_position: 3
weight: 32
---

In this section, we will download the Llama3 model and the llama tokenizer. We will then also prepare the model for the Neuron runtime by converting the model weights to be pre-sharded based on the parallel processing configuration (i.e., the degrees of the model parallelism axes).

## Download the Llama3-70b model and tokenizer
First, make sure that you have a Hugging Face account with a valid [User Access Token](https://huggingface.co/docs/hub/en/security-tokens). Also, since the Llama3 herd of families are hosted on gated repos on Hugging Face, please make sure that your Hugging Face account has access to the [Meta-Llama-3-70B](https://huggingface.co/meta-llama/Meta-Llama-3-70B) model repository.

On your head node, run
```bash
huggingface-cli login
```

You will be prompted to enter your token. Paste in the token and answer `n` when prompted to add the token as a git credential.
```

    _|    _|  _|    _|    _|_|_|    _|_|_|  _|_|_|  _|      _|    _|_|_|      _|_|_|_|    _|_|      _|_|_|  _|_|_|_|
    _|    _|  _|    _|  _|        _|          _|    _|_|    _|  _|            _|        _|    _|  _|        _|
    _|_|_|_|  _|    _|  _|  _|_|  _|  _|_|    _|    _|  _|  _|  _|  _|_|      _|_|_|    _|_|_|_|  _|        _|_|_|
    _|    _|  _|    _|  _|    _|  _|    _|    _|    _|    _|_|  _|    _|      _|        _|    _|  _|        _|
    _|    _|    _|_|      _|_|_|    _|_|_|  _|_|_|  _|      _|    _|_|_|      _|        _|    _|    _|_|_|  _|_|_|_|

    To login, `huggingface_hub` requires a token generated from https://huggingface.co/settings/tokens .
Enter your token (input will not be visible): 
Add token as git credential? (Y/n) n
Token is valid (permission: read).
Your token has been saved to /fsx/ubuntu/.cache/huggingface/token
Login successful
```

Now that you're logged in, let's grab the model weights (you may choose to use `git clone` if you wish too):
```bash
huggingface-cli download meta-llama/Meta-Llama-3-70B --local-dir /fsx/ubuntu/Meta-Llama-3-70B
```
Once the download is completed (~30 min), you will see the following directory structure:
```
/fsx/ubuntu/Meta-Llama-3-70B/
├── LICENSE
├── README.md
├── USE_POLICY.md
├── config.json
├── generation_config.json
├── model-00001-of-00030.safetensors
...
├── model-00030-of-00030.safetensors
├── model.safetensors.index.json
├── original
│   ├── consolidated.00.pth
....
│   ├── consolidated.07.pth
│   ├── params.json
│   └── tokenizer.model
├── special_tokens_map.json
├── tokenizer.json
└── tokenizer_config.json
```

Copy over the tokenizer configs under the test case repository
```bash
cp /fsx/ubuntu/Meta-Llama-3-70B/*token* /fsx/ubuntu/llama
```

## Convert the Llama3 model weights
As mentioned, NxD requires that the model checkpoints be pre-sharded based on the chosen parallel configurations (tensor, pipeline parallelism degrees). The preprocessing entails:
- Saving the original checkpoint into a single binary file.
- Sharding the checkpoints (binary file) using the provided `convert_checkpoints.py` [utility script](https://github.com/aws-neuron/neuronx-distributed/blob/main/examples/training/llama/convert_checkpoints.py).

First, let's save the original checkpoints into a single binary file. 
```bash
cat > save-llama3-70B-model.py << EOF
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

model = AutoModelForCausalLM.from_pretrained("/fsx/ubuntu/Meta-Llama-3-70B")
torch.save(model.state_dict(), '/fsx/ubuntu/llama-3-70b.pt')
EOF
```

Let's then run this created script using `sbatch` on a cluster compute node (ml.trn1.32xlarge), which has enough HBM memory to be able to load the model and run the script:
```bash
sbatch --job-name=save-checkpoints --output=logs/save-checkpoints.out \
       --wrap "srun python save-llama3-70B-model.py"
```

Once this job completes, let's convert the checkpoints (i.e., shard the checkpoints):
```bash
mkdir -p /fsx/ubuntu/llama3_70B/pretrained_weight
sbatch --job-name=convert-checkpoint --output=logs/convert-checkpoint.out \
       --wrap "\ 
              srun python convert_checkpoints.py \
              --hw_backend trn1 \
              --tp_size 32 --pp_size 8 --n_layers 80 \
              --save_xser 1 \
              --kv_size_multiplier 4 \
              --qkv_linear 1 \
              --fuse_qkv True \
              --input_dir /fsx/ubuntu/llama-3-70b.pt \
              --output_dir /fsx/ubuntu/llama3_70B/pretrained_weight \
              --config /fsx/ubuntu/Meta-Llama-3-70B/config.json \
              --convert_from_full_state"
```

You can track the progress by tailing your defined log file:
```bash
tail -f logs/convert-checkpoint.out
```

Your logs will look like
```
Saving to /fsx/ubuntu/llama3_70B/pretrained_weight/model/dp_rank_00_tp_rank_00_pp_rank_00.pt
Saving to /fsx/ubuntu/llama3_70B/pretrained_weight/model/dp_rank_00_tp_rank_00_pp_rank_01.pt
Saving to /fsx/ubuntu/llama3_70B/pretrained_weight/model/dp_rank_00_tp_rank_00_pp_rank_02.pt
Saving to /fsx/ubuntu/llama3_70B/pretrained_weight/model/dp_rank_00_tp_rank_00_pp_rank_03.pt
Saving to /fsx/ubuntu/llama3_70B/pretrained_weight/model/dp_rank_00_tp_rank_00_pp_rank_04.pt
Saving to /fsx/ubuntu/llama3_70B/pretrained_weight/model/dp_rank_00_tp_rank_00_pp_rank_05.pt
...
```

At the end of this process, we will end up with 32 x 8 = 256 checkpoints. This is because `convert_checkpoints.py` shards the model per tensor parallel and pipeline parallel dimensions.

As a sanity check:
```bash
ls /fsx/ubuntu/llama3_70B/pretrained_weight/model/dp_rank_*_tp_rank_*_pp_rank_*.pt | wc -l
# Output should be 256
```

:::info Parallelism Strategy:
Note: The sharding is done based on the hardware setup. In our case, we are running on a cluster of 16 x ml.trn1.32xlarge instances (SageMaker HyperPod SLURM cluster).

Each ml.trn1.32xlarge instance has 16 Trainium Neuron Chips (Neuron Devices). Each of these Neuron Chips has 2 NeuronCore-v2 (i.e., 2 Neuron Cores), totalling to 32 Neuron Cores per ml.trn1.32large instance, and thus 512 Neuron Cores in the entire cluster.

---
 **Pipeline Parallelism**: Given that we have 512 Neuron Cores, and that Llama3-70b has 80 layers, we can do:
 - First 10 layers: Instance 1
 - Second 10 layers: Instance 2
 - ...
 - Eighth 10 layers: Instance 8

 *=> Pipeline Parallelism = 8 (i.e., across 8 ml.trn1.32xlarge instances)*

---
 **Tensor Parallelism**: We split the model by layers (10) across 8 instances via Pipeline Parallelism. Within each of these instances, we can further split the layers via Tensor Parallelism, dividing the stage's parameters across 32 Neuron Cores. 

---
**Data Parallelism**: Since we are maintaining two replicas of the sharded models, we employ data parallelism with a degree of 2 to speed up the training process. The resultant checkpoints will be used in the next continual pre-training stage.
:::
