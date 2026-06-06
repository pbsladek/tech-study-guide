---
title: LLM Inference Systems
layout: page
permalink: /docs/ml/inference-systems/
summary: "Production LLM inference systems: model files, weights, memory, inference engines, vLLM, TensorRT-LLM, TGI, llama.cpp, SGLang, Ollama, KV cache, PagedAttention, batching, quantization, routing, performance tests, and runbooks."
tags:
  - machine-learning
  - inference
  - llm
  - serving
  - vllm
---

# LLM Inference Systems

LLM inference is the production system that turns model artifacts, tokenizers, chat templates, prompts, adapters, hardware, runtime kernels, schedulers, KV cache, and API contracts into generated tokens. Treat inference as a systems problem: the same weights can behave differently or cost much more when the tokenizer, generation config, serving engine, cache policy, precision, batching, or request shape changes.

## Command Examples

```bash
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"
python -c "from transformers import AutoTokenizer; print('tokenizer import ok')"
vllm serve <model> --help | sed -n '1,120p'
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/metrics | grep -E 'vllm:|kv|queue|token'
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `nvidia-smi` | `GPU utilization, memory use, CUDA visibility, model list, or serving metrics.` | Separates accelerator visibility from model-serving capacity and latency. |
| `Python snippet` | `A version, tensor shape, score, retrieved IDs, metric delta, or explicit error.` | Turns the example into a measurable model, data, or pipeline signal. |
| `Python snippet` | `A version, tensor shape, score, retrieved IDs, metric delta, or explicit error.` | Turns the example into a measurable model, data, or pipeline signal. |

These checks prove only basic runtime reachability. They do not prove model compatibility, output quality, cache capacity, tenant isolation, or cost.

## System Layers

| Layer | What to Verify | Common Failure |
| --- | --- | --- |
| Model artifact | File format, architecture, dtype, shards, license. | Runtime cannot load or silently falls back to slow behavior. |
| Tokenizer | Vocabulary, special tokens, BOS/EOS behavior, chat template. | Same prompt produces different token IDs across engines. |
| Weights | Parameter count, precision, quantization, sharding, adapters. | Model fits at rest but fails under KV-cache load. |
| Runtime engine | Scheduler, kernels, KV layout, batching, API server. | Good single-call output but poor production tail latency. |
| Request policy | Max prompt, max output, sampling defaults, tenant quota. | Unbounded requests exhaust cache or create cost spikes. |
| Observability | TTFT, ITL, queue time, tokens/sec, cache pressure, errors. | Incidents are diagnosed from generic GPU utilization only. |
| Release gate | Quality evals, load tests, canary, rollback, compatibility checks. | Runtime or model upgrades change behavior without detection. |

## Model Artifacts and Formats

| Format | Where It Shows Up | What to Know |
| --- | --- | --- |
| PyTorch checkpoint | Training, fine-tuning, research code. | Flexible, but often not the most efficient production serving artifact. |
| `safetensors` | Hugging Face model repos and serving stacks. | Safer tensor-only format with fast loading and no pickle execution. |
| Sharded weights | Large models split across multiple files. | Need all shards, matching index, enough host RAM, and compatible dtype. |
| GGUF | llama.cpp, local/offline inference, quantized edge use. | Bundles metadata and quantized weights for llama.cpp-family runtimes. |
| ONNX | Cross-runtime export and optimization. | Useful for some models, but decoder-only LLM serving often needs engine-specific support. |
| TensorRT engine | TensorRT-LLM deployment artifact. | Built for specific model, precision, shape assumptions, and hardware target. |
| LoRA adapter | Parameter-efficient serving over a base model. | Must match base model, tokenizer, target modules, rank, dtype, and merge state. |

Artifact reviews should record model ID, revision, license, architecture, context window, tokenizer revision, chat template, dtype, quantization scheme, adapter list, generation config, eval baseline, and rollback artifact.

## Weights, Activations, and KV Cache

| Memory Class | Lifetime | Scales With | Why It Matters |
| --- | --- | --- | --- |
| Weights | Loaded while model replica is running. | Parameter count and bytes per parameter. | Determines base GPU memory before traffic. |
| Activations | Temporary during forward passes. | Batch shape, sequence length, layers, kernels. | Training is activation-heavy; inference still has temporary workspace. |
| KV cache | Grows per active sequence during prefill/decode. | Layers, tokens, KV heads, head dim, dtype, concurrency. | Often the production serving bottleneck. |
| Optimizer state | Training only. | Parameters and optimizer type. | Usually absent from inference replicas. |
| Workspace | Runtime-specific temporary buffers. | Kernel choices, parallelism, compilation. | Can cause OOM even when rough math looks safe. |

Rough weight memory:

```text
weight_memory ~= parameters * bytes_per_parameter
```

Common bytes per parameter:

| Precision | Bytes | Typical Use |
| --- | --- | --- |
| FP32 | 4 | Training or high-precision baselines. |
| BF16 / FP16 | 2 | Common GPU inference and training precision. |
| FP8 | 1 | Newer accelerator paths with calibration and kernel support. |
| INT8 | 1 | Quantized serving where quality holds. |
| INT4 | 0.5 | Aggressive weight quantization for memory/cost reduction. |

Rough KV-cache memory per active sequence:

```text
layers * active_tokens * 2(K,V) * kv_heads * head_dim * bytes_per_value
```

Grouped-query attention and multi-query attention reduce KV memory by using fewer KV heads than query heads. This is one reason two models with similar parameter counts can have different serving capacity.

## Engine Choice Matrix

| Engine | Strengths | Watch Out For | Good Fit |
| --- | --- | --- | --- |
| vLLM | PagedAttention, continuous batching, OpenAI-compatible API, prefix caching, speculative decoding, metrics. | Feature compatibility, cache pressure, version-specific flags, operational tuning. | General high-throughput LLM serving. |
| TensorRT-LLM | NVIDIA-optimized kernels, engine build workflow, in-flight batching, paged KV cache support. | Build complexity, hardware specificity, engine rebuilds for shape/model changes. | NVIDIA fleets needing maximum optimized throughput. |
| Hugging Face TGI | Hugging Face ecosystem integration, production server, common open-model workflow. | Engine-specific model support and tuning differences. | Teams standardized on HF model repos and APIs. |
| llama.cpp | GGUF ecosystem, CPU/GPU/offload, local and edge inference. | Different performance profile, model conversion/quant choices, not a drop-in GPU fleet server. | Local apps, edge, laptops, CPU-heavy deployments. |
| SGLang | Serving runtime with structured generation and high-performance LLM execution features. | Operational maturity and feature fit should be validated for your workload. | Structured generation, agentic, or programmatic generation workloads. |
| Ollama | Simple local model management and developer UX. | Convenience layer, not usually the final high-scale serving control plane. | Local development, demos, lightweight internal tools. |

Engine selection should be workload-driven. Compare prompt length distribution, output length distribution, concurrency, latency targets, hardware, model format, quantization needs, adapter support, API compatibility, observability, and upgrade process.

## Inference Mechanics

| Mechanic | Practical Meaning | Primary Metric |
| --- | --- | --- |
| Prefill | Processes prompt tokens and creates initial KV cache. | Time to first token and prompt tokens/sec. |
| Decode | Generates tokens one step at a time using KV cache. | Inter-token latency and generation tokens/sec. |
| Streaming | Sends partial output while decode continues. | Smoothness, cancellation, client disconnects. |
| Static batching | Runs preselected batches together. | Batch throughput, but can add waiting. |
| Dynamic batching | Batches requests arriving near each other. | Throughput vs latency tradeoff. |
| Continuous batching | Adds/removes active sequences while decoding. | GPU occupancy and tail latency under mixed lengths. |
| Admission control | Limits traffic before the runtime collapses. | Queue time, rejection rate, cache pressure. |
| Request-shape routing | Splits short, long-context, and long-output traffic. | Per-pool SLOs and utilization. |

Prefill and decode should be measured separately. Long prompts hurt TTFT and KV memory early. Long outputs extend decode, grow KV cache, and keep slots occupied. A system can have good average tokens/sec while users experience bad p95 TTFT or uneven streaming.

## Sampling and Decoding Controls

| Control | Effect | Risk |
| --- | --- | --- |
| Greedy decoding | Always picks the highest-probability token. | Deterministic but can be dull or brittle. |
| Temperature | Changes randomness of token selection. | High values can reduce reliability. |
| Top-p | Samples from a probability mass cutoff. | Poor defaults can affect safety and format. |
| Top-k | Samples from a fixed number of candidates. | Too small can overconstrain output. |
| Repetition penalty | Discourages repeated tokens. | Can damage exact quoting or structured output. |
| Beam search | Explores multiple candidate sequences. | Expensive and often not ideal for chat serving. |
| Max tokens | Caps output length. | Too high raises cost/cache use; too low truncates. |
| Stop sequences | Ends generation at known boundaries. | Bad stops can cut valid answers. |

Version generation settings with deployments. A model-repo default, runtime default, SDK default, and product default can differ.

## API Contracts, Streaming, and Cancellation

| Surface | What to Lock Down | Failure Mode |
| --- | --- | --- |
| OpenAI-compatible endpoints | Request schema, response schema, model IDs, tool/function fields, streaming chunks. | Client works in one engine but breaks after runtime swap. |
| Streaming semantics | Token/chunk ordering, finish reasons, errors, timeouts. | Clients hang, double-render, or lose final usage data. |
| Cancellation | Client disconnects, timeout cancellation, server-side abort. | Abandoned requests keep decoding and holding KV cache. |
| Usage accounting | Prompt tokens, completion tokens, cached tokens, rejected requests. | Cost attribution and rate limits drift from reality. |
| Error taxonomy | Rate limit, context length, safety, overload, model unavailable. | Retry logic overloads a degraded system. |
| Backward compatibility | Old SDKs, old model aliases, old tool schemas. | Runtime upgrade becomes a client incident. |

Treat API compatibility as part of the model contract. A serving engine migration should replay real client requests, including streaming, tool calls, long prompts, stop sequences, cancellation, and overload behavior.

## KV Cache Essentials

KV cache stores attention key/value tensors for previous tokens so autoregressive decode does not recompute the whole prompt for every new token. It is internal model state for active inference, not final-answer caching and not durable conversation memory.

| Topic | Important Detail |
| --- | --- |
| Lifecycle | Allocate during prefill, append during decode, free on finish/cancel. |
| Memory pressure | Increases with prompt tokens, generated tokens, concurrency, layers, heads, and dtype. |
| Decode performance | Often memory-bandwidth-sensitive because each new token reads prior KV. |
| Prefix reuse | Shared prefixes can reuse cached KV only when model, tokenizer, template, and prefix tokens match. |
| Quantized KV | Can reduce memory/bandwidth but must pass quality and kernel support checks. |
| Offloaded KV | Moves some cache to CPU memory but adds PCIe/NVLink latency and bandwidth limits. |
| Sliding window | Some architectures keep only a recent attention window. |
| Tenant isolation | Cache reuse must not cross tenant or authorization boundaries. |

Capacity planning should include a table of request classes:

| Class | Prompt Tokens | Output Tokens | Concurrency | Serving Pool |
| --- | --- | --- | --- | --- |
| Chat short | p50/p95 | p50/p95 | target | Low-latency pool. |
| RAG long prompt | p50/p95 | p50/p95 | target | Prefix-cache or long-context pool. |
| Batch summarization | p50/p95 | p50/p95 | target | Throughput-oriented pool. |
| Agent/tool loop | p50/p95 per turn | p50/p95 per turn | target | Strict timeout and cost limits. |

## PagedAttention Essentials

PagedAttention is a KV-cache memory-management technique used by vLLM. It splits KV cache into fixed-size physical blocks and maps logical token positions to those blocks. This avoids requiring one large contiguous allocation per sequence.

| Concept | What It Means |
| --- | --- |
| Logical block | A token range in a sequence's cache. |
| Physical block | A GPU memory block holding actual KV tensors. |
| Block table | Mapping from logical blocks to physical blocks. |
| Non-contiguous storage | One request can span scattered physical blocks. |
| Block sharing | Shared prefixes or parallel samples can reuse blocks. |
| Copy-on-write | Shared blocks are copied only when sequences diverge. |
| Fragmentation control | Less memory is wasted by worst-case contiguous reservation. |

PagedAttention improves packing, concurrency, continuous batching, and cache reuse. It does not make attention compute free, change model quality, or remove the need for prompt/output limits.

## Prefix Caching, Speculation, and Prefill/Decode Split

| Technique | Helps | Best Signal |
| --- | --- | --- |
| Prefix caching | Reuses KV for stable repeated prefixes. | Prefix cache hit rate and lower TTFT. |
| Chunked prefill | Slices long prefill into schedulable chunks. | Fairness and p95 TTFT under mixed traffic. |
| Disaggregated prefill/decode | Separates prefill-heavy and decode-heavy workers. | Independent TTFT and ITL capacity control. |
| Speculative decoding | Drafts candidate tokens and verifies them. | Accepted-token rate and lower ITL. |
| Multi-LoRA serving | Serves adapters over one base model. | Adapter-specific latency, cache pressure, quality. |
| Quantized serving | Reduces memory and sometimes improves throughput. | Quality evals, latency, supported kernels. |

Prefix caching is not the same as response caching. It reuses internal KV for identical token prefixes. Any change in system prompt, chat template, retrieved document order, tokenizer, adapter, or tenant boundary can make reuse unsafe or impossible.

## Quantization for Serving

| Type | What Is Quantized | Main Benefit | Main Risk |
| --- | --- | --- | --- |
| Weight quantization | Model parameters. | Lower model memory and cost. | Quality loss, unsupported kernels, calibration gaps. |
| Activation quantization | Runtime activations. | Faster/lower-memory kernels where supported. | Accuracy and hardware dependence. |
| KV-cache quantization | Cached keys and values. | More context/concurrency. | Quality loss and decode kernel compatibility. |
| GGUF quant levels | llama.cpp model weights. | Local/edge memory reduction. | Quant choice materially affects output and speed. |
| FP8 serving | Weights/activations on supported hardware. | High throughput on modern accelerators. | Calibration and engine support complexity. |

Quantization is a release, not a toggle. Run task evals, safety evals, long-context evals, structured-output evals, and latency/load tests on the exact serving engine.

## Parallelism and Routing

| Strategy | Use | Cost |
| --- | --- | --- |
| Data parallel replicas | Scale independent traffic. | More weight copies. |
| Tensor parallelism | Split matrix work across GPUs. | Collective communication and interconnect sensitivity. |
| Pipeline parallelism | Split layers across stages. | Pipeline bubbles and higher latency for small batches. |
| Expert parallelism | MoE serving. | Routing/load-balance complexity. |
| Model routing | Choose model by task, tenant, cost, latency. | Routing becomes part of product behavior. |
| Fallback routing | Fail over to smaller/older/remote models. | Compatibility and user-visible quality changes. |
| Adapter routing | Pick LoRA adapter per tenant/task. | Cache pressure and adapter compatibility. |

Routing policy should record the model, adapter, tokenizer, generation config, prompt template, safety policy, and rollback route for every served request.

## Security and Tenant Isolation

| Risk | Why It Matters | Control |
| --- | --- | --- |
| Cross-tenant cache reuse | Prefix or response caches can expose another tenant's context. | Scope caches by tenant, auth boundary, model, tokenizer, template, adapter, and policy. |
| Prompt logging leakage | Prompts and outputs may contain secrets, PII, documents, or tool results. | Redaction, retention limits, access controls, sampling, and audit logs. |
| Adapter mix-up | Wrong LoRA adapter can leak tenant behavior or data. | Route-level adapter IDs, compatibility checks, and per-adapter metrics. |
| Tool-call drift | Engine or prompt changes can alter tool arguments. | Schema validation, deterministic authorization, replay tests. |
| Model supply chain | Artifacts may be malicious, unlicensed, or unreviewed. | Use trusted formats, pinned revisions, license review, checksum/signature policy. |
| Overload abuse | Long contexts and outputs can exhaust KV cache. | Quotas, max prompt/output tokens, admission control, and tenant rate limits. |

Security review should include cache boundaries, logs, model artifacts, adapters, generation config, routing rules, and client-visible API behavior.

## Performance Test Matrix

| Test Axis | Values to Include |
| --- | --- |
| Prompt length | p50, p90, p95, p99, max allowed. |
| Output length | p50, p90, p95, p99, max allowed. |
| Concurrency | expected, burst, overload, tenant hot spot. |
| Traffic mix | short chat, long RAG, batch, agent loops, streaming. |
| Runtime variant | baseline engine, new engine, quantized, speculative, prefix cache. |
| Model variant | old/new weights, adapter, tokenizer, chat template. |
| Hardware | GPU type, count, interconnect, driver, CUDA/runtime version. |

Track these metrics:

| Metric | Why |
| --- | --- |
| TTFT p50/p95/p99 | User waits before seeing output. |
| ITL p50/p95/p99 | Streaming smoothness. |
| End-to-end latency | Total user-visible time. |
| Prompt tokens/sec | Prefill throughput. |
| Generation tokens/sec | Decode throughput. |
| Queue time | Admission and capacity pressure. |
| Active/waiting requests | Scheduler load. |
| KV-cache utilization | Memory pressure. |
| Preemptions/swaps/recomputes | Cache exhaustion or scheduler contention. |
| Prefix cache hit rate | Prefix caching value. |
| Speculative acceptance rate | Speculation value. |
| Error/retry/reject rate | User-visible reliability. |
| Cost per 1K input/output tokens | Unit economics. |

## Debugging Runbooks

| Symptom | First Split | Likely Checks |
| --- | --- | --- |
| Wrong output | Model behavior vs serving mismatch. | Tokenizer, chat template, generation config, adapter, model revision. |
| High TTFT | Queue vs prefill. | Queue time, prompt tokens, prefix cache hits, chunked prefill, replicas. |
| Slow streaming | Decode vs network/client. | ITL, output tokens, KV pressure, memory bandwidth, speculation. |
| OOM under burst | Weights vs KV vs workspace. | Max model len, concurrency, cache usage, quantization, request limits. |
| GPU busy but throughput low | Kernel/shape/scheduler issue. | Batch occupancy, sequence length mix, tensor parallel overhead. |
| Queue high but GPU low | Admission/routing bottleneck. | Router, rate limits, worker health, blocked scheduler. |
| Prefix cache no gain | Prefix mismatch. | Tokenized prefix equality, template drift, tenant boundaries. |
| Speculation no gain | Low acceptance or overhead. | Draft quality, sampling config, accepted-token counters. |
| Adapter latency spike | Adapter-specific behavior. | Adapter rank, active adapters, cache pressure, routing. |
| Runtime upgrade regression | Compatibility drift. | Golden prompts, structured outputs, latency diff, metrics names. |

## Release Gates

Before changing model, runtime, quantization, prompt template, tokenizer, adapter, or generation config:

1. Record old and new artifact revisions.
2. Run golden quality evals and structured-output checks.
3. Run safety, refusal, and jailbreak slices where relevant.
4. Compare tokenization for representative prompts.
5. Load test short, long prompt, long output, and burst shapes.
6. Compare TTFT, ITL, throughput, queue time, cache usage, and error rate.
7. Canary by tenant or route with automatic rollback conditions.
8. Preserve old engine/model artifacts until rollback is proven.

## Practical Labs

| Lab | Goal |
| --- | --- |
| KV-cache capacity worksheet | Estimate memory by model, context, dtype, and concurrency. |
| Engine shootout | Compare vLLM, TGI, TensorRT-LLM, llama.cpp, SGLang, or Ollama for one model. |
| Prefix caching benchmark | Measure TTFT with repeated and non-repeated prefixes. |
| Long-context OOM lab | Find the prompt/output/concurrency point that exhausts KV memory. |
| Streaming cancellation lab | Confirm disconnected clients release decode work and KV cache. |
| Continuous batching demo | Compare static-style load to mixed-length continuous batching. |
| Speculative decoding A/B | Compare accepted-token rate, ITL, quality, and cost. |
| Quantization comparison | Compare weight quantization and KV quantization separately. |
| Multi-LoRA routing | Measure adapter-specific latency and correctness. |
| Canary drill | Practice rollback from a runtime or generation-config regression. |
| Metrics dashboard | Build panels for TTFT, ITL, queue, cache, preemptions, errors, cost. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is LLM inference a systems problem?" answer="Outputs and cost depend on weights, tokenizer, prompt format, generation config, runtime engine, KV cache, batching, hardware, and observability." %}
  {% include study-card.html question="How are weights different from KV cache?" answer="Weights are loaded model parameters shared by requests; KV cache is per-active-sequence attention state that grows with prompt and generated tokens." %}
  {% include study-card.html question="When should you compare inference engines?" answer="When model format, latency, throughput, quantization, adapter support, hardware, observability, or operating model changes." %}
  {% include study-card.html question="Why separate TTFT from ITL?" answer="TTFT captures queue and prefill delay, while ITL captures decode and streaming smoothness." %}
  {% include study-card.html question="What makes prefix caching safe?" answer="The reused prefix must match at the token level and respect model, tokenizer, template, adapter, and tenant boundaries." %}
  {% include study-card.html question="Why test quantization as a release?" answer="It can change quality, safety, latency, memory use, and kernel compatibility." %}
</div>

## References

- [vLLM documentation](https://docs.vllm.ai/en/stable/)
- [Inside vLLM: Anatomy of a High-Throughput LLM Inference System](https://vllm.ai/blog/anatomy-of-vllm)
- [Hugging Face Transformers KV cache documentation](https://huggingface.co/docs/transformers/main/kv_cache)
- [Text Generation Inference documentation](https://huggingface.co/docs/text-generation-inference/index)
- [TensorRT-LLM documentation](https://nvidia.github.io/TensorRT-LLM/)
- [llama.cpp GitHub repository](https://github.com/ggml-org/llama.cpp)
- [SGLang documentation](https://docs.sglang.ai/)
- [Ollama documentation](https://github.com/ollama/ollama/tree/main/docs)
- [Efficient Memory Management for Large Language Model Serving with PagedAttention](https://arxiv.org/abs/2309.06180)
