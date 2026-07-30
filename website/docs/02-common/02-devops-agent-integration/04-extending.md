---
title: Extending & APIs
sidebar_position: 4
---

# Extending the solution

The solution has two extension points, which serve different purposes:

## 1. Extending detection (what conditions are caught)

- **Event-driven path:** the webhook bridge Lambda drops `Info`-level events
  and forwards all `Warn` and `Error` level HyperPod events to DevOps Agent.
  This typically does not need modification - it already catches all
  actionable events.
- **Polling-based path:** the periodic-audit Lambda checks Kubernetes state.
  To detect additional conditions (e.g. GPU allocation below a threshold or
  specific Pod labels stuck in error states), add that logic to the Lambda
  code.

## 2. Extending reasoning (how the agent investigates and classifies)

Edit the **plain-English skill definitions**. For example, you can teach the
RCA skill new classification rules, add domain-specific context about your
workload's expected behavior, or adjust the recurrence thresholds.

**Detection is code; reasoning is natural language.** Both are in the repo
and designed to be customized independently. See
[IMPLEMENTATION.md](https://github.com/awslabs/awsome-distributed-ai/blob/main/1.architectures/5.sagemaker-hyperpod/tools/devops-agent/IMPLEMENTATION.md#authoring-your-own-skill-custom-detection-rules)
in the source repo for the full skill-authoring guide.

## DevOps Agent APIs used by this solution

For readers interested in the programmatic integration, here are the key
[DevOps Agent APIs](https://docs.aws.amazon.com/boto3/latest/reference/services/devops-agent.html)
this solution calls:

| Component | API | Purpose |
| --- | --- | --- |
| Webhook provisioner (deployment) | `register_service` | Register the generic webhook service with DevOps Agent |
| Webhook provisioner (deployment) | `associate_service` | Associate the webhook with the Agent Space |
| Skill uploader (deployment) | `list_assets` | Check if a skill already exists |
| Skill uploader (deployment) | `create_asset` / `update_asset` | Upload or update the triage and RCA skill definitions |
| Email notifier (runtime) | `get_backlog_task` | Retrieve task metadata (title, priority, timestamps) |
| Email notifier (runtime) | `list_journal_records` | Retrieve findings, symptoms, and gaps from the investigation journal |
| Teardown | `disassociate_service` / `deregister_service` / `delete_asset` | Clean up on stack deletion |

## What's next

From here you can customize the solution for your environment:

- **Adjust the CloudFormation parameters** - tune the periodic-audit
  schedule, `CrashLoopBackOff` thresholds, `NotReady` node percentages,
  namespace filtering, and email recipients - all without code changes.
  See the [parameter reference](./02-deploy.md#optional-parameters).
- **Customize the verdict thresholds** - the recovery time budgets and
  recurrence thresholds live in the RCA skill (sourced from the HyperPod
  mental model bundled with the skill). Edit and redeploy.
- **Extend detection** - modify the periodic-audit Lambda to check for
  additional Kubernetes conditions specific to your workloads (e.g. GPU
  allocation below a threshold, specific Pod labels stuck in error states).
- **Extend reasoning** - edit the triage or RCA skill definitions to adjust
  classification rules, add domain context about your expected cluster
  behavior, or tune the recurrence thresholds.
- **Add notification channels** - connect Slack, ServiceNow, PagerDuty, or
  Microsoft Teams via DevOps Agent's built-in integrations, or via a sibling
  EventBridge rule on the same `aws.aidevops` event stream that the email
  notifier uses.

The skills are plain English. Iterate on them the same way you'd iterate on
a runbook.
