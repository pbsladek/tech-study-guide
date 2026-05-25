---
title: ML Alignment and Evaluation
layout: page
permalink: /docs/ml/alignment-evaluation/
summary: "Alignment, evaluation, RLHF, preference tuning, DPO, safety policy, red teaming, regression gates, calibration, and monitoring."
tags:
  - machine-learning
  - alignment
  - evaluation
  - safety
---

# ML Alignment and Evaluation

Alignment is the work of making model behavior match intended objectives, constraints, and user expectations. Evaluation is how you prove that behavior. For production systems, alignment is not a one-time training step; it is a lifecycle of data, policy, tests, monitoring, and rollback.

## First Checks

```bash
python - <<'PY'
eval_case = {"input": "user request", "expected": "policy-compliant answer"}
print(eval_case.keys())
PY
```

Start with a written behavior policy and eval cases before changing prompts or weights.

## Alignment Techniques

| Technique | Purpose |
| --- | --- |
| Instruction tuning | Teach model to follow task instructions and response formats. |
| RLHF | Optimize behavior from human preference/reward signals. |
| DPO-style preference tuning | Train from preference pairs without a separate online RL loop. |
| Constitutional/policy methods | Use explicit principles or policies to critique or steer outputs. |
| Safety filters | Detect or block disallowed inputs/outputs around the model. |
| Tool guardrails | Restrict actions the model can take through tools. |

Alignment does not remove the need for product constraints and monitoring.

## Evaluation Layers

| Eval Layer | Question |
| --- | --- |
| Unit cases | Does one prompt/input behave correctly? |
| Golden set | Does the system preserve known critical behavior? |
| Adversarial/red-team | What happens under misuse or edge pressure? |
| Regression eval | Did a model, prompt, data, or tool change break old behavior? |
| Human review | Are outputs useful, calibrated, and policy-aligned? |
| Online monitoring | What happens after deployment under real distribution? |

Use separate evals for retrieval, generation, tool use, latency, cost, and safety.

## Common Metrics

- accuracy,
- F1/precision/recall,
- exact match,
- BLEU/ROUGE for some text tasks,
- faithfulness and citation support,
- preference win rate,
- harmful completion rate,
- refusal quality,
- calibration,
- latency and cost.

No single metric proves alignment. Pick metrics that match failure cost.

## Red Teaming

Red teaming tries to find failures before production users do. Include:

- prompt injection,
- jailbreak attempts,
- sensitive data extraction,
- unsafe tool calls,
- hallucinated citations,
- policy boundary cases,
- multilingual and encoding tricks,
- stale or conflicting retrieval sources.

## Release Gates

Before release, require:

1. model/prompt/retrieval/tool version recorded,
2. eval set pass threshold,
3. regression comparison against previous system,
4. safety review for high-risk changes,
5. monitoring and rollback plan,
6. sample review of failures, not only aggregate score.

## Evaluation Governance and Release Gaps

Evaluation needs ownership, sampling discipline, release gates, and monitoring. A green score without governance is weak evidence.

| Gap | What To Fill | Operational Check |
| --- | --- | --- |
| ML-GAP-073 Eval Dataset Governance | Version evals, owners, allowed use, refresh cadence, and contamination controls. | Record who can edit eval cases and why each case exists. |
| ML-GAP-074 Golden Sets | Maintain high-value cases that must not regress across model, prompt, retrieval, or tool changes. | Block release when critical golden cases fail. |
| ML-GAP-075 Slice-Based Metrics | Break metrics by language, tenant, product, topic, risk class, and input shape. | Review worst slices, not only aggregate scores. |
| ML-GAP-076 Regression Gates | Compare candidate systems against the current production baseline with predefined thresholds. | Require explicit approval for any accepted regression. |
| ML-GAP-077 Human Preference Labeling | Define labeler instructions, disagreement resolution, calibration, and quality audits. | Track labeler agreement and spot-check preference pairs. |
| ML-GAP-078 RLHF vs DPO Boundaries | Know whether the system uses reward modeling, online RL, offline preference optimization, or simple SFT. | Document what objective was optimized and what failure it can introduce. |
| ML-GAP-079 Red Team Taxonomy | Organize adversarial tests by misuse path, policy area, tool risk, data exposure, and prompt-injection class. | Ensure every high-risk taxonomy bucket has cases. |
| ML-GAP-080 Policy Severity Rubric | Convert behavior failures into severity levels with consistent release and incident handling. | Map each eval failure to severity, owner, and required action. |
| ML-GAP-081 Calibration and Abstention | Systems need to know when to answer, abstain, ask for clarification, or escalate. | Measure confidence/error curves and abstention quality. |
| ML-GAP-082 Fairness and Bias Checks | Evaluate harmful disparity, proxy features, representation gaps, and unequal error rates. | Review metrics and examples across protected or sensitive slices where applicable. |
| ML-GAP-083 Online Monitoring | Production data can differ from evals and should be monitored for behavior, safety, latency, and cost. | Track sampled outputs, user feedback, refusal rates, and incident signals. |
| ML-GAP-084 Drift Detection | Detect shifts in inputs, retrieved documents, labels, user goals, and model outputs. | Compare embedding distributions, topic mix, outcome rates, and eval decay over time. |
| ML-GAP-085 Canary Rollout | Release new systems to limited traffic before global promotion. | Monitor canary metrics against baseline and rollback automatically on breach. |
| ML-GAP-086 Incident Feedback Loop | Turn production failures into eval cases, policy updates, data fixes, or tool constraints. | Require every high-severity incident to produce a regression test or documented exception. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is alignment in ML systems?" answer="The work of making model behavior match intended objectives, constraints, policies, and user expectations." %}
  {% include study-card.html question="Why is a regression eval necessary?" answer="A new model, prompt, retrieval setup, or fine-tune can improve one metric while breaking old required behavior." %}
  {% include study-card.html question="What does red teaming try to find?" answer="Misuse paths, edge cases, policy failures, unsafe tool calls, and behavior that ordinary evals miss." %}
  {% include study-card.html question="Why is online monitoring part of alignment?" answer="Production traffic can differ from eval data, so behavior must be checked after deployment." %}
</div>

## References

- [Training language models to follow instructions with human feedback](https://arxiv.org/abs/2203.02155)
- [Direct Preference Optimization](https://arxiv.org/abs/2305.18290)
- [HELM evaluation benchmark](https://arxiv.org/abs/2211.09110)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
