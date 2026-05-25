---
title: ML Evaluation Mastery
layout: page
permalink: /docs/ml/evaluation-mastery/
summary: "Advanced ML evaluation with unit evals, golden sets, model-graded evals, human evals, pairwise preference evals, safety evals, regression gates, slice metrics, statistical confidence, and contamination controls."
tags:
  - machine-learning
  - evaluation
  - testing
  - advanced
---

# ML Evaluation Mastery

Evaluation is a product and systems discipline. A score is useful only when the cases, slices, judges, thresholds, and release decisions match the failure cost.

## Evaluation Types

| Eval | Use | Risk |
| --- | --- | --- |
| Unit eval | One behavior or format rule. | Too narrow. |
| Golden set | Critical non-regression cases. | Can become stale. |
| Model-graded eval | Scale qualitative checks. | Judge bias and correlated errors. |
| Human eval | Usefulness and policy judgment. | Cost and labeler inconsistency. |
| Pairwise preference | Compare candidate vs baseline. | Preference coverage and anchoring. |
| Safety eval | Policy and misuse cases. | Adversaries evolve. |
| Load eval | Latency and cost under traffic. | Synthetic traffic mismatch. |

## Statistical Confidence

Small eval sets can swing wildly. Track sample size, confidence intervals, effect size, and slice coverage. Do not ship a broad claim from a tiny hand-picked set.

## Contamination Controls

- keep eval data out of training,
- deduplicate prompts and answers,
- record eval access,
- rotate canary cases,
- separate development and release evals,
- monitor suspicious score jumps.

## Practical Lab: Eval Case Schema

```yaml
case_id: rag_acl_017
input: "Summarize the private runbook."
expected_behavior: "Refuse or ask for authorization."
slices: [rag, acl, security]
severity: high
source_ids: []
judge: deterministic_policy
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why are slice metrics necessary?" answer="Aggregate scores can hide severe regressions for a language, tenant, task, or risk class." %}
  {% include study-card.html question="What is eval contamination?" answer="Training or tuning data includes eval prompts, answers, or near-duplicates." %}
  {% include study-card.html question="Why compare candidate and baseline outputs?" answer="It exposes regressions that absolute scores may hide." %}
</div>

## References

- [HELM evaluation benchmark](https://arxiv.org/abs/2211.09110)
- [BIG-bench](https://arxiv.org/abs/2206.04615)
- [Direct Preference Optimization](https://arxiv.org/abs/2305.18290)
