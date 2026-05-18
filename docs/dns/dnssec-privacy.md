---
title: DNSSEC and DNS Privacy
layout: page
permalink: /docs/dns/dnssec-privacy/
summary: "DNSSEC validation, chain of trust, DS/DNSKEY, signing failures, DNS over TLS, DNS over HTTPS, and what privacy does not solve."
tags:
  - dns
  - dnssec
  - privacy
---

# DNSSEC and DNS Privacy

DNSSEC and encrypted DNS solve different problems. DNSSEC signs DNS data so a validating resolver can detect tampering. DNS over TLS and DNS over HTTPS encrypt transport between the client and resolver, but they do not prove the data is correct unless validation also happens.

## Validation Checks

```bash
dig +dnssec example.com
dig DS example.com
dig DNSKEY example.com
delv example.com
resolvectl query example.com
```

## DNSSEC Chain

| Record | Role |
| --- | --- |
| DNSKEY | Public keys for a signed zone. |
| DS | Parent-zone digest that points to the child zone key. |
| RRSIG | Signature over a DNS record set. |
| NSEC / NSEC3 | Authenticated denial of existence. |

The chain of trust normally runs root -> TLD -> domain -> signed answer. A DS mismatch at the parent can break a domain even when authoritative servers still return records.

## Common DNSSEC Failures

- expired RRSIG records,
- parent DS does not match child DNSKEY,
- signing provider changed but registrar DS was not updated,
- clocks wrong on validators or signers,
- large DNSSEC responses blocked by network paths,
- one authoritative nameserver serving stale signed data.

## DNS Privacy

Encrypted DNS protects the path between client and resolver from passive observation or modification. It does not hide the destination from the resolver, does not validate unsigned zones, and does not make corporate or Kubernetes split-horizon DNS automatically work.

## Operational Model

1. Decide where validation happens: local host, recursive resolver, or both.
2. Treat DS updates as part of DNS provider migrations.
3. Monitor signature expiry and validation failures.
4. Test with validating and non-validating resolvers.
5. Separate transport privacy failures from DNSSEC validation failures.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Does DNSSEC encrypt DNS queries?" answer="No. DNSSEC validates DNS data; DNS over TLS or HTTPS encrypts resolver transport." %}
  {% include study-card.html question="What does a DS record connect?" answer="It connects a parent zone delegation to the child zone's DNSSEC key material." %}
  {% include study-card.html question="Why can only validating resolvers fail?" answer="They reject answers when the DNSSEC chain, signatures, or denial-of-existence proofs are invalid." %}
</div>

## References

- [RFC 4033: DNS Security Introduction and Requirements](https://www.rfc-editor.org/rfc/rfc4033)
- [RFC 4034: Resource Records for DNS Security Extensions](https://www.rfc-editor.org/rfc/rfc4034)
- [RFC 4035: Protocol Modifications for DNS Security Extensions](https://www.rfc-editor.org/rfc/rfc4035)
- [RFC 7858: DNS over TLS](https://www.rfc-editor.org/rfc/rfc7858)
- [RFC 8484: DNS over HTTPS](https://www.rfc-editor.org/rfc/rfc8484)
