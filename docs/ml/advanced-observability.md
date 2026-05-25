---
title: Advanced ML Observability
layout: page
permalink: /docs/ml/advanced-observability/
summary: "Advanced ML observability with drift detection, data quality monitoring, online evals, human feedback loops, trace schemas, prompt/retrieval/model/tool observability, safety monitoring, cost monitoring, and incident review templates."
tags:
  - machine-learning
  - observability
  - monitoring
  - advanced
---

# Advanced ML Observability

Advanced ML observability connects production telemetry to behavior. You need enough evidence to explain whether a failure came from data, retrieval, prompt, model, runtime, tool, policy, or product integration.

## Signal Taxonomy

| Signal | Examples |
| --- | --- |
| Data quality | Missing fields, schema drift, freshness, outliers, label delay. |
| Input drift | Topic mix, language, token length, embeddings, feature distributions. |
| Output drift | Refusal rate, sentiment, toxicity, citation use, tool-call frequency. |
| Retrieval | Recall probes, top-k scores, filter decisions, index version. |
| Serving | TTFT, ITL, queue time, GPU memory, error rate, cost. |
| Safety | Policy violation rate, jailbreak success, sensitive-data exposure. |

## Trace Schema

```yaml
trace_id:
user_slice:
model_id:
prompt_version:
retrieval_index:
tools_called:
policy_version:
latency:
token_counts:
output_hash:
review_label:
```

Store enough to debug without storing unnecessary sensitive data.

## Online Evaluation

Online evals sample production traffic for delayed review. They should be stratified by tenant, language, route, risk, prompt length, model version, and retrieval path.

## Incident Review Template

```text
impact:
detection:
affected_versions:
failure_layer:
missed_monitor:
rollback:
new_eval_case:
new_alert:
owner:
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is output drift?" answer="A change in model outputs such as refusal rate, citation use, tool calls, safety failures, or style." %}
  {% include study-card.html question="Why stratify online eval samples?" answer="Rare but important slices can disappear inside aggregate production metrics." %}
  {% include study-card.html question="What should every ML incident produce?" answer="A clearer detection signal, regression case, policy update, data fix, or documented exception." %}
</div>

## References

- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [Evidently documentation](https://docs.evidentlyai.com/)
- [vLLM Production Metrics](https://docs.vllm.ai/en/stable/usage/metrics/)
