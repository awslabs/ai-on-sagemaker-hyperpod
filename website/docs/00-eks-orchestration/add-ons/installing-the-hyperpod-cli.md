---
title : Installing the Hyperpod CLI
sidebar_position : 6
sidbar_title: Installing the Hyperpod CLI
---
:::warning Under Maintenance
This tool is currently under maintenance. Some features may not work as expected. Please check the [official repository](https://github.com/aws/sagemaker-hyperpod-cli) for the latest updates.
:::


The Amazon SageMaker HyperPod command-line interface (HyperPod CLI) is a tool that helps manage training jobs on the SageMaker HyperPod clusters orchestrated by Amazon EKS. With the HyperPod CLI, scientists can submit training jobs by providing a `.yaml` file and manage jobs (list, describe, view, cancel) without needing to use kubectl. It is essentially a wrapper on top of `kubectl` and the AWS CLI.

This page shows you how to install it on your development machine (local laptop, EC2, etc.) and how to verify the installation. In some sample applications in this guide, we explain how to run it with HyperPod CLI instead of `kubectl`. For more information about the HyperPod CLI, see the [sagemaker-hyperpod-cli repository](https://github.com/aws/sagemaker-hyperpod-cli) on GitHub.


## 0. Prerequisites

To install the HyperPod CLI, you must have Helm installed. 


## 1. Install

1. Create a directory
    ``` bash
    mkdir hyperpod-cli
    cd hyperpod-cli
    ```

1. Clone the repository
    ``` bash
    git clone -b release_v2 https://github.com/aws/sagemaker-hyperpod-cli.git
    ```

1. (Optional) create a virtual env and activate it
    ``` bash
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -U wheel setuptools
    ```

1. Build
    ```
    cd sagemaker-hyperpod-cli
    pip install .
    ```


## 2. Verify installation

1. Get help message

    ``` bash
    hyperpod --help
    ```

    ```
    Find more information at: https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod.html

    Basic Commands:
    * get-clusters    Get clusters information for HyperPod EKS clusters.
    * connect-cluster Creates a connection from users local terminal to the HyperPod cluster 
                        allowing user to start and preform other basic operations with training jobs.
    * start-job       Start a training job from a file on HyperPod cluster.
    * get-job         Show details of a specific training job submitted on HyperPod cluster.
    * list-jobs       List training job on a HyperPod cluster.
    * cancel-job      Cancel training job on a HyperPod cluster.
        :
        :
    ```

1. Check where `hyperpod` command was installed
    ``` bash
    which hyperpod
    ```

    ```
    /home/username/hyperpod-cli/.venv/bin/hyperpod
    ```
