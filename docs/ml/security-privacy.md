---
title: ML Security and Privacy
layout: page
permalink: /docs/ml/security-privacy/
summary: "ML security and privacy risks including prompt injection, data exfiltration, model supply chain, poisoned retrieval, tenant isolation, PII, retention, and audit logging."
tags:
  - machine-learning
  - security
  - privacy
  - safety
---

# ML Security and Privacy

ML systems add new ways to misuse ordinary infrastructure: prompts can carry instructions, retrieved documents can poison context, tools can perform side effects, and logs can capture sensitive data. Security controls need to surround the model, not depend on the model obeying policy.

## Command Examples

```bash
date -Is
git diff --name-only
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `date -Is` | `2026-06-06T10:24:33-07:00` | Pins command output and logs to an exact incident timestamp. |
| `git diff --name-only` | `prompts/support.yaml and evals/golden.jsonl` | Shows which prompt, eval, or policy artifacts changed in the release. |

For a real system, start by listing data classes, model artifacts, tool permissions, retrieval sources, logging paths, and retention rules.

## Threat Matrix

| Threat | Example | Control |
| --- | --- | --- |
| Prompt injection | Retrieved document says to ignore policy or reveal secrets. | Treat retrieved text as untrusted data; separate instructions from evidence. |
| Data exfiltration | Model includes private source text in answer to unauthorized user. | ACL filtering before prompt assembly and output review for sensitive data. |
| Tool abuse | Model calls delete, purchase, deploy, or send-message tools unexpectedly. | Deterministic authorization, approval gates, and idempotency. |
| Model supply chain | Untrusted checkpoint, tokenizer, adapter, or custom code. | Pin artifact hashes, avoid remote code, scan licenses and provenance. |
| Retrieval poisoning | Attacker inserts malicious or low-quality documents into RAG corpus. | Source allowlists, ingestion review, document trust scoring. |
| Training data leakage | Secrets or PII enter fine-tune or eval data. | Redaction, data classification, retention, and deletion workflows. |
| Tenant isolation failure | One tenant's documents or adapters affect another tenant. | Tenant-scoped indexes, model routes, cache boundaries, and tests. |

## Privacy Controls

| Area | Practical Control |
| --- | --- |
| Prompt logging | Minimize, redact, sample, encrypt, and expire logs. |
| Training data | Track consent, allowed use, deletion, and provenance. |
| RAG corpus | Store document ACLs and enforce them before retrieval context assembly. |
| Fine-tunes | Keep dataset manifests and remove disallowed examples before training. |
| Human review | Remove unnecessary PII and control reviewer access. |
| Model outputs | Detect sensitive data and provide appeal/escalation paths where needed. |

## Security Release Gate

1. Confirm model, tokenizer, adapter, and container provenance.
2. Verify artifact hashes and license constraints.
3. Run prompt-injection and data-exfiltration evals.
4. Test tenant ACLs with positive and negative cases.
5. Test tool authorization outside the model.
6. Review logging, retention, redaction, and user-data handling.
7. Confirm incident audit trails and rollback.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why should retrieved RAG text be treated as untrusted?" answer="It can contain prompt-injection instructions or poisoned content that tries to steer the model." %}
  {% include study-card.html question="Where should tool authorization be enforced?" answer="In deterministic tool hosts and policy layers outside the model." %}
  {% include study-card.html question="Why is prompt logging a privacy risk?" answer="Prompts and outputs can contain PII, secrets, customer data, or regulated content." %}
</div>

## References

- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [vLLM Security](https://docs.vllm.ai/en/stable/usage/security/)
