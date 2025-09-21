#!/bin/bash
# Request one node:
#SBATCH --nodes=1
#
# Specify one task:
#SBATCH --ntasks-per-node=1
#
# Wall clock limit:
#SBATCH --time=00:00:30
#
## Command(s) to run:
srun --exclusive --exclude ip-26-0-176-110 --partition trn1-benchmarking ./llama_7b.sh
