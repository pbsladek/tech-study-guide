---
title: MoE Inference
layout: page
permalink: /docs/ml/moe-inference/
summary: "Mixture-of-Experts inference with active vs total parameters, expert routing, expert parallelism, all-to-all communication, load balance, capacity, KV cache, and serving tradeoffs."
tags:
  - machine-learning
  - inference
  - moe
  - transformers
---

# MoE Inference

Mixture-of-Experts models contain many expert feed-forward networks but route each token to only a subset. This can increase total parameter count without activating every parameter per token, but it adds routing, load balancing, communication, and serving complexity.

## Command Examples

```text
model:
  total_parameters:
  active_parameters_per_token:
  num_experts:
  experts_per_token:
  layers_with_experts:
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Captured fields` | `Named fields with concrete values: IDs, scores, tokens, routes, states, timestamps, or errors.` | Turns a capture template into evidence you can compare across runs. |

Always distinguish total parameters from active parameters. Total parameters drive storage and loading. Active parameters drive per-token compute.

## MoE Concepts

| Concept | Serving Meaning |
| --- | --- |
| Router/gate | Chooses experts per token. |
| Expert | Usually an MLP block specialized by training. |
| Top-k experts | Number of experts activated per token. |
| Active parameters | Parameters used for one token. |
| Total parameters | Full model storage and memory footprint. |
| Expert parallelism | Splits experts across devices. |
| All-to-all | Communication pattern for dispatching tokens to experts. |
| Load imbalance | Hot experts cause stalls or dropped capacity. |

## Performance Tradeoffs

| Benefit | Cost |
| --- | --- |
| More capacity without activating all weights. | More complex routing and communication. |
| Potentially strong quality per active FLOP. | Expert imbalance can hurt throughput. |
| Experts can specialize. | Debugging token routing is harder. |
| Sparse activation lowers compute. | Total weights still need storage/loading. |

MoE attention still uses KV cache. Expert routing changes MLP compute and communication, not the fundamental need to cache attention keys and values during autoregressive decode.

## Operational Checks

| Check | Why |
| --- | --- |
| Active vs total params | Capacity and cost planning. |
| Expert utilization | Detect hot or unused experts. |
| All-to-all latency | Interconnect bottleneck signal. |
| Batch shape | Token routing imbalance can worsen with small batches. |
| Quantization compatibility | Experts and router may have different sensitivity. |
| Fallback route | MoE serving issues can require dense-model fallback. |

## Incident Flow

1. Confirm whether latency is attention, expert MLP, or communication bound.
2. Compare expert utilization and all-to-all timing.
3. Check batch size, sequence length mix, and routing skew.
4. Compare dense baseline if available.
5. Check quantization or runtime changes near the incident.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why separate active and total parameters for MoE?" answer="Total parameters affect storage/loading, while active parameters affect per-token compute." %}
  {% include study-card.html question="What makes MoE inference operationally harder?" answer="Expert routing, load imbalance, expert parallelism, and all-to-all communication add bottlenecks." %}
  {% include study-card.html question="Does MoE remove KV-cache pressure?" answer="No. MoE changes expert MLP compute, but attention still needs KV cache during autoregressive inference." %}
</div>

## References

- [Switch Transformers](https://arxiv.org/abs/2101.03961)
- [GShard](https://arxiv.org/abs/2006.16668)
- [NVIDIA TensorRT-LLM documentation](https://nvidia.github.io/TensorRT-LLM/)
