---
title: "Downloading the Wiki-corpus datasets"
sidebar_position: 4
weight: 33
---

In this section, we will download and preprocess the [wiki-corpus](https://www.corpusdata.org/wikipedia.asp) and tokenize it for training.

We will utilize the `get_dataset.py` script inside the same `llama` sample directory. Again, we use `sbatch` to submit the data processing job to the cluster.

```bash
sbatch --job-name=get-dataset --output=logs/get-dataset.out \
       --wrap "srun python3 get_dataset.py --llama-version 3"
```

You can tail the logs:
```bash
tail -f logs/get-dataset.out
```

An example output:
```
$ python get_dataset.py --llama-version 3
The repository for wikicorpus contains custom code which must be executed to correctly load the dataset. You can inspect the repository content at https://hf.co/datasets/wikicorpus.
You can avoid this prompt in future by passing the argument `trust_remote_code=True`.

Do you wish to run the custom code? [y/N] y
Downloading data: 100%|███████████████████████████████████████████████████████████████████████████████████████████| 1.35G/1.35G [03:02<00:00, 7.36MB/s]
Generating train split: 100%|██████████████████████████████████████████████████████████████████████| 1359146/1359146 [01:12<00:00, 18644.90 examples/s]
Running tokenizer on dataset:  37%|████████████████████████▏                                         | 497000/1359146 [02:28<04:18, 3341.01 examples/s]
Token indices sequence length is longer than the specified maximum sequence length for this model (172677 > 131072). Running this sequence through the model will result in indexing errors
Running tokenizer on dataset: 100%|█████████████████████████████████████████████████████████████████| 1359146/1359146 [06:45<00:00, 3352.65 examples/s]
Grouping texts in chunks of 8192: 100%|█████████████████████████████████████████████████████████████| 1359146/1359146 [09:48<00:00, 2308.18 examples/s]
94025
Saving the dataset (21/21 shards): 100%|████████████████████████████████████████████████████████████████| 94025/94025 [00:18<00:00, 4951.30 examples/s]
```

The resultant data is saved under `/fsx/ubuntu/example_datasets`:
```
/fsx/ubuntu/examples_datasets/wikicorpus_llama3_tokenized_8k/
├── data-00000-of-00021.arrow
...
├── data-00020-of-00021.arrow
├── dataset_info.json
└── state.json
```

We're now ready for continual pre-training!