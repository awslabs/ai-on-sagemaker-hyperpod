---
sidebar_position: 3
---
# Profiling with Nvidia Nsight

Nsight Systems is a system-wide performance analysis tool designed to profile and visualize multi-node CPU and GPU workloads such as distributed training and inference to identify the largest opportunities to optimize, and tune to scale efficiently across the cluster. It also enables researchers to add their own markers into their code to surface application-level metrics into the profiler and gain further observability.

This page describes how to enable profiling of your application, capture profiling data, and visualize the captured performance data, using the [FSDP sample app](/docs/eks-blueprints/training/fsdp/fully-sharded-data-parallel) as an example.


## 0. Prerequisite

* This page assumes you have run the FSDP sample app, and know how to run the FSDP sample app.

* We will use FSx Lustre filesystem as the location to create performance profiling data. Please follow the [FSx Lustre setup instruction](/docs/getting-started/orchestrated-by-eks/Set%20up%20your%20shared%20file%20system) if you haven't done yet.

* To visualize the captured profiling data, this page assumes you installed the Nsight Systems GUI application on your local machine. You can download and install it from this official [NVIDIA Nsight Systems site](https://developer.nvidia.com/nsight-systems/get-started).


## 1. Setup

Install the [Nvidia Devtools Sidecar Injector](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/devtools/helm-charts/devtools-sidecar-injector) to your cluster. By using the sidecar, you can profile your application without modifying the application container image.

1. Create a YAML file (`custom_values.yaml`) referring to the following example.

    ``` yaml
    # Assuming EKS cluster has a FSx for Lustre filesystem mounted on it. Nsight reports will be saved in /fsx_shared
    profile:
    volumes:
        [
            {
                "name": "nsys-output-volume",
                "persistentVolumeClaim": { "claimName": "fsx-claim" }
            }
        ]
    volumeMounts:
        [
            {
                "name": "nsys-output-volume",
                "mountPath": "/fsx_shared"
            }
        ]

    # CLI options: https://docs.nvidia.com/nsight-systems/UserGuide/index.html#cli-command-switches
    # delay and duration values in secs

    # Use %{} to include environment variables in the Nsight report filename

    # The arguments for the Nsight Systems. The placeholders will be replaced with the actual values.
    devtoolArgs: "profile --force-overwrite true --trace nvtx,cuda  --delay 150 --duration 180 \
    -o /fsx_shared/fsdp/auto_{PROCESS_NAME}_%{POD_FULLNAME}_%{CONTAINER_NAME}_{TIMESTAMP}_{UID}.nsys-rep"

    # Regular expression to match process names to profile
    injectionMatch: "^/usr/bin/python3 /usr/local/bin/torchrun.*$"
    ```


1. Run following command to install the Nvidia Devtools Sidecar Injector.

    ``` sh
    helm install -f custom_values.yaml \
        devtools-sidecar-injector https://helm.ngc.nvidia.com/nvidia/devtools/charts/devtools-sidecar-injector-1.0.7.tgz
    ```


1. Add `nvidia-devtools-sidecar-injector` label to worker pods by editing the `fsdp.yaml` file.

    ``` yaml
    pytorchReplicaSpecs:
      Worker:
        template:
          metadata:
            labels:
              # Enable profiling with Nsight
              nvidia-devtools-sidecar-injector: enabled
    ```

    At this moment, profiling is enabled for `/usr/bin/python3 /usr/local/bin/torchrun` processes in the FSDP worker pods.


## 2. Run and capture profiling data

1. Run the FSDP application by running following command.

    ``` sh
    kubectl apply -f fsdp.yaml
    ```

    As you specified `--delay 150 --duration 180` in the `custom_values.yaml`, performance capturing starts 150 seconds after the launch, and the application process automatically terminates capturing data for 180 seconds.


1. Confirm captured profiling data exist.

    Run following command to list captured files.

    ```
    kubectl exec -it fsdp-worker-0 -- ls -al /fsx_shared/fsdp
    ```


## 3. Visualize

To visualize the captured profiling data, you download a file to your local machine, and open the file with Nsight System GUI application.

1. Download a file

    Run following command to download a captured profiling data file to your local machine.

    ``` sh
    kubectl cp fsdp-worker-0:/fsx_shared/fsdp/auto_python3_default_fsdp-worker-7_pytorch_1723657514003_11bccb52.nsys-rep -c pytorch ./auto_python3_default_fsdp-worker-7_pytorch_1723657514003_11bccb52.nsys-rep
    ```

1. Open the file with Nsight Systems GUI app

    Open the Nsight Systems GUI app on your local machine, and select "File" > "Open" to open the downloaded captured profiling data.

    The profiling information is visualized as follows:

    ![nvtop](/img/06-observability/nsight-gui.png)


## 4. Turn off profiling / uninstall

To disable profiling, you can comment out the `nvidia-devtools-sidecar-injector` label in the `fsdp.yaml` file.

To uninstall the Nvidia Devtools Sidecar Injector, run following command.

```
helm uninstall devtools-sidecar-injector
```
