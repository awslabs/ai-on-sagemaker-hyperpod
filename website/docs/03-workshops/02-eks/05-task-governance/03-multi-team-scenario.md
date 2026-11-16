---
title: "Example: Multi-Team Scenario"
sidebar_position: 3
---

# Example: Multi-Team Scenario

## 🎮 The Scenario

Your startup now has **two research teams**:

### Team A: Internal Antimicrobial Research

- **Lead**: Dr. Matthew Nightingale
- **Goal**: Discover new antibiotics (your core business!)
- **Needs**: 2 x `ml.g5.2xlarge` for training ESM2 models
- **Guaranteed quota**: 1 instance
- **Priority**: High (this is your bread and butter)

### Team B: University Partner - Enzyme Engineering

- **Lead**: Prof. Natarajan (University partnership)
- **Goal**: Engineer enzymes for industrial applications
- **Needs**: 1x `ml.g5.2xlarge` for protein folding simulations
- **Guaranteed quota**: 1 instance
- **Priority**: Medium (important partner, but not core business)

## 🎯 The Challenge

**Your current cluster**: 2x `ml.g5.2xlarge` instances (total)

**The problem**:

- Team A needs 2 instances but only has 1 guaranteed
- Team B has 1 instance but isn't using it yet
- How do you let Team A borrow Team B's idle resources?
- What happens when Team B needs their resources back?

**The solution**: Task governance! Let's configure it.

## 📋 What You'll Demonstrate

1. **Borrowing**: Team A borrows Team B's idle instance
2. **Reclaiming**: Team B submits a job and automatically reclaims their instance
3. **Preemption**: Team A's job is suspended to make room for Team B

**The wow factor**: All of this happens automatically with zero manual intervention!

[Let's set it up →](./04-configure-policies.md)
