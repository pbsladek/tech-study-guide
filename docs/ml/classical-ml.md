---
title: Classical ML
layout: page
permalink: /docs/ml/classical-ml/
summary: "Classical machine learning with linear models, logistic regression, trees, random forests, gradient boosting, SVMs, k-means, feature engineering, and tabular workflows."
tags:
  - machine-learning
  - classical-ml
  - tabular
  - scikit-learn
---

# Classical ML

Classical ML remains important because many production problems are tabular, small-data, latency-sensitive, or need strong interpretability. Gradient boosted trees or logistic regression can beat deep learning when features are structured and data volume is moderate.

## Command Examples

```python
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression

X, y = load_iris(return_X_y=True)
X_train, X_test, y_train, y_test = train_test_split(X, y, random_state=7)
model = LogisticRegression(max_iter=1000).fit(X_train, y_train)
print(model.score(X_test, y_test))
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Python example` | A score such as `0.97`. | Demonstrates a complete train/test split and baseline classifier score. |

## Model Families

| Family | Strength | Watch Out For |
| --- | --- | --- |
| Linear regression | Simple numeric prediction. | Nonlinear relationships and outliers. |
| Logistic regression | Interpretable classification baseline. | Feature scaling and class imbalance. |
| Decision trees | Human-readable splits. | Overfitting deep trees. |
| Random forests | Robust tabular baseline. | Larger memory and less direct explanations. |
| Gradient boosting | Strong tabular performance. | Leakage and careful validation. |
| SVMs | Good margins for some small datasets. | Scaling to large datasets. |
| k-means | Simple clustering. | Choosing k and distance metric assumptions. |

## Feature Engineering

Feature engineering translates raw records into model-ready signals:

- numeric scaling,
- categorical encoding,
- time-window aggregates,
- missing-value flags,
- text counts or embeddings,
- domain-specific ratios,
- leakage removal.

## Tabular Workflow

1. Define prediction time and label time.
2. Build point-in-time correct features.
3. Split by time, entity, or source.
4. Train a simple baseline.
5. Add features and compare by slice.
6. Calibrate and choose thresholds.
7. Monitor feature drift and label delay.

## Practical Lab: Baseline Before Complexity

```text
Baseline plan:
  model: logistic regression
  split: last 30 days as test
  metric: recall at fixed review capacity
  slices: customer tier, product, language
  challenger: gradient boosted trees
```

The lab target is not highest score. It is proving whether a simple model is good enough and where it fails.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="When can classical ML beat deep learning?" answer="When data is structured, moderate in size, and feature engineering captures the main signal." %}
  {% include study-card.html question="Why start with a simple baseline?" answer="It exposes data and metric problems before model complexity hides them." %}
  {% include study-card.html question="What is the main tabular ML leakage risk?" answer="Features that contain future or post-outcome information unavailable at prediction time." %}
</div>

## References

- [scikit-learn Supervised Learning](https://scikit-learn.org/stable/supervised_learning.html)
- [XGBoost documentation](https://xgboost.readthedocs.io/)
- [LightGBM documentation](https://lightgbm.readthedocs.io/)
