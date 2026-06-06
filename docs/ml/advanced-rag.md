---
title: Advanced RAG
layout: page
permalink: /docs/ml/advanced-rag/
summary: "Advanced retrieval-augmented generation with hybrid retrieval, query planning, multi-hop retrieval, reranker architectures, GraphRAG, context compression, citation verification, agentic RAG, retrieval evals, and RAG security."
tags:
  - machine-learning
  - rag
  - retrieval
  - advanced
---

# Advanced RAG

Advanced RAG is a retrieval system, ranking system, prompt assembly system, and verification system. The generator is only the last stage.

## Command Examples

```text
For one bad answer, capture:
  query
  rewritten query
  top-k chunks
  reranked chunks
  final context
  answer
  citations
  expected source
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `Captured fields` | `Named fields with concrete values: IDs, scores, tokens, routes, states, timestamps, or errors.` | Turns a capture template into evidence you can compare across runs. |

## Advanced Patterns

| Pattern | Use | Risk |
| --- | --- | --- |
| Hybrid retrieval | Combine lexical and vector search. | Score fusion and tuning complexity. |
| Query planning | Break a question into retrieval subqueries. | Over-planning and extra latency. |
| Multi-hop retrieval | Retrieve evidence across multiple documents. | Missing bridge entities or compounding errors. |
| Reranker architectures | Cross-encoder or LLM reranking. | Latency and overfitting to benchmark style. |
| GraphRAG | Use entities and relationships. | Graph extraction quality and stale edges. |
| Context compression | Reduce tokens while preserving evidence. | Dropping critical qualifiers. |
| Citation verification | Check claims against sources. | Requires claim segmentation and source alignment. |
| Agentic RAG | Let an agent decide retrieval actions. | Tool loops, cost, and harder evals. |

## Retrieval Evaluation Dataset

| Field | Purpose |
| --- | --- |
| Query | User-facing question. |
| Relevant source IDs | Ground truth for Recall@k. |
| Required claims | What the answer must support. |
| Forbidden sources | ACL and tenant isolation checks. |
| Freshness version | Ensures index recency is tested. |
| Difficulty slice | Exact term, semantic, multi-hop, ambiguous, adversarial. |

## Practical Lab: Citation Verification

```text
answer_claim: "CloudNativePG performs rolling PostgreSQL minor updates."
cited_source: docs/databases/postgres/cloudnativepg
verifier_question: "Does the cited source support the exact claim?"
labels: supported | partially_supported | unsupported
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why use hybrid retrieval?" answer="Lexical search catches exact terms and identifiers while vector search catches semantic similarity." %}
  {% include study-card.html question="What is multi-hop retrieval?" answer="Retrieving multiple pieces of evidence that must be connected to answer one question." %}
  {% include study-card.html question="Why verify citations?" answer="A cited document can be related without supporting the exact generated claim." %}
</div>

## References

- [Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks](https://arxiv.org/abs/2005.11401)
- [BEIR retrieval benchmark](https://arxiv.org/abs/2104.08663)
- [From Local to Global: A Graph RAG Approach](https://arxiv.org/abs/2404.16130)
