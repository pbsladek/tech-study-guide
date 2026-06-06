---
title: Inference Runbooks
layout: page
permalink: /docs/ml/inference-runbooks/
summary: "Operational runbooks for LLM inference incidents: wrong output, high TTFT, slow inter-token latency, OOM, low throughput, queue buildup, cache pressure, tokenizer mismatch, and runtime regressions."
tags:
  - machine-learning
  - inference
  - runbooks
  - operations
---

# Inference Runbooks

Inference incidents need fast symptom splitting. Avoid starting with "the GPU is slow." First classify the failure as behavior, queueing, prefill, decode, memory, API, routing, or release regression.

## Command Examples

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/metrics | grep -E 'queue|token|kv|error|request'
nvidia-smi
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `curl -s http://localhost:8000/v1/models` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `curl -s http://localhost:8000/metrics \| grep -E 'queue\|token\|kv\|error\|request'` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `nvidia-smi` | `GPU utilization, memory use, CUDA visibility, model list, or serving metrics.` | Separates accelerator visibility from model-serving capacity and latency. |

Record route, model ID, adapter, tokenizer/template revision, runtime version, generation config, prompt tokens, output tokens, tenant, and release time.

## Symptom Split

| Symptom | First Question |
| --- | --- |
| Wrong output | Does a deterministic single-call repro fail outside the serving engine? |
| High TTFT | Is the delay queueing or prefill? |
| Slow streaming | Is ITL high on server metrics or only at the client? |
| OOM/rejections | Are weights, KV cache, or workspace the pressure source? |
| Low throughput | Is bottleneck compute, memory bandwidth, scheduler, or routing? |
| Queue buildup | Are workers healthy and admitting requests? |
| Cache preemptions | Are prompt/output/concurrency limits too high? |
| Runtime regression | Did model, tokenizer, adapter, quantization, or engine change? |

## Wrong Output

1. Reproduce with deterministic decoding.
2. Compare model revision, tokenizer, chat template, generation config, and adapter.
3. Render prompt text and token IDs.
4. Test same input in a reference runtime.
5. Check retrieval/tool context if present.
6. Roll back changed artifact if release-linked.

## High TTFT

| Evidence | Meaning |
| --- | --- |
| High queue time | Admission, capacity, or worker health issue. |
| Long prompt tokens | Prefill-heavy request shape. |
| Low prefix hit rate | Prefix caching not helping. |
| High waiting requests | Scheduler pressure. |
| Cold model | Load/warmup path. |

Levers: reduce prompt tokens, add replicas, route long prompts, enable prefix caching, use chunked prefill, lower concurrency per replica, or scale hardware.

## Slow Inter-Token Latency

Check output tokens, decode tokens/sec, KV-cache usage, GPU memory bandwidth, batch occupancy, speculative acceptance rate, and client/network buffering. Levers include smaller model, speculation, quantization, decode-focused pool, lower output caps, or more hardware.

## OOM and Cache Pressure

1. Compare weight memory estimate to available GPU memory.
2. Estimate KV cache for p95 prompt plus output at active concurrency.
3. Check `kv_cache_usage`, preemptions, swaps, and rejected requests.
4. Lower `max_model_len`, output cap, or concurrency.
5. Add KV quantization, more memory, or separate long-context pool.

## Low Throughput

| Cause | Check |
| --- | --- |
| Small batches | Batch occupancy and request arrival pattern. |
| Sequence skew | Long outputs holding decode slots. |
| Tensor parallel overhead | Interconnect and NCCL metrics. |
| CPU bottleneck | Tokenization, routing, logging, JSON serialization. |
| Kernel mismatch | Runtime version, quantization, unsupported shape. |

## Release Regression

Use this rollback checklist:

1. Identify changed model/runtime/tokenizer/template/adapter/quantization/flags.
2. Compare golden prompts and structured-output evals.
3. Compare TTFT, ITL, queue, cache, and error metrics.
4. Canary stop if p95 latency, error rate, or quality gates fail.
5. Restore previous artifact bundle and flags.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the first split in an inference incident?" answer="Separate behavior, queueing, prefill, decode, memory, API, routing, and release-regression causes." %}
  {% include study-card.html question="What usually drives high TTFT?" answer="Queue time, long prompt prefill, cold starts, low prefix-cache hits, or insufficient capacity." %}
  {% include study-card.html question="What usually drives slow ITL?" answer="Decode bottlenecks, memory bandwidth, long outputs, poor batch occupancy, or ineffective speculation." %}
</div>

## References

- [vLLM Production Metrics](https://docs.vllm.ai/en/stable/usage/metrics/)
- [Hugging Face Transformers KV cache documentation](https://huggingface.co/docs/transformers/main/kv_cache)
- [NVIDIA TensorRT-LLM documentation](https://nvidia.github.io/TensorRT-LLM/)
