---
title: vLLM Operations
layout: page
permalink: /docs/ml/vllm-operations/
summary: "Operational guide for vLLM serving with scheduler concepts, PagedAttention, KV cache, prefix caching, speculative decoding, parallelism, metrics, flags, and runbooks."
tags:
  - machine-learning
  - inference
  - vllm
  - operations
---

# vLLM Operations

vLLM is a production-oriented LLM serving engine. Operating it well means controlling request shapes, KV-cache pressure, scheduler behavior, model compatibility, runtime flags, metrics, and rollout risk.

## Command Examples

```bash
vllm serve <model> --help | sed -n '1,160p'
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/metrics | grep '^vllm:'
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `vllm serve <model> --help \| sed -n '1,160p'` | `GPU utilization, memory use, CUDA visibility, model list, or serving metrics.` | Separates accelerator visibility from model-serving capacity and latency. |
| `curl -s http://localhost:8000/v1/models` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `curl -s http://localhost:8000/metrics \| grep '^vllm:'` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |

These checks prove the server responds. They do not prove capacity or compatibility.

## Operational Concepts

| Concept | What To Watch |
| --- | --- |
| Scheduler | Waiting/running requests, queue time, priority, fairness. |
| PagedAttention | KV block allocation, fragmentation, cache pressure. |
| Continuous batching | Batch occupancy under mixed prompt/output lengths. |
| Prefix caching | Hit rate, tokenized prefix stability, tenant boundaries. |
| Speculative decoding | Accepted tokens, draft overhead, quality compatibility. |
| Parallelism | Tensor/pipeline split, NCCL, interconnect, latency. |
| Adapters | LoRA compatibility, active adapters, adapter-specific latency. |

## Important Flags

| Flag | Use |
| --- | --- |
| `--max-model-len` | Bound context length and KV-cache demand. |
| `--gpu-memory-utilization` | Reserve GPU memory fraction for execution. |
| `--tensor-parallel-size` | Split tensors across GPUs. |
| `--pipeline-parallel-size` | Split layers across stages. |
| `--enable-prefix-caching` | Reuse stable prompt prefixes. |
| `--generation-config` | Control model repo vs vLLM generation defaults. |
| `--speculative-config` | Enable supported speculative decoding mode. |
| `--kv-cache-dtype` | Use supported KV-cache dtype/quantization. |

## Metrics Checklist

| Metric Family | Incident Meaning |
| --- | --- |
| Queue time | Admission or scheduler pressure. |
| TTFT | Queue plus prefill user wait. |
| ITL | Decode smoothness. |
| KV-cache usage | Memory pressure. |
| Preemptions | Cache or scheduler stress. |
| Running/waiting requests | Load and fairness. |
| Prefix cache hits | Prefix caching value. |
| Token throughput | Prefill and decode capacity. |

## vLLM Runbook

1. Identify model ID, runtime version, flags, adapter, and request shape.
2. Split symptom into wrong output, high TTFT, slow ITL, OOM, or errors.
3. Compare prompt/output token histograms.
4. Inspect queue time, running/waiting requests, KV usage, and preemptions.
5. Check tokenizer, chat template, generation config, and adapter compatibility.
6. Roll back model/runtime/config if release-linked.
7. Add the request shape to load tests and evals.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does vLLM PagedAttention operate on?" answer="The KV cache blocks used by active autoregressive sequences." %}
  {% include study-card.html question="Which vLLM metrics matter during OOM-like incidents?" answer="KV-cache usage, preemptions, running/waiting requests, queue time, and token histograms." %}
  {% include study-card.html question="Why version vLLM flags?" answer="Flags such as max model length, memory utilization, generation config, prefix caching, and speculation change capacity and behavior." %}
</div>

## References

- [vLLM documentation](https://docs.vllm.ai/en/stable/)
- [vLLM Production Metrics](https://docs.vllm.ai/en/stable/usage/metrics/)
- [Inside vLLM: Anatomy of a High-Throughput LLM Inference System](https://vllm.ai/blog/anatomy-of-vllm)
