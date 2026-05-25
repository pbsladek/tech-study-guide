---
title: ML Data Pipelines and Feature Stores
layout: page
permalink: /docs/ml/data-pipelines-feature-stores/
summary: "ML data engineering with dataset versioning, feature stores, lineage, data contracts, train/serve skew, point-in-time correctness, privacy, and reproducibility."
tags:
  - machine-learning
  - data
  - feature-store
  - pipelines
---

# ML Data Pipelines and Feature Stores

Data pipelines define what the model can learn and what it can see at inference time. A strong model trained on leaky, stale, mislabeled, or irreproducible data becomes a fragile system.

## First Checks

```bash
date -Is
ls -lh data/
find data -maxdepth 2 -type f | sort | head
```

In production, replace filesystem checks with source inventory, lineage, data contracts, and dataset version manifests.

## Pipeline Boundaries

| Boundary | What To Version |
| --- | --- |
| Raw source | Source system, extraction query, timestamp, schema, permissions. |
| Cleaning | Dedup rules, filters, redaction, normalization, language detection. |
| Labeling | Label source, instructions, adjudication, quality audits. |
| Feature generation | Code version, backfill window, joins, aggregation windows. |
| Dataset split | Split key, time boundary, leakage checks, holdout policy. |
| Training manifest | Dataset hashes, preprocessing, tokenizer, feature schema, model config. |

## Feature Store Model

Feature stores help when the same features need offline training and low-latency online serving.

| Concept | Why It Matters |
| --- | --- |
| Offline store | Historical feature values for training and backfills. |
| Online store | Fresh low-latency features for inference. |
| Entity key | Stable join key such as user, account, host, document, or device. |
| Event time | Time the fact happened; needed for point-in-time correctness. |
| Materialization | Copying computed features into serving storage. |
| Freshness SLA | Maximum tolerated lag between source and online value. |

## Train/Serve Skew

Train/serve skew happens when training features differ from inference features. Common causes:

- training uses future data unavailable at inference,
- online features lag or are missing,
- preprocessing code differs between batch and request path,
- categorical vocabularies or tokenizers drift,
- time windows are computed differently,
- null/default behavior differs.

Skew check:

```text
For each feature:
  source system
  event-time semantics
  offline transform
  online transform
  null/default policy
  freshness target
  owner
```

## Data Quality Gates

| Gate | Blocks |
| --- | --- |
| Schema contract | Missing fields, type drift, enum drift. |
| Range checks | Impossible values, unit changes, clipped distributions. |
| Freshness checks | Late sources, failed materialization, stale online store. |
| Leakage checks | Post-outcome fields, future timestamps, duplicate entities across splits. |
| Privacy checks | PII, secrets, disallowed training data, retention violations. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is train/serve skew?" answer="A mismatch between features used during training and features available or computed at inference time." %}
  {% include study-card.html question="Why does event time matter for ML features?" answer="It prevents training from using facts that would not have been known at prediction time." %}
  {% include study-card.html question="When does a feature store help?" answer="When the same feature definitions must support offline training and online low-latency inference." %}
</div>

## References

- [Feast documentation](https://docs.feast.dev/)
- [Hidden Technical Debt in Machine Learning Systems](https://papers.nips.cc/paper_files/paper/2015/hash/86df7dcfd896fcaf2674f757a2463eba-Abstract.html)
