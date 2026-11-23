---
title: Example - Multi-Team Scenario
sidebar_position: 3
---

# Example: multi-team scenario

## 🎮 The scenario

Your startup now has two research teams.

### Team A: internal antimicrobial research

- **Lead:** Dr. Matthew Nightingale
- **Goal:** discover new antibiotics (your core business!)
- **Needs:** 2 x `ml.g7.2xlarge` for training ESM2 models
- **Guaranteed allocation:** 1 instance
- **Priority:** high (this is your core business)

### Team B: university partner, enzyme engineering

- **Lead:** Prof. Natarajan (university partnership)
- **Goal:** engineer enzymes for industrial applications
- **Needs:** 1 x `ml.g7.2xlarge` for protein folding simulations
- **Guaranteed allocation:** 1 instance
- **Priority:** medium (important partner, but not core business)

:::note
The crawl dropped the field labels in both team descriptions. The labels above are inferred from the values; see the [live workshop](https://catalog.us-east-1.prod.workshops.aws/workshops/5344c881-4077-471e-aedf-2944bd6fe8eb/en-US/05-task-governance/02-example) for the exact wording.
:::

## 🎯 The challenge

**Your current cluster:** 2 x `ml.g7.2xlarge` instances in total.

**The problem:**

- Team A needs 2 instances but only has 1 guaranteed
- Team B has 1 instance but isn't using it yet
- How do you let Team A borrow Team B's idle resources?
- What happens when Team B needs their resources back?

**The solution:** task governance! Let's configure it.

## 📋 What you'll demonstrate

1. **Borrowing:** Team A borrows Team B's idle instance
2. **Reclaiming:** Team B submits a job and automatically reclaims their instance
3. **Preemption:** Team A's job is suspended to make room for Team B

The key benefit: all of this happens automatically with zero manual intervention!

[Let's set it up →](./04-configure-policies.md)
