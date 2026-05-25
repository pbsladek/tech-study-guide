---
title: PyTorch Fundamentals
layout: page
permalink: /docs/ml/pytorch-fundamentals/
summary: "PyTorch fundamentals for tensors, modules, autograd, losses, optimizers, dataloaders, training loops, mixed precision, and checkpointing."
tags:
  - machine-learning
  - pytorch
  - training
  - tensors
---

# PyTorch Fundamentals

PyTorch is a tensor library plus an automatic differentiation system and neural-network module ecosystem. Most training code is a loop over batches: run the model, compute loss, backpropagate gradients, update weights, and evaluate.

## First Checks

```bash
python - <<'PY'
import torch
print(torch.__version__)
print(torch.cuda.is_available())
x = torch.randn(4, 8)
print(x.mean().item())
PY
```

## Core Objects

| Object | Role |
| --- | --- |
| Tensor | N-dimensional numeric array with device and dtype. |
| `nn.Module` | Stateful model component containing parameters and submodules. |
| Parameter | Tensor registered as trainable model state. |
| Autograd graph | Dynamic graph PyTorch builds to compute gradients. |
| Loss | Scalar objective to minimize or maximize. |
| Optimizer | Updates parameters using gradients and optimizer state. |
| Dataset/DataLoader | Input examples and batching pipeline. |
| Checkpoint | Saved model, optimizer, scheduler, and training metadata. |

## Minimal Training Loop

```python
import torch
from torch import nn

model = nn.Sequential(nn.Linear(10, 32), nn.ReLU(), nn.Linear(32, 1))
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3)
loss_fn = nn.MSELoss()

for features, target in dataloader:
    prediction = model(features)
    loss = loss_fn(prediction, target)
    optimizer.zero_grad(set_to_none=True)
    loss.backward()
    optimizer.step()
```

This pattern hides important details: device movement, dtype, gradient accumulation, clipping, evaluation mode, checkpointing, and reproducibility.

## Training vs Evaluation

```python
model.train()
# gradients and training-time module behavior

model.eval()
with torch.no_grad():
    prediction = model(batch)
```

`train()` and `eval()` change modules such as dropout and batch norm. `torch.no_grad()` disables gradient tracking for inference/evaluation.

## Device and Dtype

```python
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)
features = features.to(device)
```

All tensors participating in an operation must generally be on compatible devices. Mixed CPU/GPU tensors cause runtime errors or implicit slow paths.

## Checkpointing

```python
torch.save({
    "model": model.state_dict(),
    "optimizer": optimizer.state_dict(),
    "epoch": epoch,
}, "checkpoint.pt")
```

Save enough state to resume or audit the run: architecture config, weights, optimizer, scheduler, tokenizer/preprocessor, random seeds, dataset version, and metrics.

## Training Loop Correctness Gaps

PyTorch gives direct control over the training loop, which means correctness depends on explicit handling of state, randomness, gradient flow, and evaluation behavior.

| Gap | What To Fill | Operational Check |
| --- | --- | --- |
| ML-GAP-024 Dataset and DataLoader Boundaries | Separate dataset indexing, transforms, collation, shuffling, worker state, and batch shape assumptions. | Test one batch end-to-end before starting a long run. |
| ML-GAP-025 Reproducibility Seeds | Seed Python, NumPy, PyTorch, workers, and distributed ranks while recording nondeterministic kernel settings. | Store seed, library versions, device type, and determinism flags with each run. |
| ML-GAP-026 Autograd Graph Lifetime | Know when graphs are freed, retained, detached, or accidentally expanded across iterations. | Watch memory growth and use `detach()` intentionally for recurrent or cached tensors. |
| ML-GAP-027 Gradient Accumulation | Accumulate gradients deliberately when effective batch size exceeds memory. | Scale loss or learning rate consistently and step the optimizer only at accumulation boundaries. |
| ML-GAP-028 Gradient Clipping | Clip exploding gradients for unstable sequence, RL, or fine-tuning workloads. | Log gradient norms before and after clipping. |
| ML-GAP-029 Optimizer State | Adam-like optimizers keep state that can exceed model weight memory. | Include optimizer memory in GPU budget and checkpoint size estimates. |
| ML-GAP-030 Learning Rate Schedules | Warmup, decay, cosine, step, or constant schedules change convergence and stability. | Plot learning rate against loss and validation metrics. |
| ML-GAP-031 AMP GradScaler | Automatic mixed precision needs scaling on FP16 training to avoid underflow and overflow. | Check skipped steps, scaler value, `nan` gradients, and dtype coverage. |
| ML-GAP-032 DistributedDataParallel | DDP needs correct rank setup, sampler sharding, gradient synchronization, and identical model graphs. | Confirm each rank sees a distinct data shard and reaches barriers. |
| ML-GAP-033 Checkpoint Resume State | Resume requires model, optimizer, scheduler, scaler, epoch/step, RNG, and data cursor state. | Resume from a checkpoint in CI or a smoke run, not only after an outage. |
| ML-GAP-034 Torch Compile and Export | `torch.compile`, TorchScript, ONNX, and export paths can alter supported ops, shapes, and debugging behavior. | Compare compiled/exported output against eager output on representative inputs. |
| ML-GAP-035 Evaluation Mode Hazards | Forgetting `eval()` or `no_grad()` changes dropout, batch norm, gradient memory, and reported metrics. | Wrap validation in a helper that sets mode and restores the previous mode. |

## Common Failures

| Symptom | Likely Cause |
| --- | --- |
| Loss is `nan` | Learning rate too high, bad labels, unstable precision, exploding gradients. |
| GPU unused | Tensors or model still on CPU, dataloader bottleneck, tiny batch. |
| Eval differs from training | Forgot `model.eval()`, data leakage, preprocessing mismatch. |
| Cannot resume | Saved only weights, not optimizer/scheduler/config. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does autograd compute?" answer="Gradients of tensor operations so optimizers can update model parameters." %}
  {% include study-card.html question="Why call optimizer.zero_grad before backward?" answer="PyTorch accumulates gradients by default, so old gradients must be cleared or intentionally accumulated." %}
  {% include study-card.html question="What does model.eval change?" answer="It switches modules such as dropout and batch norm to evaluation behavior." %}
  {% include study-card.html question="Why save optimizer state in checkpoints?" answer="Optimizers such as Adam keep momentum-like state needed to resume training faithfully." %}
</div>

## References

- [PyTorch tutorials](https://pytorch.org/tutorials/)
- [PyTorch autograd mechanics](https://pytorch.org/docs/stable/notes/autograd.html)
- [PyTorch saving and loading models](https://pytorch.org/tutorials/beginner/saving_loading_models.html)
- [PyTorch performance tuning guide](https://pytorch.org/tutorials/recipes/recipes/tuning_guide.html)
