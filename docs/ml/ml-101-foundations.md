---
title: ML 101 Foundations
layout: page
permalink: /docs/ml/ml-101-foundations/
summary: "Beginner ML foundations: what ML is, when not to use it, datasets, features, labels, splits, training, inference, metrics, overfitting, and bias/variance."
tags:
  - machine-learning
  - foundations
  - ml-101
  - evaluation
---

# ML 101 Foundations

Machine learning is useful when rules are hard to write directly but examples, feedback, or patterns are available. It is not magic automation. A model learns a mapping from inputs to outputs, and every design choice changes what it can learn, how it fails, and how operators can verify it.

## First Concepts

| Concept | Practical Meaning |
| --- | --- |
| Example | One row, document, image, event, or interaction the model learns from or predicts on. |
| Feature | Input signal available to the model. |
| Label | Target output used for supervised learning. |
| Training | Adjusting model weights or parameters from data. |
| Inference | Using the trained model to make predictions or generate outputs. |
| Evaluation | Measuring behavior on data not used to train the model. |

## When Not To Use ML

Use rules, queries, or deterministic code when the requirement is clear, auditable, and stable. ML is usually a bad first choice when:

- there is no reliable training or feedback data,
- a wrong answer has high cost and no review path,
- the decision must be exactly reproducible and explainable by policy,
- a simple threshold, SQL query, or rules engine solves the problem,
- the system cannot tolerate drift, monitoring, or retraining work.

## Common Problem Types

| Problem | Output | Example Metric |
| --- | --- | --- |
| Classification | Class or probability. | Accuracy, F1, precision, recall. |
| Regression | Numeric value. | MAE, RMSE, R2. |
| Ranking | Ordered candidates. | NDCG, MRR, Recall@k. |
| Clustering | Groups without labels. | Silhouette, manual review. |
| Generation | Text, image, audio, code, action. | Task score, human review, faithfulness, safety. |

## Dataset Splits

| Split | Purpose |
| --- | --- |
| Train | Fit model parameters. |
| Validation | Tune hyperparameters and select candidates. |
| Test | Final held-out estimate. |
| Golden set | Critical examples that must not regress. |

Split by the thing that can leak. For users, split by user. For time series, split by time. For documents, split by source or near-duplicate cluster.

## Overfitting and Underfitting

| Symptom | Meaning | Fix |
| --- | --- | --- |
| Train bad, validation bad | Underfitting or weak features/model. | Better features, model, objective, or data. |
| Train good, validation bad | Overfitting or leakage in train. | More data, regularization, simpler model, better split. |
| Validation good, production bad | Distribution shift, leakage, weak eval, product mismatch. | Better eval slices, monitoring, and feedback. |

## Practical Lab: Tiny Classifier Framing

```text
Problem: predict whether a support ticket needs escalation.
Input features: product, severity text, customer tier, recent incidents.
Label: escalated_within_24h.
Split: by customer and ticket creation time.
Metric: recall for high-priority escalations plus false-positive review cost.
Fallback: human review for low-confidence predictions.
```

The lab is about framing, not code. If this framing is wrong, a better model will optimize the wrong target.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the difference between training and inference?" answer="Training adjusts model parameters from data; inference uses trained parameters to produce predictions or outputs." %}
  {% include study-card.html question="Why split datasets by user or time?" answer="It prevents leakage where similar examples or future information make evaluation look better than production reality." %}
  {% include study-card.html question="When should you avoid ML?" answer="When a deterministic rule is clear, auditable, stable, and cheaper to operate than an ML lifecycle." %}
</div>

## References

- [Google Machine Learning Crash Course](https://developers.google.com/machine-learning/crash-course)
- [scikit-learn User Guide](https://scikit-learn.org/stable/user_guide.html)
- [Hidden Technical Debt in Machine Learning Systems](https://papers.nips.cc/paper_files/paper/2015/hash/86df7dcfd896fcaf2674f757a2463eba-Abstract.html)
