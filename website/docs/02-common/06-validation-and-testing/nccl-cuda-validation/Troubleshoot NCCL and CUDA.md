---
title: Troubleshoot NCCL and CUDA
sidebar_position: 1
---
# Troubleshooting NCCL and CUDA - a (not) comprehensive guide

There are moments where you are stuck either because things are not working or the performnace is not what you expected. Most, not always, it will be an issue with libraries and drivers. For GPU-based workloads, those issues can show up more frequently as there are many bits and pieces that need to be working together. A simple mismatch of a library version or not-optimized driver version for that specific librabry version can break things.

Let's start with creating simple scripts that will help us debug and validate our environment. 

## CUDA - Compute Unified Device Architecture

### Background history and architecture overview
NVIDIA CUDA is the platform required to run workloads using your GPU. Initially designed for rendering graphics, hence the name Graphic Processing Unit (GPU), the GPU has become much more than that. Starting circa 2006, NVIDIA launched the CUDA platform and allowed their GPU to become GPGPU: General Purpose Graphic Processing Unit. This meant that now you could run workloads using your GPGPU instead of the CPU to execute binary code. 

In order to develop an application that uses your GPGPU (i'll start abbreviating as GPU from now on), you need a few things to work together:
- a GPU device. The latests ones, as of September 2025, are the H200, B200 (Blackwell) and the GB200 (Grace Hopper Blackwell). 
- a GPU driver.
- a CUDA runtime. 

## Debug and test if the CUDA environment is okay

Here is a simple debug script that will output an error code which we can use later:

```c
#include <cuda.h>
#include <stdio.h>

int main() {
    CUresult result = cuInit(0);
    printf("cuInit result: %d\n", result);

    if (result == CUDA_SUCCESS) {
        int count;
        cuDeviceGetCount(&count);
        printf("Device count: %d\n", count);
    }
    return 0;
}
``` 

Then, in order to run this script we need to compile it with our CUDA compiler (named: nvcc) and create an executable binary. 

```bash
nvcc debug_cuda.cu -o debug_cuda -lcuda
```

Now you can run it simply as `debug_cuda`. 

Let's create another script. This time we want to create a simple test that will use our CUDA environment and show the versions used when running the executable code.

```c
#include <cuda.h>
#include <stdio.h>

int main() {
    CUresult result = cuInit(0);
    printf("cuInit: %d\n", result);

    int count = 0;
    result = cuDeviceGetCount(&count);
    printf("cuDeviceGetCount: %d, count: %d\n", result, count);

    return 0;
}
``` 

It uses the driver API directly and show how many CUDA devices there are (GPUs). Compile and run it: 

```bash
nvcc test_cuda.cu -o test_cuda -L/usr/lib64 -lcuda
./test_cuda
```

Another way to test if your workload can access the CUDA devices is using Python3 Torch library. You can install the library using `pip3` and then run a simple python oneliner to check version and count of CUDA devices. 

```bash
pip3 install torch
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}'); print(f'Device count: {torch.cuda.device_count()}')"
```

## Possible solutions

Hopefully, those scripts will help you understand what is the problem. Some possible scenarios are:

### CUDA driver and NVCC (compiler) versions mismatch
One of the most common issues is to use different versions for both of those components. The recommended approach is to have both at the same version. 

Links you can try to use to debug:


### CUDA device not intialized
Your device needs to be initialized (awakened) to work with your drivers. There are several ways of doing that, including rebooting the server. 

Links you can try to use to debug: 

### NVLink status and topology
It is important to check the status and topology of NVLinks. Those are hardware dependant and can be checked with the following commands: 

```bash
nvidia-smi nvlink --status
nvidia-smi topo -m
nvidia-smi nvlink --capabilities
```

The output should give you plenty of information on the hardware topology and specification. This information is useful to understand how to better define paralellism in your jobs and understand the theoretical limits of your hardware solution.
