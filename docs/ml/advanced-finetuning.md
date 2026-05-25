---
title: Advanced Fine-Tuning
layout: page
permalink: /docs/ml/advanced-finetuning/
summary: "Advanced fine-tuning with full tuning, LoRA, QLoRA, adapter composition, multi-adapter serving, dataset mixing, long-context tuning, packing, catastrophic forgetting, and safety-preserving releases."
tags:
  - machine-learning
  - finetuning
  - lora
  - advanced
---

# Advanced Fine-Tuning

Advanced fine-tuning is less about running a trainer and more about preserving behavior while changing a narrow capability. The hard problems are dataset mixture, template compatibility, forgetting, safety regression, and serving artifacts.

## First Checks

```bash
python -c "import transformers, peft; print(transformers.__version__); print(peft.__version__)"
```

## Method Selection

| Method | Use | Risk |
| --- | --- | --- |
| Full fine-tune | Maximum adaptation with enough data/compute. | Cost, forgetting, rollback complexity. |
| LoRA | Efficient targeted adaptation. | Target-module and rank choices. |
| QLoRA | Memory-constrained adapter training. | Quantization/runtime compatibility. |
| Adapter composition | Combine task or domain adapters. | Interference and routing complexity. |
| Long-context tuning | Teach behavior over long prompts. | Expensive examples, positional limits, eval gaps. |

## Dataset Mixing

Mixing controls what behavior survives. A domain dataset alone can overfit style and erase general instruction behavior. A good mixture usually includes:

- target task examples,
- general instruction examples,
- refusal and safety examples,
- hard negatives,
- old golden cases,
- held-out domain sources.

## Multi-Adapter Serving

Serving many adapters over one base model reduces memory but adds routing, compatibility, and cache pressure. Version base model, tokenizer, chat template, adapter, rank, dtype, and merge state together.

## Practical Lab: Fine-Tune Release Packet

```text
adapter:
  base_model:
  tokenizer:
  chat_template:
  target_modules:
  rank:
  dataset_manifest:
  eval_report:
  safety_report:
  merged_vs_unmerged_diff:
  rollback_command:
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why does dataset mixing matter in fine-tuning?" answer="It controls which old behaviors are preserved while the target task improves." %}
  {% include study-card.html question="What is adapter composition risk?" answer="Adapters trained for different tasks can interfere when combined or routed poorly." %}
  {% include study-card.html question="Why compare merged and unmerged adapters?" answer="Merging can change precision and behavior, so it needs its own release check." %}
</div>

## References

- [LoRA: Low-Rank Adaptation of Large Language Models](https://arxiv.org/abs/2106.09685)
- [QLoRA](https://arxiv.org/abs/2305.14314)
- [Hugging Face PEFT documentation](https://huggingface.co/docs/peft/index)
