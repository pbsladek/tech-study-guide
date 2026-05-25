---
title: Cross-Topic Study Paths
layout: page
permalink: /docs/study-paths/
summary: "Cross-topic paths for debugging a 504, Pod networking, Linux performance, TLS and mTLS, and cloud egress."
tags:
  - study
  - troubleshooting
  - networking
  - linux
---

# Cross-Topic Study Paths

These paths are designed for repeated practice. Each path crosses multiple topic boundaries because real incidents rarely respect the guide's navigation tree.

Use the page completion control in the right rail as you finish each topic. The path cards below calculate progress locally in the browser so you can repeat the same path without changing the repository.

{% include study-path-list.html %}

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why use cross-topic study paths?" answer="They practice the same boundary crossings that production incidents require." %}
  {% include study-card.html question="Which path should start a 504 investigation?" answer="Request Path, then Cross-Layer Incident Runbooks, load balancer behavior, timeout budget, and Kubernetes Services." %}
  {% include study-card.html question="Why does cloud egress need DNS and NAT together?" answer="DNS selects the target address, and that address determines whether traffic uses private routing, NAT, or public egress." %}
  {% include study-card.html question="Why start distributed storage debugging with placement?" answer="Placement and failure domains explain which OSDs should hold data and why recovery or fullness affects clients." %}
  {% include study-card.html question="Why separate RAG retrieval from generation?" answer="A model cannot ground an answer in a source the retriever failed to return." %}
</div>

## References

- [Request Path](/docs/networking/request-path/)
- [Incident Entry Points](/docs/troubleshooting/incident-entrypoints/)
- [Glossary](/docs/glossary/)
