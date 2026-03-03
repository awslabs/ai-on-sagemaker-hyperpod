---
title : "Diagnose GPU Failures"
weight : 50
---

To diagnose a node with a bad gpu `ip-10-1-69-242` on SageMaker HyperPod, do the following:

1. Run the nvidia reset command:

```bash
srun -w ip-10-1-69-242 sudo nvidia-smi --gpu-reset -i 0
```

2. If that doesn't success then generate a bug report:

```bash
srun -w ip-10-1-69-242 nvidia-bug-report.sh
```

3. Grab the instance id:

```bash
srun -w ip-10-1-69-242 cat /sys/devices/virtual/dmi/id/board_asset_tag | tr -d " "
```

4. Grab the output of `nvidia-bug-report.sh` and replace that instance:

```bash
sudo scontrol update node=ip-10-1-69-242 state=down reason="Action:Replace"
```