---
title: Scenario Labs
layout: page
permalink: /docs/labs/
summary: "Operational labs for practicing cross-layer debugging with symptoms, evidence, checks, and answers."
tags:
  - study
  - troubleshooting
  - runbooks
---

# Scenario Labs

Each lab starts from symptoms, then asks for evidence before an answer. The same lab cards are embedded into the related topic pages so the scenario stays near the concepts and commands it exercises.

{% include scenario-labs.html %}

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why start labs from symptoms instead of commands?" answer="Symptoms force you to name the failing user-visible behavior before collecting evidence." %}
  {% include study-card.html question="What should evidence do in an operational lab?" answer="It should distinguish competing failure domains without depending on one favored fix." %}
  {% include study-card.html question="Why embed labs in topic pages?" answer="The lab can be practiced beside the protocol, system, or tool behavior it depends on." %}
</div>

## References

- [Incident Entry Points](/docs/troubleshooting/incident-entrypoints/)
- [Kubernetes DNS and CoreDNS](/docs/kubernetes/dns-coredns/)
- [PostgreSQL Operations and HA](/docs/databases/postgres/operations-ha/)
- [Ceph Operations and Recovery](/docs/ceph/operations-recovery/)
- [Istio Security, mTLS, and Policy](/docs/istio/security-mtls-policy/)
- [NAT Gateways and NAT](/docs/networking/nat-gateways/)
- [Certificates and HTTPS](/docs/networking/certificates-https/)
- [OpenSearch](/docs/databases/opensearch/)
- [Retrieval-Augmented Generation](/docs/ml/rag/)
- [ML Serving, Inference, and vLLM](/docs/ml/serving-inference-vllm/)
