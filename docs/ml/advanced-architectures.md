---
title: Advanced ML Architectures
layout: page
permalink: /docs/ml/advanced-architectures/
summary: "Advanced model architectures including Mixture of Experts, retrieval-augmented models, state space models, diffusion transformers, sparse attention, long-context architectures, and encoder-only, decoder-only, and encoder-decoder tradeoffs."
tags:
  - machine-learning
  - architectures
  - transformers
  - advanced
---

# Advanced ML Architectures

Architecture choices decide what the model can represent and how expensive it is to train or serve. Advanced architectures usually trade simplicity for scale, context, sparsity, or modality.

## Architecture Map

| Architecture | Strength | Tradeoff |
| --- | --- | --- |
| Encoder-only | Understanding and classification. | Not natural for autoregressive generation. |
| Decoder-only | Text/code generation and chat. | Prompt/context cost grows with sequence. |
| Encoder-decoder | Translation and conditional generation. | More serving complexity. |
| Mixture of Experts | Many parameters with sparse activation. | Routing and load balancing. |
| Retrieval-augmented models | External memory or evidence. | Retriever and generator coupling. |
| State space models | Long sequence efficiency. | Ecosystem and task fit. |
| Diffusion transformers | Generative media. | Sampling cost and safety review. |
| Sparse attention | Longer context at lower cost. | Kernel and quality tradeoffs. |

## Long-Context Design

Long-context architectures change where the bottleneck sits. More context can improve recall but also increases prefill latency, KV-cache memory, lost-in-the-middle behavior, and eval cost.

## MoE Operations

MoE models need:

- expert capacity planning,
- router stability checks,
- load-balance metrics,
- expert-parallel serving support,
- per-slice quality evaluation.

## Practical Lab: Architecture Decision Record

```text
task:
candidate_architectures:
context_needed:
latency_target:
training_data:
serving_hardware:
eval_slices:
rollback_plan:
chosen_architecture:
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is a Mixture-of-Experts model?" answer="A model that routes tokens to a subset of expert layers instead of activating all parameters for every token." %}
  {% include study-card.html question="Why can long context hurt operations?" answer="It increases prefill latency, KV-cache memory, cost, and evaluation complexity." %}
  {% include study-card.html question="When are encoder-only models useful?" answer="For understanding tasks such as classification, ranking, extraction, and embeddings." %}
</div>

## References

- [Switch Transformers](https://arxiv.org/abs/2101.03961)
- [Mamba](https://arxiv.org/abs/2312.00752)
- [DiT: Scalable Diffusion Models with Transformers](https://arxiv.org/abs/2212.09748)
