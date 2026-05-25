---
title: MLOps Systems
layout: page
permalink: /docs/ml/mlops-systems/
summary: "MLOps systems with model registries, feature stores, training pipelines, artifact versioning, reproducibility, batch and online inference, canaries, shadow evaluation, rollback, and cost governance."
tags:
  - machine-learning
  - mlops
  - systems
  - deployment
---

# MLOps Systems

MLOps is the system around the model: data, training, registry, release, serving, monitoring, incident response, governance, and cost control. The model artifact is only one piece.

## System Components

| Component | Job |
| --- | --- |
| Data catalog | Tracks sources, schemas, ownership, and classification. |
| Feature store | Keeps offline and online features consistent. |
| Training pipeline | Reproducible training and evaluation workflow. |
| Model registry | Stores approved artifacts, metadata, metrics, and lineage. |
| Serving platform | Routes traffic to model/runtime versions. |
| Monitor | Watches data, behavior, latency, safety, and cost. |
| Release controller | Handles canary, rollback, approval, and audit. |

## Deployment Modes

| Mode | Use | Risk |
| --- | --- | --- |
| Batch inference | Offline scoring and reports. | Stale predictions and backfill errors. |
| Online inference | Low-latency request/response. | Tail latency and feature freshness. |
| Streaming inference | Continuous event decisions. | Ordering, duplication, exactly-once expectations. |
| Shadow evaluation | Test candidate without user-visible output. | Privacy and extra cost. |
| Canary | Limited production traffic. | Requires per-version monitoring. |

## Practical Lab: Model Registry Record

```yaml
model_id: ticket-escalation-v4
artifact_uri: s3://models/ticket-escalation/v4
training_data: dataset_2026_05_01
feature_schema: features_v7
eval_report: eval_2026_05_02
owner: ml-platform
approved_for: production-canary
rollback_to: ticket-escalation-v3
```

## Cost Governance

Track cost by model, tenant, route, prompt tokens, output tokens, GPU hours, retrieval calls, reranker calls, and human review. Cost surprises are operational incidents.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a model registry store besides weights?" answer="Metadata, lineage, metrics, approvals, artifact URI, versions, owners, and deployment status." %}
  {% include study-card.html question="Why use shadow evaluation?" answer="It tests a candidate on real traffic without making its output user-visible." %}
  {% include study-card.html question="Why is cost governance part of MLOps?" answer="Token, GPU, retrieval, and review costs can regress independently of quality." %}
</div>

## References

- [MLflow Model Registry](https://mlflow.org/docs/latest/model-registry.html)
- [Kubeflow Pipelines](https://www.kubeflow.org/docs/components/pipelines/)
- [Hidden Technical Debt in Machine Learning Systems](https://papers.nips.cc/paper_files/paper/2015/hash/86df7dcfd896fcaf2674f757a2463eba-Abstract.html)
