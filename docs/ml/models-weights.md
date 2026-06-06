---
title: ML Models, Types, and Weights
layout: page
permalink: /docs/ml/models-weights/
summary: "Model families, model types, parameters, weights, checkpoints, tokenizers, embeddings, transformers, diffusion models, and inference boundaries."
tags:
  - machine-learning
  - models
  - weights
  - transformers
---

# ML Models, Types, and Weights

A model is a parameterized function. Training adjusts its weights so the function maps inputs to useful outputs. The architecture defines the shape of computation; the weights are learned numbers inside that shape.

## Command Examples

```bash
python - <<'PY'
import torch
print(torch.__version__)
print(torch.randn(2, 3).shape)
PY
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Python snippet` | `2.6.0` and `torch.Size([2, 3])`. | Proves the tensor library imports and can create tensors with the expected shape. |

This only proves the tensor library works. Model behavior depends on the architecture, weights, tokenizer or preprocessing, and inference settings.

## Model Types

| Type | Learns From | Common Outputs |
| --- | --- | --- |
| Supervised | Labeled examples. | Class labels, probabilities, regression values. |
| Unsupervised | Unlabeled data structure. | Clusters, compressed representations, anomaly scores. |
| Self-supervised | Labels derived from the data itself. | Representations, next-token predictions, masked-token predictions. |
| Reinforcement learning | Rewards from actions in an environment. | Policies or value estimates. |
| Generative | Data distribution or conditional generation objective. | Text, images, audio, code, synthetic samples. |
| Discriminative | Boundary between classes or scores. | Classification or ranking decisions. |

Large language models are usually self-supervised transformer models further adapted with instruction tuning, preference tuning, tool-use data, or domain-specific fine-tuning.

## Common Families

| Family | Shape | Typical Use |
| --- | --- | --- |
| Linear/logistic models | Weighted features. | Baselines, interpretable tabular problems. |
| Tree ensembles | Decision trees combined by bagging or boosting. | Tabular prediction, feature importance. |
| CNNs | Convolutions over local structure. | Images, signals, some sequence tasks. |
| RNNs/LSTMs/GRUs | Recurrent state over sequences. | Legacy sequence modeling and time series. |
| Transformers | Attention over token sequences. | Language, code, multimodal, embeddings. |
| Diffusion models | Iterative denoising process. | Image, audio, video, generative media. |
| Embedding models | Map inputs to vectors. | Search, clustering, similarity, RAG retrieval. |

## Weights, Checkpoints, and Tokenizers

Weights are numeric tensors. A checkpoint stores weights plus metadata needed to load them. For language models, the tokenizer is part of the model interface: changing it can change the token sequence and therefore the model behavior.

Important artifacts:

| Artifact | Why It Matters |
| --- | --- |
| Architecture config | Defines tensor shapes and layer graph. |
| Weights | Learned parameters. |
| Tokenizer / preprocessor | Converts raw input into model input IDs or tensors. |
| Checkpoint | Saved model state for training or inference. |
| Optimizer state | Needed to resume training faithfully. |
| Generation config | Sampling, temperature, top-p, max tokens, and stopping behavior. |

Do not treat a checkpoint file as a complete system. Production behavior also depends on prompts, retrieval, adapters, runtime precision, decoding settings, and safety layers.

## Data, Objective, and Inference Gaps

Model quality is usually limited by hidden data, objective, and serving assumptions before it is limited by architecture alone.

| Gap | What To Fill | Operational Check |
| --- | --- | --- |
| ML-GAP-001 Data Splits and Leakage | Split train, validation, and test data by user, time, source, or entity so near-duplicates and future information do not leak across boundaries. | Run duplicate and temporal-leak checks before trusting eval scores. |
| ML-GAP-002 Label Quality | Track label source, adjudication rules, disagreement, and stale labels; noisy labels become learned behavior. | Review low-confidence labels and measure inter-annotator agreement where humans label data. |
| ML-GAP-003 Feature Leakage | Remove features that encode the answer through timestamps, IDs, post-event fields, or downstream workflow artifacts. | Compare top features against what would be known at prediction time. |
| ML-GAP-004 Loss Functions | Match the loss to the real objective: regression, classification, ranking, sequence likelihood, contrastive learning, or preference optimization. | Explain what the loss rewards and what user-visible behavior it ignores. |
| ML-GAP-005 Optimizers | Choose optimizer, learning rate, weight decay, and schedule deliberately; defaults can hide instability or slow convergence. | Track train loss, validation loss, gradient norms, and update magnitude. |
| ML-GAP-006 Decoding Strategies | Document greedy, beam, temperature, top-p, top-k, max-token, and stop-sequence settings because they change outputs without changing weights. | Version generation config with prompts and model artifacts. |
| ML-GAP-007 Tokenization Failure Modes | Account for unknown tokens, Unicode normalization, whitespace sensitivity, special tokens, truncation, and tokenizer/model mismatch. | Test representative edge text through the exact production tokenizer. |
| ML-GAP-008 Embedding Spaces | Keep embedding model, distance metric, normalization, dimensionality, and index build together as one compatibility boundary. | Rebuild or migrate indexes when embedding model or vector normalization changes. |
| ML-GAP-009 Calibration | Check whether probabilities, confidence scores, or logits match observed correctness rates. | Plot reliability by score bucket and calibrate or abstain where needed. |
| ML-GAP-010 Distillation | Treat student models as new models with their own evals, not compressed copies that inherit teacher behavior perfectly. | Compare teacher and student by slice, not only aggregate accuracy. |
| ML-GAP-011 Quantization | Measure quality, latency, and memory after INT8, INT4, or weight-only quantization; small numeric changes can alter generation. | Run task, safety, and calibration evals on the quantized artifact. |
| ML-GAP-012 Model Cards | Document intended use, training data, metrics, limitations, risks, and operational constraints. | Require a model card update before promoting a new checkpoint or adapter. |

## Inference Boundaries

Inference is constrained by:

- context length or input tensor shape,
- memory for weights and activations,
- batch size and latency target,
- precision such as FP32, FP16, BF16, INT8, or INT4,
- decoding strategy,
- tokenizer/preprocessing compatibility,
- safety and post-processing.

## Failure Modes

| Symptom | Likely Cause |
| --- | --- |
| Nonsense output | Wrong tokenizer, wrong checkpoint, bad prompt, incompatible adapter, or out-of-distribution input. |
| Good eval, bad production | Data leakage, weak eval set, distribution shift, missing product constraints. |
| High latency | Model too large, batch shape inefficient, accelerator underused, CPU preprocessing bottleneck. |
| Regressions after update | Changed weights, prompt, tokenizer, decoding, retrieval, or guardrail behavior. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the difference between architecture and weights?" answer="Architecture defines the computation graph; weights are learned tensors inside that graph." %}
  {% include study-card.html question="Why is the tokenizer part of a language model boundary?" answer="It determines how raw text becomes token IDs, so changing it changes model inputs." %}
  {% include study-card.html question="What does an embedding model produce?" answer="Vectors that represent semantic or feature similarity for search, clustering, or retrieval." %}
  {% include study-card.html question="Why can the same weights behave differently in production?" answer="Prompts, decoding settings, adapters, retrieval, precision, and safety layers can all change outputs." %}
</div>

## References

- [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- [PyTorch model saving and loading](https://pytorch.org/tutorials/beginner/saving_loading_models.html)
- [Hugging Face tokenizer summary](https://huggingface.co/docs/transformers/tokenizer_summary)
- [DDPM diffusion models](https://arxiv.org/abs/2006.11239)
