---
title: "Resiliency: Murphy's Law Strikes"
sidebar_position: 4
---

# Resiliency: Murphy's Law Strikes

:::tip Reference Documentation
For the full set of resiliency mechanisms on EKS-orchestrated clusters, see [EKS resiliency](/docs/eks-orchestration/validation-and-testing/resiliency/eks-resiliency).
:::

Or as our CTO Dr. Werner Vogels said: "Everything fails, all the time."

## 🎯 Mission: Demonstrate Fault Tolerance

**Objective**: Intentionally fail a GPU node during training and watch HyperPod's surgical recovery in action.

- **Investor**: "This is impressive, but what happens when hardware fails? In our current setup, a single node failure means restarting everything. We've lost days of training time."
- **Jane Doe**: "Great question. MLE, can you demonstrate—"
- **You**: "Actually, let me show you something. I'll intentionally break a node during training, and you can watch HyperPod recovery in real-time."
- **Jane Doe**: "You're going to break it? During the demo?"
- **Investor**: "Wait, are you sure? Will we lose everything??"

You: "Watch this.... HyperPod's surgical recovery in action."

**Why this matters**: In production, hardware fails. A lot. HyperPod's resilience can save you days of training time and thousands of dollars. Check out this blog that talks about the [TCO savings you can make with HyperPod](https://aws.amazon.com/blogs/machine-learning/reduce-ml-training-costs-with-amazon-sagemaker-hyperpod/)!

In this section, we will use the HyperPod Training Operator's Process Level Restart feature, that automatically restarts processes rather than the entire job.

## 🛡️ HyperPod Training Operator Resiliency

How does the HP Training Operator improve resiliency? Instead of tearing down and restarting the whole job when a node goes bad, the operator restarts only the affected processes (a *surgical*, process-level restart), re-forms the rendezvous with the remaining healthy ranks, and resumes from the most recent checkpoint on the shared file system. Its log monitoring rules additionally detect jobs that start too slowly or hang, so a stuck job is recovered rather than silently burning GPU hours.

## 🧪 The Experiment: Break Things on Purpose

:::tip Pro Tip
You'll want **TWO** terminal windows open for this demo to get the best experience. Again, make sure it's in your Code Editor instance:

- **\[T1\]**: Monitor training logs in real-time
- **\[T2\]**: Trigger the node failure and watch recovery

This gives you the full "mission control" experience! 🚀
:::

:::note
We will annotate steps with \[T1\] and \[T2\] to let you know which terminal we recommend running those steps in.
:::

\[T1\] Delete old job:

```bash
kubectl delete -f train.yaml
```

\[T1\] Change checkpoint directory to make sure we don't resume from our last training job:

```bash
export OUTPUT_DIR=/fsx/esm/new-output
```

\[T1\] Run new job:

```bash
envsubst < train.yaml | kubectl apply -f -
```

\[T1\] Use `kubetail` to log the training job, and wait until it writes a checkpoint:

```bash
kubetail hpto
```

It will write a checkpoint every 50 steps because of our `--save_steps=50` argument.

You will see logs like the following when the checkpoints are written:

```
[hpto-job-pods-0] INFO: 10.1.225.138:33484 - "GET /status HTTP/1.1" 200 OK
[hpto-job-pods-0] [default0]: 4%|▍ | 48/1136 [00:18<06:54, 2.63it/s][default0]:
[hpto-job-pods-0] [default0]: 4%|▍ | 49/1136 [00:19<06:56, 2.61it/s][default0]:
[hpto-job-pods-0] [default0]: 4%|▍ | 50/1136 [00:19<06:54, 2.62it/s][INFO|trainer.py:3478] 2025-11-26 18:26:17,010 >> Saving model checkpoint to /fsx/esm/new-output-2/checkpoint-50
[hpto-job-pods-0] [default0]:[INFO|configuration_utils.py:472] 2025-11-26 18:26:17,015 >> Configuration saved in /fsx/esm/new-output-2/checkpoint-50/config.json
[hpto-job-pods-0] [default0]:[INFO|modeling_utils.py:2690] 2025-11-26 18:26:17,097 >> Model weights saved in /fsx/esm/new-output-2/checkpoint-50/model.safetensors
[hpto-job-pods-0] [default0]:[INFO|tokenization_utils_base.py:2574] 2025-11-26 18:26:17,100 >> tokenizer config file saved in /fsx/esm/new-output-2/checkpoint-50/tokenizer_config.json
[hpto-job-pods-0] [default0]:[INFO|tokenization_utils_base.py:2583] 2025-11-26 18:26:17,103 >> Special tokens file saved in /fsx/esm/new-output-2/checkpoint-50/special_tokens_map.json
[hpto-job-pods-1] INFO: 10.1.225.138:46622 - "GET /status HTTP/1.1" 200 OK
[hpto-job-pods-0] INFO: 10.1.225.138:33484 - "GET /status HTTP/1.1" 200 OK
[hpto-job-pods-0] [default0]:
[hpto-job-pods-0] [default0]: 4%|▍ | 51/1136 [00:20<08:09, 2.22it/s][default0]:
```

\[T2\] Once it writes a checkpoint, you can emulate an instance failure by labeling a node as unhealthy. HyperPod's health agent reacts to this label and automatically replaces or reboots the node:

```bash
export NODE=$(kubectl get nodes -l node.kubernetes.io/instance-type=${INSTANCE_TYPE} | awk 'NR>1 {print $1}' | shuf -n 1)
kubectl label node $NODE \
  sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReboot \
  --overwrite=true
```

\[T2\] Get pods:

```bash
kubectl get pods -o wide
```

Example output:

```
NAME              READY   STATUS    RESTARTS   AGE   IP             NODE                          NOMINATED NODE   READINESS GATES
hpto-job-pods-0   0/1     Pending   0          8s    <none>         <none>                        <none>           <none>
hpto-job-pods-1   1/1     Running   0          93s   10.1.162.220   hyperpod-i-04ece4cf129ebc090  <none>           <none>
```

\[T2\] Describe `hyperpodpytorchjob`:

```bash
kubectl describe hyperpodpytorchjob
```

Example output:

```
Status:
  Conditions:
    Last Transition Time:  2025-08-04T22:06:18Z
    Status:                True
    Type:                  Created
    Last Transition Time:  2025-08-04T22:08:37Z
    Status:                True
    Type:                  PodsRunning
    Last Transition Time:  2025-08-04T22:08:44Z
    Message:               The fault of reason NodeFault was remediated in 94283 milliseconds.
    Reason:                Running
    Status:                True
    Type:                  Running
  Master Addr:             10.1.152.155
  Master Port:             1234
  Restart Count:           1
  Restart Status:
    Current Eval Period:     81219
    Full Job Restart Count:  0
    Restart Count:           1
Events:
  Type     Reason     Age    From                              Message
  ----     ------     ----   ----                              -------
  Normal              2m50s  hyperpod-pytorch-job-controller
  Normal   Running    2m45s  hyperpod-pytorch-job-controller
  Warning  NodeFault  64s    hyperpod-pytorch-job-controller   Found unhealthy node hyperpod-i-04b6755eb5fbb2c0f
```

You'll also notice in T1 that your job is currently paused:

```
[hpto-job-pods-0] INFO: 10.1.225.138:33484 - "GET /status HTTP/1.1" 200 OK
[hpto-job-pods-0] [default0]: 16%|█▌ | 179/1136 [01:09<06:02, 2.64it/s][default0]:
[hpto-job-pods-0] [default0]: 16%|█▌ | 180/1136 [01:09<06:01, 2.64it/s][default0]:
[hpto-job-pods-0] [default0]: 16%|█▌ | 181/1136 [01:10<06:00, 2.65it/s][default0]:
[hpto-job-pods-0] [default0]: 16%|█▌ | 182/1136 [01:10<06:00, 2.65it/s][HyperPodElasticAgent] 2025-11-26 18:27:08,260 [WARNING] [rank0-restart0] /usr/local/lib/python3.10/dist-packages/torch/distributed/elastic/agent/server/api.py:688: Received Signals.SIGTERM death signal, shutting down workers
[hpto-job-pods-0] [HyperPodElasticAgent] 2025-11-26 18:27:08,260 [INFO] [rank0-restart0] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/hyperpod_elastic_agent.py:315: Shutting down workers with signal 15...
[hpto-job-pods-0] [HyperPodElasticAgent] 2025-11-26 18:27:08,260 [WARNING] [rank0-restart0] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/pcontext/pcontext.py:127: Sending process 96 closing signal SIGTERM
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:27:08,360 [INFO] [rank1-restart0] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/hyperpod_elastic_agent.py:365: Transitioning from RUNNING to STOPPING
[hpto-job-pods-0] [HyperPodElasticAgent] 2025-11-26 18:27:08,360 [INFO] [rank0-restart0] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/hyperpod_elastic_agent.py:365: Transitioning from RUNNING to STOPPING
[hpto-job-pods-0] INFO: 10.1.225.138:33484 - "POST /stop HTTP/1.1" 200 OK
[hpto-job-pods-1] INFO: 10.1.225.138:46622 - "POST /stop HTTP/1.1" 200 OK
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:27:08,382 [INFO] [rank1-restart0] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/hyperpod_elastic_agent.py:154: Stopping workers...
```

After about ~150 seconds, you'll see an output like the following in the `describe` output from above (in `Events`):

```
Normal  Running  3s  hyperpod-pytorch-job-controller  The fault of reason NodeFault was remediated in 148952 milliseconds.
```

Your training should have also continued:

```
[hpto-job-pods-1] INFO: 10.1.225.138:43800 - "GET /status HTTP/1.1" 200 OK
[hpto-job-pods-1] INFO: 10.1.225.138:43800 - "GET /status HTTP/1.1" 200 OK
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:29:36,891 [INFO] [rank1-restart1] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/hyperpod_elastic_agent.py:365: Transitioning from READY to RUNNING
[hpto-job-pods-1] INFO: 10.1.225.138:43800 - "POST /start HTTP/1.1" 200 OK
[hpto-job-pods-1] INFO: 10.1.225.138:43800 - "GET /status HTTP/1.1" 200 OK
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:29:36,964 [INFO] [rank1-restart1] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/hyperpod_elastic_agent.py:460: [default] Agent starting workers for entrypoint: python3.
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:29:37,064 [INFO] [rank1-restart1] /usr/local/lib/python3.10/dist-packages/torch/distributed/elastic/agent/server/api.py:646: [default] Rendezvous'ing worker group
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:29:37,065 [INFO] [rank1-restart1] /usr/local/lib/python3.10/dist-packages/torch/distributed/elastic/agent/server/api.py:512: [default] Rendezvous complete for workers. Result:
[hpto-job-pods-1]   restart_count=1
[hpto-job-pods-1]   master_addr=10.1.180.119
[hpto-job-pods-1]   master_port=1234
[hpto-job-pods-1]   group_rank=1
[hpto-job-pods-1]   group_world_size=2
[hpto-job-pods-1]   local_ranks=[0]
[hpto-job-pods-1]   role_ranks=[1]
[hpto-job-pods-1]   global_ranks=[1]
[hpto-job-pods-1]   role_world_sizes=[2]
[hpto-job-pods-1]   global_world_sizes=[2]
[hpto-job-pods-1]
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:29:37,065 [INFO] [rank1-restart1] /usr/local/lib/python3.10/dist-packages/torch/distributed/elastic/agent/server/api.py:654: [default] Starting worker group
[hpto-job-pods-1] [HyperPodElasticAgent] 2025-11-26 18:29:37,065 [INFO] [rank1-restart1] /usr/local/lib/python3.10/dist-packages/hyperpod_elastic_agent/hyperpod_elastic_agent.py:221: Starting workers
```

When the job reloads its checkpoint you may see a PyTorch `FutureWarning` about `torch.load` and `weights_only`, for example:

```
FutureWarning: You are using `torch.load` with `weights_only=False` ...
  checkpoint_rng_state = torch.load(rng_file)
```

This warning is expected and can be safely ignored — the checkpoint was still loaded and training resumes normally.

\[T2\] As expected, the node should have also healed itself:

```bash
kubectl get nodes -L sagemaker.amazonaws.com/node-health-status
```

\[Optional\] If you'd like to test your custom log monitoring configurations, you can modify your arguments like so:

```yaml
logMonitoringConfiguration:
- name: JobStart
  logPattern: ".*'loss':.*"
  expectedStartCutOffInSeconds: 1   # Change this from 240 to 1
```

Now when you start your job, you'll get errors because the training starts "too slow" (greater than 1 second). This would be alerted as a `LogStateHanging_JobStart` error.

## Clean up

When you are done with this section, delete the job if it's still running. You don't need to wait for the training to be finished:

```bash
kubectl delete -f train.yaml
```

## Additional info on runPolicy

The following table describes all of the possible log monitoring configurations:

| Parameter | Description |
|---|---|
| `jobMaxRetryCount` | Maximum number of restarts at the process level. |
| `restartPolicy: numRestartBeforeFullJobRestart` | Maximum number of restarts at the process level before the operator restarts at the job level. |
| `restartPolicy: evalPeriodSeconds` | The period of evaluating the restart limit in seconds. |
| `restartPolicy: maxFullJobRestarts` | Maximum number of full job restarts before the job fails. |
| `cleanPodPolicy` | Specifies the pods that the operator should clean. Accepted values are `All`, `OnlyComplete`, and `None`. |
| `logMonitoringConfiguration` | The log monitoring rules for slow and hanging job detection. |
| `expectedRecurringFrequencyInSeconds` | Time interval between two consecutive `LogPattern` matches after which the rule evaluates to `HANGING`. |
| `expectedStartCutOffInSeconds` | Time to first `LogPattern` match after which the rule evaluates to `HANGING`. If not specified, no time limit applies. |
| `logPattern` | Regular expression that identifies log lines that the rule applies to when the rule is active. |
| `metricEvaluationDataPoints` | Number of consecutive times a rule must evaluate to `SLOW` before marking a job as `SLOW`. |
| `metricThreshold` | Threshold for value extracted by `LogPattern` with a capturing group. If not specified, metric evaluation does not apply. |
| `operator` | The inequality to apply to the monitoring configuration. Accepted values are `gt`, `gteq`, `lt`, `lteq`, and `eq`. |
| `stopPattern` | Regular expression to identify the log line at which to deactivate the rule. If not specified, the rule stays active. |

## 📊 The Results

What just happened:

- ⏱️ Detection time: ~5 seconds (HyperPod detected the unhealthy node)
- 🔧 Recovery time: ~150 seconds (pod restarted on healthy node)
- 📦 Checkpoint resume: Automatic (loaded from FSx)
- 💰 Training time lost: ~3 minutes (vs. hours with full restart)
- 🎯 Full job restarts: 0 (surgical recovery only)

Investor seems happy!

- **Investor**: "Wait... it recovered in 150 seconds? And resumed from the checkpoint?"
- **You**: "Yep. Surgical Process Level recovery. No full job restart needed."
- **Investor**: "In our current setup, that would've cost us 3 hours and $2,500. How much did you lose?"
- **You**: "About 2 minutes of training time. Maybe $0.1 in compute."
- **Investor**: "Continue..."
- **Jane Doe**: "Told you we had something special."
