---
title: ML Performance Engineering
layout: page
permalink: /docs/ml/performance-engineering/
summary: "ML performance engineering with training-loop profiling, GPU utilization, memory bandwidth, activation checkpointing, FlashAttention, fused kernels, distributed training bottlenecks, inference throughput tuning, and cost/performance tradeoffs."
tags:
  - machine-learning
  - performance
  - gpu
  - inference
---

# ML Performance Engineering

ML performance work starts with measurement. Guessing often optimizes the wrong layer: Python overhead, input pipeline, GPU kernels, memory bandwidth, collective communication, queueing, or model quality constraints.

## Command Examples

```bash
nvidia-smi dmon
python -m torch.utils.bottleneck train.py
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `nvidia-smi dmon` | `GPU utilization, memory use, CUDA visibility, model list, or serving metrics.` | Separates accelerator visibility from model-serving capacity and latency. |
| `python -m torch.utils.bottleneck train.py` | `GPU utilization, memory use, CUDA visibility, model list, or serving metrics.` | Separates accelerator visibility from model-serving capacity and latency. |

## Bottleneck Map

| Bottleneck | Signal | Lever |
| --- | --- | --- |
| CPU input pipeline | GPU idle, CPU busy. | More workers, caching, prefetch, vectorized transforms. |
| Host-device copies | Copy time high. | Pinned memory, async copies, move transforms to GPU. |
| Kernel overhead | Many tiny kernels. | Fuse ops, compile, larger batches. |
| Memory bandwidth | FLOPS low, bandwidth high. | Better layout, fused kernels, lower precision. |
| Activation memory | OOM in training. | Activation checkpointing, sequence/batch reduction. |
| Collectives | Distributed stalls. | Topology, bucket sizes, faster interconnect. |
| Inference queue | High TTFT. | Autoscale, admission control, batching policy. |

## Advanced Techniques

| Technique | Helps | Risk |
| --- | --- | --- |
| FlashAttention | Efficient attention memory and speed. | Kernel/version compatibility. |
| Fused kernels | Less launch overhead and memory traffic. | Debugging and portability. |
| `torch.compile` | Graph optimization. | Dynamic shape and op support issues. |
| Activation checkpointing | Lower training memory. | Extra compute. |
| Quantization | Lower inference memory/cost. | Quality and calibration. |
| Speculative decoding | Lower decode latency. | Acceptance rate and overhead. |

## Practical Lab: Performance Report

```text
baseline:
  throughput:
  p95_latency:
  gpu_utilization:
  memory_used:
candidate:
  change:
  throughput:
  p95_latency:
  quality_delta:
decision:
```

Never accept a performance gain without a quality and regression check.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why profile before optimizing ML code?" answer="The bottleneck may be input, CPU, copies, kernels, memory, communication, queueing, or decoding." %}
  {% include study-card.html question="What does activation checkpointing trade?" answer="It saves memory by recomputing activations, increasing compute time." %}
  {% include study-card.html question="Why pair performance tests with quality evals?" answer="Optimization can change precision, decoding, batching, or context behavior in ways that affect outputs." %}
</div>

## References

- [PyTorch Performance Tuning Guide](https://pytorch.org/tutorials/recipes/recipes/tuning_guide.html)
- [FlashAttention](https://arxiv.org/abs/2205.14135)
- [PyTorch Profiler](https://pytorch.org/tutorials/recipes/recipes/profiler_recipe.html)
