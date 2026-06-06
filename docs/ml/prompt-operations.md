---
title: ML Prompt Operations
layout: page
permalink: /docs/ml/prompt-operations/
summary: "Prompt engineering operations with templates, versioning, structured outputs, injection resistance, system/developer/user boundaries, evals, and rollback."
tags:
  - machine-learning
  - prompts
  - operations
  - llm
---

# ML Prompt Operations

Prompts are production code. They define task framing, tool policy, response format, safety posture, retrieval usage, and error behavior. Prompt changes should be versioned, reviewed, evaluated, and rolled back like model or application changes.

Prompt templates should be treated as named, versioned artifacts instead of anonymous strings hidden in application code.

## Command Examples

```bash
find prompts -type f | sort
git diff -- prompts/
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `find prompts -type f \\| sort` | `Sorted file paths such as data/train.parquet and data/validation.parquet.` | Shows which files the pipeline or prompt loader will actually consume. |
| `git diff -- prompts/` | `Concrete IDs, states, counters, versions, rows, or error strings.` | Turns the example from a command list into evidence for the next debugging step. |

If prompts live in code or a database, export the exact active prompt bundle before debugging.

## Prompt Contract

| Part | What It Controls |
| --- | --- |
| System message | Global role, safety constraints, output boundaries. |
| Developer message | Application-specific task rules and tool rules. |
| User message | User intent and input data. |
| Retrieved context | External evidence, citations, and grounding material. |
| Tool schema | Available actions and structured input constraints. |
| Output schema | JSON, citations, refusal format, or other response contract. |

## Versioning Checklist

- prompt template ID,
- prompt text hash,
- model ID,
- tokenizer/chat template,
- retrieval prompt assembly code,
- tool schema version,
- output schema version,
- generation config,
- eval report,
- rollout status.

## Structured Outputs

Use structured outputs when downstream systems need predictable fields. Treat the schema as an API contract.

```json
{
  "answer": "short response",
  "citations": ["source-id"],
  "confidence": "low|medium|high",
  "needs_human_review": false
}
```

Structured output still needs semantic validation. Valid JSON can contain unsupported claims or unsafe tool arguments.

## Prompt Failure Modes

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| Ignores retrieved evidence | Context too long, weak instruction hierarchy, conflicting chunks. | Improve context assembly and citation checks. |
| Verbose or off-format output | Output schema unclear or not enforced. | Use schema validation and examples. |
| Unsafe tool choice | Tool policy embedded only in natural language. | Enforce tool authorization outside the prompt. |
| Fragile improvements | Prompt tuned to a tiny eval set. | Expand slices and run regression cases. |
| Injection success | Untrusted text mixed with instructions. | Delimit data, quote sources, and add injection evals. |

## Prompt Release Runbook

1. Render prompts for representative cases.
2. Run golden, safety, retrieval, and formatting evals.
3. Compare token count and latency against baseline.
4. Review failures by slice and severity.
5. Canary the new prompt with per-version metrics.
6. Roll back by prompt bundle ID if thresholds fail.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why are prompts production code?" answer="They control task behavior, tool policy, output format, safety boundaries, and retrieval usage." %}
  {% include study-card.html question="What should be versioned with a prompt?" answer="Template text, model, chat template, tool schema, output schema, retrieval assembly, generation config, and eval report." %}
  {% include study-card.html question="Why is valid JSON not enough for structured outputs?" answer="The JSON can still contain unsupported claims, unsafe actions, or semantically invalid values." %}
</div>

## References

- [vLLM OpenAI-Compatible Server](https://docs.vllm.ai/en/stable/serving/openai_compatible_server/)
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
