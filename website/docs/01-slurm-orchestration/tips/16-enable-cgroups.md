---
title: "Configure Cgroups for Slurm"
weight: 56
---

[Cgroups](https://en.wikipedia.org/wiki/Cgroups) is a Linux kernel feature that limits, accounts for, and isolates the resource usage (CPU, memory, disk I/O, etc.) of a collection of processes. In traditional environments, Cgroups allow system administrators to allocate resources such as CPU time, system memory, disk bandwidth, etc., among user-defined groups of tasks (processes) running on a system. We can [configure Slurm to use Cgroups](https://slurm.schedmd.com/cgroups.html) to constrain resources at the Slurm job and task level. A popular usecase for implementing Cgroups with Slurm is to use Process tracking `proctrac/cgroup` to isolate processes to a slurm job, thus ensuring all processes created by the job are contained within a cgroup, which helps in monitoring and controlling the resource usage by the job. It also helps in cleaning up processes after the job ends, ensuring that there are no "zombie" processes left running on the system.


### Steps to enable c-groups:

*Execute the following example steps on the **Controller Node** of your cluster*

##### 1. Modify `slurm.conf: note you might need to remove existing mention of these from slurm.conf

```bash
sudo vim /opt/slurm/etc/slurm.conf
```
Add the following lines:
```bash
# Cgroup settings
ProctrackType=proctrack/cgroup
TaskPlugin=task/cgroup,task/affinity
PrologFlags=Contain

# SCHEDULING
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory
```

* `ProctrackType=proctrack/cgroup`: This setting tells Slurm to use Linux Control Groups (cgroups) to track and manage the processes started by a Slurm job. This ensures that all processes created by the job are contained within a cgroup.

* `TaskPlugin=task/cgroup,task/affinity`: the `task/cgroup` plugin is the main plugin for enabling cgroup support in Slurm. It integrates with the Linux cgroups subsystem to manage and limit resources such as CPU, memory, and I/O for jobs and job steps. It also allows Slurm to create, modify, and delete cgroups dynamically as jobs are scheduled, executed, and completed. You can read more about the `task/Cgroup` plugin in the [Link to SchedMD Documentation](https://slurm.schedmd.com/cgroups.html#task).The `task/afinity` plugin handles CPU affinity for tasks, meaning it binds tasks to specific CPUs. This can improve performance by reducing context switching and cache misses, and it can ensure that tasks run on the CPUs allocated to them, promoting better resource utilization and isolation.


* `PrologFlags=Contain`: 

* `SchedulerType=sched/backfill`: Backfill is a scheduling technique used to optimize the utilization of resources. The backfill scheduler scans the queue of pending jobs and identifies jobs that can be started and completed without delaying the start of any higher-priority jobs. This helps to maximize resource utilization by filling in gaps in the schedule with smaller or shorter jobs.

* `SelectType=select/cons_tres` plugin is available to manage resources on a much more fine-grained basis than exclusive node allocation. This allows for the use of Memory containment on the nodes Read more [here](https://slurm.schedmd.com/cons_tres.html)

* `SelectTypeParameters=CR_Core_Memory`: ensures that memory allocation is directly tied to core allocation, leading to a more balanced and efficient use of resources on the cluster.

##### 2. Create a new file `/opt/slurm/etc/cgroup.conf` and configure your cgroup options:

```bash
CgroupPlugin=autodetect
ConstrainDevices=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=yes
SignalChildrenProcesses=yes
MaxRAMPercent=50
```
With this configuration, Slurm will create a cgroup hierarchy for each job and constrain the processes to the assigned resources, including GPUs. User processes will not be able to escape the cgroup and continue consuming resources after the job completes. For more information, see the below linked documentation:

* `CgroupPlugin=autodetect` If configured will try to determine which cgroup version (v1 or v2) the system is providing. This is a recomended setting from Schedmd. [Link to SchedMD Documentation](https://slurm.schedmd.com/cgroup.conf.html#SECTION_DESCRIPTION:~:text=sys/fs/cgroup.-,CgroupPlugin,-%3D%3Ccgroup/v1).

* `ConstrainDevices=yes` If configured to "yes" then constrain the job's allowed devices based on GRES allocated resources. It uses the devices subsystem for that. The default value is "no". [Link to SchedMD Documentation](https://slurm.schedmd.com/cgroup.conf.html#OPT_ConstrainDevices).

* `ConstrainRAMSpace=yes` If configured to "yes" then constrain the job's RAM usage by setting the memory soft limit to the allocated memory and the hard limit to the allocated memory * AllowedRAMSpace. The default value is "no", in which case the job's RAM limit will be set to its swap space limit if ConstrainSwapSpace is set to "yes". CR_*_Memory must be set in slurm.conf for this parameter to take any effect. Also see AllowedSwapSpace, AllowedRAMSpace and ConstrainSwapSpace. **NOTE:**  When using ConstrainRAMSpace, if the combined memory used by all processes in a step is greater than the limit, then the kernel will trigger an OOM event, killing one or more of the processes in the step. The step state will be marked as OOM, but the step itself will keep running and other processes in the step may continue to run as well. This differs from the behavior of OverMemoryKill, where the whole step will be killed/cancelled. [Link to SchedMD Documentation](https://slurm.schedmd.com/cgroup.conf.html#OPT_ConstrainRAMSpace).

* `ConstrainSwapSpace=yes` If configured to "yes" then constrain the job's swap space usage. The default value is "no". Note that when set to "yes" and ConstrainRAMSpace is set to "no", AllowedRAMSpace is automatically set to 100% in order to limit the RAM+Swap amount to 100% of job's requirement plus the percent of allowed swap space. This amount is thus set to both RAM and RAM+Swap limits. This means that in that particular case, ConstrainRAMSpace is automatically enabled with the same limit as the one used to constrain swap space. CR_*_Memory must be set in slurm.conf for this parameter to take any effect. Also see AllowedSwapSpace.[Link to SchedMD Documentation](https://slurm.schedmd.com/cgroup.conf.html#OPT_ConstrainSwapSpace). 


##### 3.Restart slurmctld and reconfigure to enable the configuration changes:

```bash 
sudo systemctl restart slurmctld
sudo scontrol reconfigure
```

##### Validation Tests

**1.** In the following test, we will start a sleep process and exit leaving it in background. Use the below bash script to run a job which runs a sleep command (600 seconds) and exits. We can test this before and after configuring the cgroup and notice the process gets killed with cgroups configured. 

Create a file called `test.sh` which contains:
```bash
#! /bin/bash
# SBATCH —nodes 1


echo "1"
echo $(sleep 600 &) &
echo "2"
```

Now lets run the script and check if the process is killed.
```bash
sbatch test.sh 

# check if the job completed

scontrol show job <job_id> 

# Now we should not be able to see the process on the node with srun when using cgroup

srun -N 1 ps aux | head -n 1; ps aux | grep sleep
```

Note without c-groups enabled, you will be able to find the sleep process continuing to run after the slurm job has canceled (for 600 seconds as defined in the script).  If the `ProctrackType=proctrack/cgroup` is correctly configured, you will not see the sleep process when sshing onto the node, because it was killed when the job ended.

**2.** (optional) Start a tmux session within a srun session

The following demonstrates a situation of a process that will not be killed by cgroups. On HyperPod, although not recommended, users may launch a job or process outside of Slurm, one common scenario is `tmux`. Tmux has its own daemon to manage sessions, so the session that is created when you use `tmux` belongs to that tmux manager and not slurm. As a result any process started by tmux session will not be cleaned up by cgroups.

```bash
srun -t 4:00:00 --pty bash
tmux # start tmux sessions
while [ true ]; do echo hi; sleep 1 ; done
# detach from tmux session
# leave the node and end the job
```

3. Memory Test to check enforcement of memory limits

```bash
git clone https://github.com/josenk/alloc_mem
cd alloc_mem
make 64bit
srun -N 1 ./alloc_mem -r -l 2000000 8000
```

The above job will allocate 2 TiB of Memory in 8 GB chunks. it should take ~5 min to OOM on a p5.48xlarge.
while the job is running, open up a second terminal, ssh into the node which the memory test job is running on, and check free memory:


```bash
### see which node is allocated to the jon
squeue
### ssh into that node and check for memory utilization
ssh <ipv-4-for-job>
free -m
```


When memory hits the threshold, you will see used memory cap out, and the srun job will fail with:

```
slurmstepd: error: Detected 1 oom_kill event in StepId=29.0. Some of the
step tasks have been OOM Killed.
srun: error: ip-10-1-10-5: task 0: Out Of Memory
```


Congratulations, you have successfully setup and tested memory enforcement and process tracking via c-groups.