---
title: "Monitor Job"
sidebar_position: 4
weight: 23
---

Now that the job is running, we can monitor it in two ways, we can tail the log file to see how the training is progressing:

```bash
# Control-C to stop tailing
tail -f llama.out
```

We can also ensure it's utilizing the accelerators appropriately by SSH-ing into the compute node. 

Grab the hostname by running `sinfo` and seeing which node it's running on:

```bash
sinfo
```

```
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
dev*         up   infinite      1  alloc ip-10-1-90-87
```

Then ssh into that instance using the hostname from `sinfo`:

```bash
ssh ip-10-1-90-87
```

Once there we can monitor the accelerator usage by running `neuron-top`:

```bash
neuron-top
```

You'll see very little usage of the accelerators for the first few minutes as it sets up the case, then you'll see constant usage after that:

![Neuron Top](/img/02-llama/neuron-top.png)