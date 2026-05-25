---
title: "ML Accelerators: GPU and TPU"
layout: page
permalink: /docs/ml/accelerators-gpu-tpu/
summary: "GPU and TPU fundamentals for ML workloads: parallelism, memory, precision, batching, utilization, data movement, and troubleshooting."
tags:
  - machine-learning
  - gpu
  - tpu
  - performance
---

# ML Accelerators: GPU and TPU

ML accelerators make tensor operations fast by running many numeric operations in parallel. They are excellent at dense matrix multiplication, convolutions, attention kernels, and batched workloads. They are poor at work dominated by Python overhead, serial control flow, slow input pipelines, or host-device copies.

## First Checks

```bash
nvidia-smi
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.device_count())"
python -c "import torch; print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'cpu')"
```

For TPUs, the equivalent checks depend on the cloud/runtime, but the same question applies: can the framework see the accelerator, compile the graph, and feed it fast enough?

## GPU vs TPU

| Area | GPU | TPU |
| --- | --- | --- |
| Common stack | CUDA, ROCm, PyTorch, TensorRT, vendor libraries. | XLA/JAX/TensorFlow/PyTorch XLA depending on platform. |
| Strength | Flexible kernels, broad ecosystem, training and inference. | Large matrix workloads, XLA-compiled graphs, scale-out pods. |
| Programming model | Eager plus compiled paths, explicit device memory behavior. | Graph compilation and static-shape friendliness matter more. |
| Operational signal | `nvidia-smi`, DCGM, CUDA errors, GPU memory. | XLA compile time, device mesh, input stalls, TPU metrics. |

## Memory and Precision

Accelerator memory is often the hard limit.

Memory consumers:

- model weights,
- optimizer state,
- activations,
- gradients,
- key/value cache for autoregressive inference,
- batch tensors,
- temporary kernel workspaces.

Precision changes memory and speed:

| Precision | Use |
| --- | --- |
| FP32 | Stable baseline, expensive. |
| FP16 | Common on GPUs, faster and smaller, needs scaling in training. |
| BF16 | Wide exponent, common for modern training. |
| INT8 / INT4 | Inference quantization, smaller, may reduce quality. |

## Utilization

Low accelerator utilization usually means the bottleneck is somewhere else.

Check:

```bash
nvidia-smi dmon
python -m torch.utils.bottleneck <script.py>
```

Common bottlenecks:

- CPU preprocessing,
- dataloader workers too low,
- small batch size,
- host-device copies,
- frequent synchronization,
- dynamic shapes causing recompilation,
- slow storage or network input,
- model too small to fill the device.

## Accelerator Production Gaps

Accelerator incidents usually come from memory arithmetic, input stalls, synchronization, or distributed behavior that the model code does not make obvious.

| Gap | What To Fill | Operational Check |
| --- | --- | --- |
| ML-GAP-013 Accelerator Memory Math | Estimate weights, activations, gradients, optimizer state, KV cache, and temporary workspace before choosing batch size or model size. | Keep a memory budget per training and inference mode. |
| ML-GAP-014 Tensor Cores and Matrix Units | Use dimensions, dtypes, and kernels that hit tensor cores or TPU matrix units instead of falling back to slower paths. | Profile kernel names and achieved FLOPS, not only utilization percentage. |
| ML-GAP-015 Mixed Precision Overflow | FP16 can overflow or underflow; BF16 is more forgiving but still needs eval coverage. | Watch loss scaling, `nan` loss, gradient norms, and dtype-specific eval regressions. |
| ML-GAP-016 Gradient Checkpointing | Recompute activations to save memory when model depth or sequence length exceeds device capacity. | Compare memory saved against extra compute and wall-clock cost. |
| ML-GAP-017 CPU-GPU Transfer Bottlenecks | Host-device copies and CPU preprocessing can starve accelerators. | Track data-loader time, pinned memory, prefetching, and copy overlap. |
| ML-GAP-018 Batch Size Tradeoffs | Larger batches improve throughput but can hurt latency, convergence, memory, or generalization. | Sweep batch size with latency, throughput, memory, and quality metrics together. |
| ML-GAP-019 Distributed Training Topology | Data, tensor, pipeline, and expert parallelism stress different interconnects and failure modes. | Map ranks to hosts, GPUs, NUMA, and network paths before scaling. |
| ML-GAP-020 NCCL and Collective Failures | All-reduce stalls, rank crashes, and interface mismatch can freeze distributed training. | Capture rank logs, `NCCL_DEBUG`, selected NICs, and timeout settings. |
| ML-GAP-021 GPU Fragmentation | Allocator fragmentation can produce OOM even when total free memory looks sufficient. | Compare reserved versus allocated memory and restart workers for long-lived fragmentation. |
| ML-GAP-022 Profiling Kernels | Wall-clock time needs kernel, memory-bandwidth, and synchronization evidence. | Use PyTorch profiler, Nsight, TPU traces, or framework profiler before changing code. |
| ML-GAP-023 Serving Utilization | Inference utilization depends on batching, KV cache, prefill/decode balance, and request shape distribution. | Track tokens/sec, queue time, batch occupancy, memory headroom, and tail latency. |

## Operational Runbook

1. Confirm framework sees the accelerator.
2. Confirm the model and tensors are on the same device.
3. Check memory headroom before increasing batch size.
4. Check input pipeline and CPU utilization.
5. Check accelerator utilization and memory bandwidth.
6. Use mixed precision only with evaluation gates.
7. For distributed training, check interconnect, rank health, and all-reduce time.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why can GPU utilization be low during ML training?" answer="The bottleneck may be CPU preprocessing, small batches, data loading, synchronization, or host-device copies." %}
  {% include study-card.html question="What consumes accelerator memory during training?" answer="Weights, activations, gradients, optimizer state, batches, and temporary kernel workspaces." %}
  {% include study-card.html question="Why is BF16 common in modern training?" answer="It reduces memory and bandwidth while preserving a wider exponent range than FP16." %}
  {% include study-card.html question="Why do TPUs favor static-shape workloads?" answer="XLA compilation and device execution are more efficient when shapes and graphs are stable." %}
</div>

## References

- [NVIDIA CUDA C Programming Guide](https://docs.nvidia.com/cuda/cuda-c-programming-guide/)
- [PyTorch CUDA semantics](https://pytorch.org/docs/stable/notes/cuda.html)
- [Google Cloud TPU documentation](https://cloud.google.com/tpu/docs)
- [PyTorch performance tuning guide](https://pytorch.org/tutorials/recipes/recipes/tuning_guide.html)
