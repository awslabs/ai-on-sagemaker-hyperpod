---
title: "Submit Job"
siderbar_position: 3
weight: 22
---

## Launch training

Once your environment is done building, you can launch training by running below command. (We already precompile the model so you can launch the job without compilation).

Make sure you are in the directory of `~/training_artifacts/neuronx-distributed-training/examples`.

```bash
cat > submit-llama8b.sh << EOL
#!/bin/bash
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -o llama.out

export OMP_NUM_THREADS=1

export COMPILE=0
export CONF_FILE=hf_llama3_8B_config

srun ./train.sh
EOL
```

Now we can submit the job:

```bash
sbatch submit-llama8b.sh
```

Note the `--exclusive` flag. This tells Slurm you want exclusive access to this node, and so it can assign all CPU cores for your use. On some Slurm systems, CPU cores can be individually assigned, and leaving the flag out can mean you only get 1 core, which isn't enough to keep all 16 Trainium chips working. While Slurm can be configured to always give exclusive access, it's good practice to include the flag when you're not sure.
