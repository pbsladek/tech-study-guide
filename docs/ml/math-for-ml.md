---
title: Math for ML
layout: page
permalink: /docs/ml/math-for-ml/
summary: "Practical math for machine learning: vectors, matrices, tensors, dot products, cosine similarity, gradients, softmax, cross entropy, KL divergence, probability, and attention intuition."
tags:
  - machine-learning
  - math
  - tensors
  - optimization
---

# Math for ML

ML math is mostly about representing data as numbers, measuring error, and updating parameters to reduce that error. You do not need to derive every theorem to operate ML systems, but you do need to recognize what the math controls.

## First Checks

```python
import numpy as np

a = np.array([1.0, 2.0, 3.0])
b = np.array([1.0, 0.0, 1.0])
print(float(a @ b))
print(float((a @ b) / (np.linalg.norm(a) * np.linalg.norm(b))))
```

This computes a dot product and cosine similarity, the same basic shape behind linear models and embedding search.

## Core Objects

| Object | Meaning |
| --- | --- |
| Scalar | One number. |
| Vector | Ordered list of numbers. |
| Matrix | 2D table of numbers. |
| Tensor | N-dimensional numeric array. |
| Dot product | Weighted similarity or projection. |
| Norm | Size or length of a vector. |
| Gradient | Direction that changes a function fastest. |

## Probability and Scores

| Concept | Why It Matters |
| --- | --- |
| Probability | Represents uncertainty or expected frequency. |
| Logit | Raw model score before probability normalization. |
| Softmax | Converts logits into a probability distribution. |
| Cross entropy | Penalizes confident wrong predictions. |
| KL divergence | Measures distribution mismatch. |
| Calibration | Checks whether predicted confidence matches observed correctness. |

## Gradient Descent

Training repeatedly:

1. runs the model,
2. computes a loss,
3. computes gradients,
4. updates parameters opposite the gradient,
5. evaluates on held-out data.

The learning rate controls update size. Too small is slow; too large can diverge.

## Attention Intuition

Attention is weighted retrieval inside a model layer. Queries ask what a token needs, keys describe what other tokens offer, and values carry the information that gets mixed.

| Term | Operational Meaning |
| --- | --- |
| Query | What this position is looking for. |
| Key | What another position can match on. |
| Value | Information copied or mixed if matched. |
| Attention weights | Normalized scores over positions. |

## Practical Lab: Cosine Similarity

```python
import numpy as np

docs = {
    "postgres": np.array([0.9, 0.1, 0.0]),
    "kubernetes": np.array([0.1, 0.8, 0.1]),
    "gpu": np.array([0.0, 0.2, 0.9]),
}
query = np.array([0.8, 0.2, 0.0])

def cosine(a, b):
    return float((a @ b) / (np.linalg.norm(a) * np.linalg.norm(b)))

print(sorted((cosine(query, v), k) for k, v in docs.items()), reverse=True)
```

This toy example shows why embeddings and distance metrics are system contracts.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a dot product measure in ML?" answer="A weighted alignment between two vectors, often used for scoring or similarity." %}
  {% include study-card.html question="What is a gradient?" answer="A direction and magnitude showing how changing parameters changes the loss." %}
  {% include study-card.html question="Why does softmax matter?" answer="It turns raw logits into a probability distribution over choices." %}
</div>

## References

- [Mathematics for Machine Learning](https://mml-book.github.io/)
- [PyTorch autograd mechanics](https://pytorch.org/docs/stable/notes/autograd.html)
- [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
