---
title: LLM Training Lifecycle
layout: page
permalink: /docs/ml/llm-training-lifecycle/
summary: "LLM lifecycle from pretraining and continued pretraining to SFT, RLHF, DPO, RLAIF, preference data, synthetic data, data filtering, and stage-specific evaluation."
tags:
  - machine-learning
  - llm
  - training
  - alignment
---

# LLM Training Lifecycle

LLM behavior is built in stages. Each stage changes data, objective, evaluation, and risk. A production team needs to know which stage created the behavior it is trying to preserve or change.

## Lifecycle Stages

| Stage | Objective | Main Risk |
| --- | --- | --- |
| Pretraining | Learn broad language/statistical structure from large corpora. | Data quality, memorization, contamination, compute cost. |
| Continued pretraining | Adapt base model to domain distribution. | Forgetting, domain overfit, data licensing. |
| Supervised fine-tuning | Teach instruction following and task format. | Bad examples, template drift, eval leakage. |
| Preference tuning | Prefer better answers over worse answers. | Labeler bias, reward hacking, oversmoothing. |
| RLHF | Optimize against a reward model with RL. | Instability and reward-model misspecification. |
| DPO | Optimize directly from preference pairs. | Pair quality and preference coverage. |
| RLAIF | Use AI feedback to scale preference signals. | Judge-model bias and correlated failure. |

## Data Filtering

Data filtering removes:

- duplicates and near-duplicates,
- unsafe or disallowed data,
- low-quality boilerplate,
- private or secret material,
- eval contamination,
- malformed examples,
- language or domain outliers when not intended.

## Synthetic Data

Synthetic data can fill coverage gaps, but it can also amplify model errors or create narrow, unrealistic patterns. Treat generated examples as candidates that need review, filtering, and eval.

## Stage-Specific Evaluation

| Stage | Eval Focus |
| --- | --- |
| Pretraining | Perplexity, contamination, broad capability probes. |
| Continued pretraining | Domain understanding and general regression. |
| SFT | Instruction following, format, refusal, task success. |
| Preference tuning | Win rate, safety, helpfulness, calibration. |
| Release | Golden set, red team, latency, cost, rollback. |

## Practical Lab: Training Stage Audit

```text
model_candidate:
  base_model:
  continued_pretraining_data:
  sft_dataset:
  preference_dataset:
  chat_template:
  eval_report:
  safety_report:
  rollback_artifacts:
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does continued pretraining usually adapt?" answer="It adapts a base model to a domain distribution before task-specific instruction tuning." %}
  {% include study-card.html question="Why is synthetic data risky?" answer="It can amplify model errors, narrow style, or unrealistic patterns if not reviewed and evaluated." %}
  {% include study-card.html question="How is DPO different from RLHF at a high level?" answer="DPO learns directly from preference pairs without a separate online RL loop." %}
</div>

## References

- [Training language models to follow instructions with human feedback](https://arxiv.org/abs/2203.02155)
- [Direct Preference Optimization](https://arxiv.org/abs/2305.18290)
- [Constitutional AI](https://arxiv.org/abs/2212.08073)
