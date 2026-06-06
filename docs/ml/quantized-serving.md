---
title: Quantized Serving
layout: page
permalink: /docs/ml/quantized-serving/
summary: "Quantized LLM serving with weight quantization, activation quantization, KV-cache quantization, GGUF, AWQ, GPTQ, FP8, quality gates, and rollout checks."
tags:
  - machine-learning
  - inference
  - quantization
  - serving
---

# Quantized Serving

Quantization represents model data with fewer bits to reduce memory, bandwidth, and cost. In serving, quantization is a release decision because it can change quality, latency, safety behavior, kernel compatibility, and rollback behavior.

## Command Examples

```bash
python - <<'PY'
import torch
for dtype in [torch.float32, torch.bfloat16, torch.float16, torch.int8]:
    print(dtype)
PY
vllm serve <model> --help | grep -i quant
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Python snippet` | `torch.float32`, `torch.bfloat16`, `torch.float16`, and `torch.int8`. | Confirms dtype names before comparing weight and KV-cache precision choices. |
| `vllm serve <model> --help | grep -i quant` | Quantization flags and supported option names. | Verifies the runtime exposes the quantization mode you plan to use. |

Do not assume a runtime supports every quantized artifact or that a supported artifact is quality-equivalent.

## Quantization Types

| Type | What Changes | Main Benefit | Main Risk |
| --- | --- | --- | --- |
| Weight-only INT8/INT4 | Model weights. | Lower model memory. | Quality loss and kernel support. |
| Activation quantization | Intermediate tensors. | Faster kernels on supported hardware. | Calibration sensitivity. |
| KV-cache quantization | Cached K/V tensors. | More context or concurrency. | Decode quality and kernel compatibility. |
| FP8 | Low-precision floating point. | High throughput on modern GPUs. | Hardware and calibration requirements. |
| GGUF quant levels | llama.cpp-family weights. | Local and edge memory reduction. | Quant choice affects speed and quality. |
| QLoRA | Quantized base for adapter training. | Lower fine-tuning memory. | Merge and serving compatibility. |

## Common Schemes

| Scheme | Where Seen | Notes |
| --- | --- | --- |
| AWQ | LLM weight quantization. | Often used for activation-aware weight-only serving. |
| GPTQ | Post-training weight quantization. | Artifact/runtime compatibility matters. |
| bitsandbytes | Training and inference workflows. | Convenient but not always fastest production path. |
| GGUF Q-types | llama.cpp. | Choose by model, hardware, and quality tolerance. |
| FP8 | H100/H200/B200-class paths and optimized engines. | Requires exact hardware/runtime validation. |

## Quality Gates

| Gate | Why |
| --- | --- |
| Golden prompts | Catch obvious behavior drift. |
| Structured output | Quantization can break exact schemas. |
| Long-context eval | Small numeric drift can compound. |
| Safety/refusal eval | Safety behavior can shift. |
| RAG faithfulness | Answers may become less grounded. |
| Tool-call eval | Arguments and formatting must remain valid. |
| Latency/load test | Smaller memory does not always mean faster serving. |

## Rollout Flow

1. Baseline full-precision model on exact evals and traffic shapes.
2. Quantize or select quantized artifact.
3. Verify tokenizer, chat template, adapter, and generation config compatibility.
4. Run quality, safety, long-context, and structured-output evals.
5. Run load tests for TTFT, ITL, throughput, cache usage, and errors.
6. Canary by route or tenant.
7. Preserve rollback artifact and runtime flags.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is quantized serving not just a memory toggle?" answer="It can change quality, safety, latency, kernel support, and rollback compatibility." %}
  {% include study-card.html question="How is KV-cache quantization different from weight quantization?" answer="Weight quantization compresses parameters; KV-cache quantization compresses per-request attention state." %}
  {% include study-card.html question="Why test structured output after quantization?" answer="Small numeric changes can break formatting, schemas, tool calls, or stop behavior." %}
</div>

## References

- [vLLM Quantization](https://docs.vllm.ai/en/stable/features/quantization/)
- [Hugging Face Quantization](https://huggingface.co/docs/transformers/main/quantization/overview)
- [llama.cpp quantization examples](https://github.com/ggml-org/llama.cpp)
- [QLoRA](https://arxiv.org/abs/2305.14314)
