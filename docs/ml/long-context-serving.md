---
title: Long-Context Serving
layout: page
permalink: /docs/ml/long-context-serving/
summary: "Long-context LLM serving with RoPE scaling, sliding-window attention, sink tokens, lost-in-the-middle behavior, KV-cache growth, prompt budgeting, and long-context evals."
tags:
  - machine-learning
  - inference
  - long-context
  - transformers
---

# Long-Context Serving

Long context expands what a model can read, but it does not make all tokens equally useful or cheap. Long prompts increase prefill latency, KV-cache memory, retrieval cost, and evaluation complexity.

## Command Examples

```text
prompt_budget:
  system: 800
  tools: 1200
  retrieved_context: 24000
  user: 500
  output_cap: 2000
  model_context: 32768
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Captured fields` | `Named fields with concrete values: IDs, scores, tokens, routes, states, timestamps, or errors.` | Turns a capture template into evidence you can compare across runs. |

Budget input and output together. Output tokens also consume context and KV cache.

## Long-Context Mechanics

| Topic | Why It Matters |
| --- | --- |
| Context window | Hard limit on input plus generated tokens. |
| RoPE scaling | Extends position handling but can affect quality. |
| Sliding-window attention | Reduces attention span and KV growth in supported models. |
| Sink tokens | Some models preserve early tokens for stability. |
| Lost in the middle | Models may underuse evidence buried in long contexts. |
| Prefix caching | Stable long prefixes can reduce repeated prefill. |
| Chunked prefill | Improves scheduling fairness for long prompts. |

## Serving Risks

| Risk | Mitigation |
| --- | --- |
| High TTFT | Compress prompts, cache prefixes, chunk prefill, route long prompts separately. |
| KV-cache OOM | Lower context, lower concurrency, quantize KV, add memory, use GQA/MQA models. |
| Lower answer quality | Evaluate evidence position and retrieval ordering. |
| Higher cost | Budget tokens and apply admission control. |
| Noisy neighbors | Separate long-context pool from short chat pool. |

## Long-Context Eval Design

| Eval | What It Catches |
| --- | --- |
| Evidence at beginning/middle/end | Lost-in-the-middle behavior. |
| Multi-document distractors | Retrieval and reasoning robustness. |
| Long prompt with short answer | Prefill cost vs value. |
| Long output generation | Decode occupancy and cache growth. |
| Truncation tests | Whether critical instructions survive budget pressure. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is long context not free?" answer="It increases prefill time, KV-cache memory, cost, and eval complexity." %}
  {% include study-card.html question="What is lost-in-the-middle behavior?" answer="The model may fail to use relevant evidence placed in the middle of a long context." %}
  {% include study-card.html question="Why route long-context traffic separately?" answer="It prevents long prompts from consuming cache and scheduler capacity needed for short-latency traffic." %}
</div>

## References

- [RoFormer: Enhanced Transformer with Rotary Position Embedding](https://arxiv.org/abs/2104.09864)
- [Lost in the Middle](https://arxiv.org/abs/2307.03172)
- [Hugging Face KV cache documentation](https://huggingface.co/docs/transformers/main/kv_cache)
