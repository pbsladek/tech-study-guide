---
title: DNS
layout: page
permalink: /docs/dns/
summary: Name resolution flow, DNS records, delegation, caching, negative answers, and operational debugging.
tags:
  - dns
  - networking
  - troubleshooting
---

# DNS

DNS is a distributed, cached database for names. The protocol looks simple until caching, delegation, CNAME chains, split-horizon zones, DNSSEC, search paths, and resolver behavior interact. Ops people need to understand the full path from application lookup to authoritative answer.

## The Actors

| Actor | Role |
| --- | --- |
| Stub resolver | Library or local resolver on the client host. It asks a recursive resolver. |
| Recursive resolver | Does the work of chasing the answer and caching results. |
| Root servers | Refer resolvers to TLD servers such as `.com` or `.org`. |
| TLD servers | Refer resolvers to authoritative nameservers for a registered domain. |
| Authoritative nameserver | Serves records for a zone. This is where the truth for that zone lives. |

Most clients do not talk to root or authoritative servers directly. They ask a recursive resolver, often from DHCP, systemd-resolved, a corporate DNS service, or a public resolver.

## Critical Subtopics

| Topic | Why It Matters |
| --- | --- |
| [Resolution and Caching](resolution-caching/) | Explains resolver paths, local caches, recursive caches, TTLs, negative answers, search domains, and `ndots`. |
| [Authoritative DNS and Zones](authoritative-zones/) | Explains source-of-truth zone data, delegation, NS/SOA records, glue, apex constraints, and wildcard behavior. |
| [DNSSEC and DNS Privacy](dnssec-privacy/) | Separates signed-data validation from encrypted resolver transport and covers common validation failures. |

## Walkthrough: Resolving `www.example.com`

1. The application calls resolver APIs such as `getaddrinfo`.
2. The OS checks local sources: hosts file, local cache, resolver daemon, and configured name service order.
3. The stub resolver asks its configured recursive resolver for A and/or AAAA records.
4. If not cached, the recursive resolver asks a root server where to find `.com`.
5. The root server returns a referral to `.com` TLD nameservers.
6. The resolver asks a `.com` server where to find `example.com`.
7. The TLD server returns the domain's authoritative NS records, often with glue A/AAAA records when needed.
8. The resolver asks an authoritative server for `www.example.com`.
9. The authoritative server returns an answer, CNAME, NXDOMAIN, NODATA, or referral.
10. The recursive resolver caches the result for the TTL and returns it to the client.

DNS "propagation" is usually cache expiration. There is no global push of new records to every resolver.

## Records Operators Should Know

| Record | Purpose | Gotcha |
| --- | --- | --- |
| A / AAAA | Name to IPv4 / IPv6 address. | Dual-stack clients may prefer IPv6 if AAAA works badly. |
| CNAME | Alias to another canonical name. | A CNAME cannot coexist with most other records at the same owner name. |
| NS | Delegates a zone to nameservers. | Parent and child NS sets can drift. |
| SOA | Zone metadata and negative-cache TTL source. | The SOA matters for NXDOMAIN/NODATA caching. |
| MX | Mail exchanger. | Points to names, not raw IPs. |
| TXT | Arbitrary text, often verification and SPF. | Quoting and splitting can surprise automation. |
| SRV | Service discovery with priority, weight, port, target. | Target is a hostname. |
| PTR | Reverse DNS. | Lives under `in-addr.arpa` or `ip6.arpa`, delegated separately. |
| CAA | Restricts which CAs may issue certificates. | Misconfiguration can block certificate issuance. |

## TTL and Caching

TTL is how long a resolver may cache a record. Lowering a TTL after clients have already cached the old higher TTL does not make those clients forget early. Lower TTL before a planned migration, wait out the old TTL, then change the record.

Negative answers are cached too. RFC 2308 defines negative caching behavior. If you query a name before it exists, recursive resolvers can cache that negative result, so creating the record afterward may still appear broken until the negative TTL expires.

## CNAME Chains

CNAMEs are common for SaaS, CDNs, and cloud load balancers. Each link in a chain can have a separate TTL and failure mode. A query for A records can return a CNAME and then require more lookups to reach final A/AAAA records.

Operational advice:

- Keep chains short.
- Avoid CNAMEs at zone apex unless your provider implements flattening or ALIAS-style behavior.
- Remember that the authoritative server for the original name and the target name may be different.

## Delegation and Glue

Delegation happens at a zone boundary. The parent publishes NS records for the child zone. If a nameserver is inside the zone it serves, the parent also needs glue address records so resolvers can reach it.

Example: if `example.com` is served by `ns1.example.com`, the `.com` zone needs glue for `ns1.example.com`. Without glue, resolution can become circular.

## Split-Horizon DNS

Split-horizon DNS returns different answers depending on the client, network, or resolver path. It is common for private services and hybrid cloud. It also creates confusion:

- `dig` from a laptop and from a Pod may get different answers.
- Public resolvers may see public data while corporate resolvers see private data.
- Conditional forwarding must be tested from the actual network path that applications use.

## DNSSEC

DNSSEC signs DNS data so validating resolvers can detect tampering. It does not encrypt DNS. Common failure modes are expired signatures, DS/DNSKEY mismatch during migration, and forgetting to update DS records at the registrar.

## Kubernetes DNS Tie-In

Kubernetes Service discovery is DNS-heavy. CoreDNS watches Services and EndpointSlices and serves names such as:

```text
service.namespace.svc.cluster.local
```

If Pods use a search list and `ndots`, a lookup for an external name may first try several cluster-local suffixes. This can add latency and load to CoreDNS.

## Debugging Method

1. Query the same resolver the application uses.
2. Query authoritative servers directly.
3. Check A and AAAA.
4. Check CNAME chains.
5. Check TTLs and negative cache possibilities.
6. Check delegation from the parent.
7. Check DNSSEC validation if only validating resolvers fail.
8. Check search paths and `/etc/resolv.conf` in containers.

## Commands

```bash
dig example.com A
dig example.com AAAA
dig +trace example.com
dig @1.1.1.1 example.com
dig NS example.com
dig SOA example.com
dig +dnssec example.com
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is DNS propagation really?" answer="Usually cache expiration. DNS changes are not pushed globally; recursive resolvers keep cached answers until TTL or policy says otherwise." %}
  {% include study-card.html question="Why can a newly created DNS record still return NXDOMAIN?" answer="A resolver may have cached the earlier negative answer according to negative caching rules." %}
  {% include study-card.html question="What is glue?" answer="Address records published by a parent zone for in-bailiwick nameservers so resolvers can reach the delegated zone." %}
  {% include study-card.html question="Why should you query authoritative servers directly?" answer="It separates authoritative truth from recursive resolver cache, forwarding, DNSSEC, and client search-path behavior." %}
  {% include study-card.html question="Does DNSSEC encrypt DNS queries?" answer="No. DNSSEC signs DNS data for validation; it does not provide query privacy." %}
</div>

## Practice Deck

{% include study-card-deck.html deck="dns" %}

## References

- [RFC 1034: Domain Names - Concepts and Facilities](https://www.rfc-editor.org/rfc/rfc1034)
- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 2308: Negative Caching of DNS Queries](https://www.rfc-editor.org/rfc/rfc2308)
- [RFC 4033: DNS Security Introduction and Requirements](https://www.rfc-editor.org/rfc/rfc4033)
- [Cloudflare: How DNS works](https://www.cloudflare.com/learning/dns/what-is-dns/)
