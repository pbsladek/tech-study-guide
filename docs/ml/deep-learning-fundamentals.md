---
title: Deep Learning Fundamentals
layout: page
permalink: /docs/ml/deep-learning-fundamentals/
summary: "Deep learning fundamentals: neural networks, layers, activations, embeddings, CNNs, RNNs, transformers, optimizers, normalization, regularization, initialization, and training stability."
tags:
  - machine-learning
  - deep-learning
  - neural-networks
  - training
---

# Deep Learning Fundamentals

Deep learning stacks differentiable layers so a model can learn representations from raw or lightly processed data. The same core mechanics appear in vision, speech, recommendation, language, and multimodal systems.

## Command Examples

```python
import torch
from torch import nn

model = nn.Sequential(nn.Linear(8, 16), nn.ReLU(), nn.Linear(16, 2))
x = torch.randn(4, 8)
print(model(x).shape)
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Python example` | `A numeric score, tensor shape, token IDs, retrieved IDs, or explicit error.` | Shows the example produces measurable output instead of silent success. |

## Core Building Blocks

| Block | Role |
| --- | --- |
| Linear layer | Weighted projection from inputs to outputs. |
| Activation | Adds nonlinearity so networks can model complex functions. |
| Embedding | Learned vector lookup for tokens, categories, users, or items. |
| Convolution | Local pattern detector for grids and signals. |
| Recurrent layer | Processes sequence state over time. |
| Attention | Mixes information across positions by learned relevance. |
| Normalization | Stabilizes activations or residual streams. |
| Dropout | Regularizes by randomly masking activations during training. |

## Training Stability

| Issue | Signal | Control |
| --- | --- | --- |
| Exploding gradients | `nan` loss, huge gradient norm. | Gradient clipping, lower LR, normalization. |
| Vanishing gradients | No learning in early layers. | Residual connections, better initialization, normalization. |
| Overfit | Train improves while validation worsens. | Data, regularization, early stopping. |
| Poor initialization | Slow or unstable start. | Established initializers and architecture defaults. |
| Bad schedule | Loss spikes or plateaus. | Warmup, cosine decay, step decay, LR sweep. |

## Architecture Families

| Family | Typical Use |
| --- | --- |
| MLP | Tabular, embeddings, simple features. |
| CNN | Images, audio spectrograms, local signal patterns. |
| RNN/LSTM/GRU | Legacy sequence and time-series workloads. |
| Transformer | Language, code, multimodal, long-context modeling. |
| Diffusion network | Generative media through denoising. |

## Practical Lab: Training Stability Checklist

```text
Before a long run:
  one batch overfits: yes/no
  gradient norms logged: yes/no
  validation split clean: yes/no
  checkpoint resume tested: yes/no
  learning-rate schedule plotted: yes/no
  eval mode used for validation: yes/no
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why do neural networks need activations?" answer="Without nonlinear activations, stacked linear layers collapse into another linear function." %}
  {% include study-card.html question="What does normalization help with?" answer="It stabilizes training by controlling activation or residual-stream scale." %}
  {% include study-card.html question="Why use residual connections?" answer="They improve gradient flow and make deep networks easier to optimize." %}
</div>

## References

- [Deep Learning Book](https://www.deeplearningbook.org/)
- [PyTorch tutorials](https://pytorch.org/tutorials/)
- [Batch Normalization](https://arxiv.org/abs/1502.03167)
