---
title: Advanced Inference and vLLM
layout: page
permalink: /docs/ml/advanced-inference-vllm/
summary: "Advanced LLM inference with vLLM, PagedAttention, continuous batching, disaggregated prefill, chunked prefill, speculative decoding, prefix caching, KV-cache math, tensor and pipeline parallelism, quantized serving, LoRA serving, and autoscaling."
tags:
  - machine-learning
  - inference
  - vllm
  - advanced
---

# Advanced Inference and vLLM

Advanced inference engineering is about managing tokens, memory, scheduling, and tail latency. vLLM provides a production-oriented serving engine, but operators still need to size KV cache, control prompt/output shapes, choose parallelism, and measure real traffic.

## First Checks

```bash
vllm serve <model> --help | sed -n '1,80p'
curl -s http://localhost:8000/metrics | grep '^vllm:'
```

## vLLM Architecture Concepts

| Concept | Operational Meaning |
| --- | --- |
| PagedAttention | KV-cache memory management that avoids large contiguous allocations. |
| Continuous batching | Adds and removes requests dynamically as sequences progress. |
| Chunked prefill | Splits large prompt prefill into smaller schedulable chunks. |
| Disaggregated prefill | Runs prefill and decode in separate instances and transfers KV cache; experimental in current vLLM docs. |
| Prefix caching | Reuses KV cache for repeated prompt prefixes. |
| Speculative decoding | Uses draft or prompt/suffix methods to reduce inter-token latency when candidate tokens are accepted. |
| Quantized KV cache | Reduces KV memory in supported configurations with quality checks. |

## KV-Cache Memory Math

Approximate KV memory grows with:

```text
layers * 2(K,V) * batch_sequences * context_tokens * hidden_per_layer * bytes_per_value
```

This is why long context and high concurrency are memory problems even when model weights fit.

## Parallelism Choices

| Strategy | Helps | Cost |
| --- | --- | --- |
| Tensor parallelism | Split large matrix work across GPUs. | Collective communication and interconnect dependence. |
| Pipeline parallelism | Split layers across stages. | Bubbles and latency for small batches. |
| Data parallel serving | More replicas for more traffic. | More model copies and routing complexity. |
| Disaggregated prefill/decode | Tune TTFT and ITL separately. | KV transfer, experimental behavior, more moving parts. |

## Advanced vLLM Lab: Capacity Worksheet

```text
model:
  parameters:
  dtype:
  max_model_len:
traffic:
  p50_prompt_tokens:
  p95_prompt_tokens:
  p50_output_tokens:
  p95_output_tokens:
targets:
  ttft_p95:
  itl_p95:
  cost_per_1k_tokens:
tuning:
  tensor_parallel_size:
  gpu_memory_utilization:
  enable_prefix_caching:
  speculative_config:
```

## Tuning Decision Tree

| Goal | First Lever | Second Lever |
| --- | --- | --- |
| Lower TTFT | Reduce prompt tokens or add prefix caching. | More replicas or disaggregated prefill. |
| Lower ITL | Speculative decoding or smaller model. | Decode-focused routing and hardware sizing. |
| Fit longer context | More memory or lower concurrency. | Quantized KV cache after quality testing. |
| Improve throughput | Continuous batching and admission control. | Tensor parallelism or more replicas. |
| Support many adapters | Adapter routing and compatibility checks. | Separate pools for heavy adapters. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is disaggregated prefill useful?" answer="It lets operators tune time to first token and inter-token latency separately by separating prefill and decode work." %}
  {% include study-card.html question="What does KV-cache memory scale with?" answer="Layers, active sequences, context tokens, hidden dimensions, and bytes per cached value." %}
  {% include study-card.html question="When is speculative decoding most useful?" answer="When workloads are decode-latency sensitive and candidate tokens are accepted often enough to offset overhead." %}
</div>

## References

- [vLLM documentation](https://docs.vllm.ai/en/stable/)
- [vLLM Disaggregated Prefilling](https://docs.vllm.ai/en/latest/usage/disagg_prefill.html)
- [vLLM Speculative Decoding](https://docs.vllm.ai/en/stable/features/speculative_decoding/)
- [vLLM Automatic Prefix Caching](https://docs.vllm.ai/en/stable/features/automatic_prefix_caching/)
- [PagedAttention paper](https://arxiv.org/abs/2309.06180)
