---
title: "Setting up the software stack"
sidebar_position: 2
weight: 31
---

![Tranium](/img/02-llama/trn1.png)

In this section, we will prepare the software stack and scripts needed for the training. Specifically, we will:
1. Create a Python Virtual Environment, which includes NeuronX Distributed
2. Fetch the scripts used for the Llama3-70B training.

## Python Virtual Environment Preparation
First, let's create the Python Virtual Environment. We can then install `torch-neuronx` and `neuronx-distributed`.

```bash
# Install Python venv 
sudo apt-get install -y python3.8-venv g++ 

# Create Python venv
python3.8 -m venv /fsx/ubuntu/aws_neuron_venv_pytorch 

# Activate Python venv 
source /fsx/ubuntu/aws_neuron_venv_pytorch/bin/activate 
python -m pip install -U pip 

# Set pip repository pointing to the Neuron repository 
python -m pip config set global.extra-index-url https://pip.repos.neuron.amazonaws.com

# Install wget, awscli, and huggingface-cli 
python -m pip install wget awscli huggingface_hub 

# Install Neuron Compiler and Framework
python -m pip install --upgrade neuronx-cc==2.* torch-neuronx==2.1.* torchvision

#Install the neuronx-distributed package 
python -m pip install neuronx_distributed --extra-index-url https://pip.repos.neuron.amazonaws.com
```

This test case is with Neuron SDK 2.21.0. For the latest release versions, check [What's New](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/release-notes/index.html). Neuron SDK 2.21.0 includes:
```
(aws_neuron_venv_pytorch) ubuntu:~$ pip list | grep neuron
libneuronxla              2.1.714.0
neuronx-cc                2.16.372.0+4a9b2326
neuronx-distributed       0.10.1
torch-neuronx             2.1.2.2.4.0

$ srun -N1 dpkg -l | grep neuron # This command runs on a compute instance (trn1.32xlarge)
ii  aws-neuronx-collectives                2.23.133.0-3e70920f2                  amd64        neuron_ccom built using CMake
ii  aws-neuronx-dkms                       2.19.64.0                             amd64        aws-neuronx driver in DKMS format.
ii  aws-neuronx-oci-hook                   2.6.36.0                              amd64        neuron_oci_hook built using CMake
ii  aws-neuronx-runtime-lib                2.23.110.0-9b5179492                  amd64        neuron_runtime built using CMake
ii  aws-neuronx-tools                      2.20.204.0                            amd64        Neuron profile and debug tools
```

## Clone the NxD Repository and install additional dependencies
Now that the virtual environment is prepared and ready, let's fetch the [llama3 test case](https://github.com/aws-neuron/neuronx-distributed/tree/main/examples/training/llama) from `neuronx-distributed`. Let's clone it to our home directory
```bash
git clone https://github.com/aws-neuron/neuronx-distributed.git \
          /fsx/ubuntu/neuronx-distributed

# Copy over just the llama3 test case under the home directory
cp -r /fsx/ubuntu/neuronx-distributed/examples/training/llama /fsx/ubuntu/llama
cd /fsx/ubuntu/llama

# Install additional dependencies
source /fsx/ubuntu/aws_neuron_venv_pytorch/bin/activate
python -m pip install -r requirements.txt
```