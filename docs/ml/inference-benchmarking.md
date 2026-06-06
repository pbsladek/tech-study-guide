---
title: Inference Benchmarking
layout: page
permalink: /docs/ml/inference-benchmarking/
summary: "Benchmark methodology for LLM inference with warmup, prompt/output distributions, concurrency sweeps, TTFT, ITL, throughput, quality gates, and benchmark anti-patterns."
tags:
  - machine-learning
  - inference
  - performance
  - benchmarking
---

# Inference Benchmarking

Inference benchmarks should answer a production question: can this model/runtime/hardware combination meet quality, latency, throughput, and cost goals for the real request mix? A benchmark that only reports average tokens/sec on short prompts is usually not enough.

## Command Examples

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/metrics | grep -E 'queue|token|kv|request'
nvidia-smi dmon -s pucm
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `curl -s http://localhost:8000/v1/models` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `curl -s http://localhost:8000/metrics \| grep -E 'queue\|token\|kv\|request'` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `nvidia-smi dmon -s pucm` | `GPU utilization, memory use, CUDA visibility, model list, or serving metrics.` | Separates accelerator visibility from model-serving capacity and latency. |

Record model revision, tokenizer, runtime version, GPU type, driver, CUDA version, precision, quantization, and serving flags with every result.

## Benchmark Design

| Axis | Include |
| --- | --- |
| Prompt length | p50, p90, p95, p99, and max allowed. |
| Output length | p50, p90, p95, p99, and max allowed. |
| Concurrency | steady state, burst, overload, tenant hot spot. |
| Traffic mix | short chat, long RAG, summarization, agents, batch. |
| Generation config | deterministic and product defaults. |
| Runtime variants | baseline, quantized, prefix cache, speculation, new engine. |
| Quality gates | Golden prompts, structured output, safety slices. |

## Metrics

| Metric | Why It Matters |
| --- | --- |
| TTFT p50/p95/p99 | User-visible wait before output starts. |
| ITL p50/p95/p99 | Streaming smoothness during decode. |
| End-to-end latency | Total request duration. |
| Prompt tokens/sec | Prefill throughput. |
| Generation tokens/sec | Decode throughput. |
| Queue time | Admission and capacity pressure. |
| Active/waiting requests | Scheduler health. |
| KV-cache utilization | Memory headroom. |
| Preemptions/swaps/recomputes | Cache pressure symptoms. |
| Error/retry/reject rate | Reliability under load. |
| Cost per 1K tokens | Unit economics. |

## Methodology

1. Warm up model load, CUDA context, kernels, and cache allocator.
2. Run a single-request correctness smoke test.
3. Run fixed-shape tests to isolate prefill and decode.
4. Run production-shape traffic mixes.
5. Sweep concurrency until SLO failure.
6. Repeat with quantization, prefix cache, speculation, and engine changes.
7. Pair every latency result with quality and safety evals.

## Anti-Patterns

| Anti-Pattern | Why It Misleads |
| --- | --- |
| Average-only latency | Hides p95/p99 tail behavior. |
| Short prompts only | Misses prefill and KV-cache pressure. |
| Fixed output length only | Misses decode occupancy variation. |
| No warmup | Measures cold start instead of steady state. |
| No quality gate | Faster output may be worse output. |
| Ignoring rejects | Overload may look fast because bad requests were dropped. |
| Single tenant only | Misses noisy-neighbor and routing behavior. |

## Benchmark Report

| Field | Value |
| --- | --- |
| Model / revision |  |
| Tokenizer / template |  |
| Runtime / version |  |
| Hardware / driver |  |
| Precision / quantization |  |
| Serving flags |  |
| Traffic mix |  |
| SLO target |  |
| Pass/fail decision |  |
| Rollback risk |  |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why are average tokens/sec benchmarks weak?" answer="They can hide tail latency, prompt-shape effects, quality regressions, and overload behavior." %}
  {% include study-card.html question="What should every inference benchmark record?" answer="Model, tokenizer, runtime, hardware, precision, serving flags, traffic mix, latency, throughput, quality, and errors." %}
  {% include study-card.html question="Why benchmark prompt and generation tokens separately?" answer="Prefill and decode stress different parts of the serving system." %}
</div>

## References

- [vLLM Benchmarking](https://docs.vllm.ai/en/stable/contributing/benchmarks.html)
- [vLLM Production Metrics](https://docs.vllm.ai/en/stable/usage/metrics/)
- [TensorRT-LLM Performance](https://nvidia.github.io/TensorRT-LLM/performance.html)
