---
title: Machine Learning
layout: page
permalink: /docs/ml/
summary: "Machine learning systems study guide from ML 101 through advanced concepts: math, classical ML, deep learning, transformers, LLM training, fine-tuning, RAG, agents, serving, vLLM, MLOps, security, evaluation, performance, and governance."
tags:
  - machine-learning
  - ai
  - models
  - operations
---

# Machine Learning

Machine learning systems turn data, model architectures, weights, training objectives, hardware, evaluation, and deployment constraints into predictions or generated outputs. The engineering challenge is not only "train a model"; it is choosing the right model type, managing data and weights, measuring behavior, operating accelerators, adapting models safely, and explaining failures.

## Critical Subtopics

| Topic | Why It Matters |
| --- | --- |
| [ML 101 Foundations](ml-101-foundations/) | Covers what ML is, when not to use it, datasets, features, labels, splits, training, inference, metrics, overfitting, and bias/variance. |
| [Math for ML](math-for-ml/) | Covers vectors, matrices, tensors, dot products, cosine similarity, gradients, probability, softmax, cross entropy, KL divergence, and attention intuition. |
| [Classical ML](classical-ml/) | Covers linear/logistic regression, trees, random forests, gradient boosting, SVMs, k-means, feature engineering, and tabular workflows. |
| [Deep Learning Fundamentals](deep-learning-fundamentals/) | Covers neural networks, activations, embeddings, CNNs, RNNs, transformers, optimizers, normalization, regularization, and training stability. |
| [Models, Types, and Weights](models-weights/) | Covers supervised, unsupervised, self-supervised, generative, discriminative, transformer, embedding, and diffusion model shapes plus what weights represent. |
| [Transformer Internals](transformers-internals/) | Covers tokenization, embeddings, positional encodings, RoPE, self-attention, MLP blocks, normalization, decoder-only models, KV cache, context windows, and MoE basics. |
| [LLM Training Lifecycle](llm-training-lifecycle/) | Covers pretraining, continued pretraining, SFT, RLHF, DPO, RLAIF, preference data, synthetic data, filtering, and stage-specific evaluation. |
| [Accelerators: GPU and TPU](accelerators-gpu-tpu/) | Covers GPU and TPU execution models, memory, batching, precision, utilization, and accelerator troubleshooting. |
| [PyTorch Fundamentals](pytorch-fundamentals/) | Covers tensors, modules, autograd, losses, optimizers, dataloaders, training loops, mixed precision, and checkpointing. |
| [Fine-Tuning and LoRA](finetuning-lora/) | Covers full fine-tuning, parameter-efficient tuning, LoRA adapters, data preparation, evaluation, and rollback. |
| [Advanced Fine-Tuning](advanced-finetuning/) | Covers QLoRA, adapter composition, multi-adapter serving, dataset mixing, packing, long-context tuning, forgetting, and safety-preserving releases. |
| [Retrieval-Augmented Generation](rag/) | Covers embeddings, chunking, vector indexes, retrieval, reranking, context assembly, citations, and freshness boundaries. |
| [Advanced RAG](advanced-rag/) | Covers hybrid retrieval, query planning, multi-hop retrieval, rerankers, GraphRAG, context compression, citation verification, agentic RAG, retrieval evals, and secure RAG. |
| [Agents and Tool Use](agents/) | Covers planning loops, tool calling, memory, state, guardrails, idempotency, and agent evaluation. |
| [Advanced Agents](advanced-agents/) | Covers ReAct, planning, reflection, tool routing, multi-agent systems, durable execution, memory, sandboxing, approvals, trajectory evaluation, and failure recovery. |
| [Multimodal ML](multimodal-ml/) | Covers vision, audio, speech-to-text, text-to-speech, vision-language models, image embeddings, OCR pipelines, multimodal RAG, and video basics. |
| [Serving, Inference, and vLLM](serving-inference-vllm/) | Covers model serving, prefill/decode, batching, streaming, KV cache, vLLM, PagedAttention, prefix caching, speculative decoding, canaries, and inference optimization. |
| [Advanced Inference and vLLM](advanced-inference-vllm/) | Covers PagedAttention, continuous batching, disaggregated prefill, chunked prefill, speculative decoding, prefix caching, KV-cache math, parallelism, quantized serving, LoRA serving, and autoscaling. |
| [Observability and Incident Response](observability-incident-response/) | Covers serving metrics, traces, prompt and retrieval logging, drift, quality monitoring, feedback loops, and ML incident runbooks. |
| [Advanced ML Observability](advanced-observability/) | Covers drift detection, data quality monitoring, online evals, feedback loops, trace schemas, prompt/retrieval/model/tool observability, safety monitoring, cost monitoring, and incident templates. |
| [Data Pipelines and Feature Stores](data-pipelines-feature-stores/) | Covers dataset versioning, lineage, data contracts, feature stores, point-in-time correctness, train/serve skew, and privacy gates. |
| [MLOps Systems](mlops-systems/) | Covers model registries, feature stores, training pipelines, artifact versioning, reproducibility, batch/online inference, canaries, shadow evaluation, rollback, and cost governance. |
| [Evaluation and CI/CD](evaluation-ci-cd/) | Covers eval harnesses, golden sets, regression gates, human review, release scorecards, canaries, and behavioral CI/CD. |
| [Evaluation Mastery](evaluation-mastery/) | Covers unit evals, golden sets, model-graded evals, human evals, preference evals, safety evals, regression gates, slice metrics, statistical confidence, and contamination controls. |
| [Security and Privacy](security-privacy/) | Covers prompt injection, data exfiltration, model supply chain, poisoned retrieval, tenant isolation, PII, retention, and audit logging. |
| [ML Security Threats](ml-security-threats/) | Covers prompt injection, jailbreaks, data poisoning, model extraction, membership inference, training data leakage, secrets in prompts, supply chain risk, tenant isolation, and secure RAG. |
| [Prompt Operations](prompt-operations/) | Covers prompt templates, versioning, structured outputs, prompt injection resistance, evals, generation config, and rollback. |
| [Advanced ML Architectures](advanced-architectures/) | Covers Mixture of Experts, retrieval-augmented models, state space models, diffusion transformers, sparse attention, long-context architectures, and encoder/decoder tradeoffs. |
| [ML Performance Engineering](performance-engineering/) | Covers training-loop profiling, GPU utilization, memory bandwidth, activation checkpointing, FlashAttention, fused kernels, distributed bottlenecks, inference throughput tuning, and cost/performance tradeoffs. |
| [Alignment and Evaluation](alignment-evaluation/) | Covers preference tuning, RLHF/DPO concepts, safety policy, eval sets, red teaming, and regression gates. |
| [Explainability](explainability/) | Covers feature attribution, saliency, counterfactuals, interpretable models, LIME/SHAP, attention caveats, and model cards. |
| [Responsible AI and Governance](responsible-ai-governance/) | Covers model cards, dataset cards, risk classification, human oversight, audit trails, fairness checks, red-team programs, release approval, incidents, and regulatory documentation. |

## Core Mental Model

An ML system has several separable layers:

| Layer | Key Question |
| --- | --- |
| Data | What examples, labels, documents, features, and feedback does the system learn from or retrieve? |
| Model | What architecture maps inputs to outputs? |
| Weights | What learned parameters encode behavior after training or adaptation? |
| Objective | What loss, reward, or preference signal is optimized? |
| Hardware | What accelerator, memory, precision, and parallelism constraints shape runtime? |
| Evaluation | What tests prove the system works and stays inside boundaries? |
| Product loop | How are user feedback, drift, monitoring, and rollback handled? |

Separate these layers during design reviews and incidents. A bad answer might be a retrieval failure, model limitation, prompt issue, data drift, unsafe tool action, bad fine-tune, accelerator pressure, or evaluation gap.

## ML 100 Gap Closure Matrix

The ML section tracks 100 concrete gaps that should be understood before operating ML systems in production. The identifiers below are implemented in the topic pages so the overview stays navigational while the details live with the relevant material.

| Range | Topic Page | Gap Area |
| --- | --- | --- |
| ML-GAP-001 through ML-GAP-012 | Models, Types, and Weights | Data splits, label quality, leakage, objectives, optimizers, decoding, tokenization, embeddings, calibration, distillation, quantization, and model cards. |
| ML-GAP-013 through ML-GAP-023 | Accelerators: GPU and TPU | Memory math, tensor cores, mixed precision, checkpointing, transfer bottlenecks, batches, distributed topology, collectives, fragmentation, profiling, and serving utilization. |
| ML-GAP-024 through ML-GAP-035 | PyTorch Fundamentals | Datasets, reproducibility, autograd lifetime, accumulation, clipping, optimizer state, schedules, AMP, DDP, resume state, compile/export, and evaluation-mode hazards. |
| ML-GAP-036 through ML-GAP-047 | Fine-Tuning and LoRA | SFT formats, chat templates, LoRA modules, rank, QLoRA, packing, forgetting, overfit, merge risk, eval contamination, safety regression, and rollback compatibility. |
| ML-GAP-048 through ML-GAP-060 | Retrieval-Augmented Generation | Ingestion, chunk boundaries, metadata, hybrid search, query rewriting, rerankers, ACLs, freshness, citations, context budget, hallucination triage, observability, and cost/latency. |
| ML-GAP-061 through ML-GAP-072 | Agents and Tool Use | Tool contracts, authorization, idempotency, state machines, approvals, sandboxes, retries, timeouts, parallel calls, memory poisoning, trajectory evals, and replay. |
| ML-GAP-073 through ML-GAP-086 | Alignment and Evaluation | Eval governance, golden sets, metric slices, release gates, preference labels, RLHF/DPO boundaries, red-team taxonomies, severity rubrics, abstention, fairness, monitoring, drift, canaries, and incidents. |
| ML-GAP-087 through ML-GAP-100 | Explainability | Method selection, SHAP baselines, LIME perturbations, counterfactuals, saliency, attention caveats, embedding neighborhoods, probes, attribution stability, debugging, user risks, documentation, explanation drift, and evidence. |

## First Checks

```bash
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
nvidia-smi
python -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'cpu')"
```

These checks prove local PyTorch import, CUDA visibility, and GPU identity. They do not prove model correctness.

## Study Path

| Stage | Pages |
| --- | --- |
| 101 | ML 101 Foundations, Math for ML, Classical ML. |
| Core | Deep Learning Fundamentals, Models/Weights, PyTorch, Transformer Internals, Accelerators. |
| LLM | LLM Training Lifecycle, Fine-Tuning and LoRA, Advanced Fine-Tuning, RAG, Advanced RAG, Agents, Advanced Agents, Multimodal ML. |
| Production | Serving and vLLM, Advanced Inference and vLLM, Observability, Advanced Observability, Data Pipelines and Feature Stores, MLOps Systems, Prompt Operations. |
| Advanced | Evaluation Mastery, ML Security Threats, Advanced Architectures, Performance Engineering, Alignment, Explainability, Responsible AI and Governance. |

Learn the stages in order, but use production gates early. Data leakage, weak evals, unsafe prompts, or unbounded serving cost can invalidate a model regardless of how advanced the architecture is.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What are model weights?" answer="Learned numeric parameters that encode how a model maps inputs to outputs after training or adaptation." %}
  {% include study-card.html question="Why separate data, model, weights, objective, hardware, and evaluation?" answer="Each layer can cause different failures and needs different debugging evidence." %}
  {% include study-card.html question="When is RAG preferable to fine-tuning?" answer="When answers need fresh, inspectable, source-grounded knowledge rather than changed model behavior." %}
  {% include study-card.html question="Why are agents harder to evaluate than single model calls?" answer="They include state, tool effects, multi-step decisions, and failure recovery paths." %}
  {% include study-card.html question="Why separate prefill and decode in LLM inference?" answer="Prefill and decode have different latency, memory, batching, and KV-cache behavior." %}
  {% include study-card.html question="Why treat prompts as production code?" answer="Prompts control task behavior, safety boundaries, tool use, output format, and retrieval usage." %}
</div>

{% include study-card-deck.html deck="ml" %}

## References

- [PyTorch documentation](https://pytorch.org/docs/stable/index.html)
- [Google Cloud TPU documentation](https://cloud.google.com/tpu/docs)
- [vLLM documentation](https://docs.vllm.ai/en/stable/)
- [The Illustrated Transformer](https://jalammar.github.io/illustrated-transformer/)
- [Model Cards for Model Reporting](https://arxiv.org/abs/1810.03993)
