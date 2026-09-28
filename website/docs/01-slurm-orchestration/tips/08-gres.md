---
title : "Gres (--gpus)"
weight : 48
---

This section describes how to setup [Slurm Gres](https://slurm.schedmd.com/gres.html) which allows scheduling jobs based on the number of gpu's needed i.e. `--gpus=4`. Please see the below note before proceeding with the setup:

:::warning
If you enable Gres support and your cluster uses an AMI older than the [August 20, 2024 release](https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-release-notes.html#sagemaker-hyperpod-release-notes-20240820), the auto-resume feature doesn't work. This is because instances need to be scheduled with `--nodes` and `--exclusive` flags for automatic instance replacement to function. To enable Gres and auto-resume, update your cluster to the latest AMI.
:::

If you see an error `sbatch: error: Invalid generic resource (gres) specification`, you need to set `GresType` in slurm.conf so it recognizes the parameter `--gres=gpu:8`. To do that run the following:

```bash
printf "\nGresTypes=gpu" | sudo tee -a /opt/slurm/etc/slurm.conf
```

Next remove the `OverSubscribe=EXCLUSIVE` section on the line:

```
PartitionName=dev Nodes=ALL Default=YES MaxTime=INFINITE State=UP ~~OverSubscribe=EXCLUSIVE~~
```

Next edit the file `/opt/slurm/etc/slurm.conf` and remove the `file=` part after `Gres` (if it exists). Make sure the number of gpus corresponds to the number on the instance, i.e. 8 for p4d/p5.

```
# change
NodeName=ip-10-1-57-141 NodeHostname=ip-10-1-57-141 NodeAddr=10.1.57.141 CPUs=48 Gres=gpu:4,file=/dev/nvidia-[0-3] State=CLOUD
# to
NodeName=ip-10-1-57-141 NodeHostname=ip-10-1-57-141 NodeAddr=10.1.57.141 CPUs=48 Gres=gpu:4 State=CLOUD
```

Reconfigure and restart `slurmctld`:

```bash
sudo systemctl restart slurmctld
sudo scontrol reconfigure
sudo systemctl restart slurmctld
```

Restart `slurmd` daemons on the compute node, you will need to ssh in if the nodes show `inval` or `drain`. We've included a script that can be used to automate this below:

```bash
ssh ip-10-0-0-XX sudo systemctl restart slurmd
```

:::warning
You may have to SSH into each node if the nodes are in the `invalid`, `down` or `drain` state instead of using the above `srun` command. In order to do that please use the following script where `nodes="ip-10-0-0-[1,2]"` is the nodelist from `sinfo`. 

```bash
#!/bin/bash

nodes="ip-10-0-0-[1,2]"
NODES=$( scontrol show hostnames $nodes  | sed 'N;s/\n/ /' )
echo $NODES
command="sudo systemctl restart slurmd"

for node in $NODES
do
        echo -e "SSH into $node"
        ssh $node $command
done
```

Run this script like, where `restart_slurmd.sh` is the name of the script above:

```bash
bash restart_slurmd.sh
```
:::


Finally set the node states to `idle`, where the `nodename` points to all the nodes in your cluster:

```bash
sudo scontrol update nodename=ip-26-0-148-28,ip-x-x-x-x state=idle
```

You can check to make sure gres is setup by running the following command:

```bash
sinfo -o "%P %G %D %N"
```

This command will show you the Gres resources for your instances:

```
PARTITION GRES NODES NODELIST
ml.p5.48xlarge* gpu:8 1 ip-10-1-10-42
```

Next you can test by submitting two jobs that each requires 4 gpus:

```bash
cat > gpus.sh << EOF
#!/bin/bash
#SBATCH --gpus=4
#SBATCH --array=0-1
#SBATCH --mem=4G

echo -e "GPUs's assigned to this job: \$CUDA_VISIBLE_DEVICES"
EOF
```

Submit the job and take note of the job id:

```bash
sbatch gpus.sh
```

You'll see the following output, assuming each instance has 8 gpus and the job id is `1`:

```bash
$ cat slurm-1_*
GPUs's assigned to this job: 0,1,2,3
GPUs's assigned to this job: 4,5,6,7
```
