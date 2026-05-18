---
title: Authoritative DNS and Zones
layout: page
permalink: /docs/dns/authoritative-zones/
summary: "Zones, delegations, NS records, SOA serials, glue, apex constraints, wildcard behavior, and authoritative debugging."
tags:
  - dns
  - authoritative-dns
  - zones
---

# Authoritative DNS and Zones

Authoritative DNS is the source of truth for a zone. Recursive resolvers cache and relay answers, but authoritative nameservers define what exists inside the delegated namespace.

## Authoritative Checks

```bash
dig NS example.com
dig SOA example.com
dig @ns1.example.com example.com SOA
dig @ns1.example.com www.example.com A +norecurse
dig +trace www.example.com
```

## Zone Model

| Concept | Meaning |
| --- | --- |
| Domain | A node and its descendants in the DNS namespace. |
| Zone | The portion of the namespace administered as one unit. |
| Delegation | A parent zone points a child zone to its authoritative nameservers. |
| SOA | Start of authority record containing zone metadata and serial. |
| NS | Nameserver records identifying authoritative servers for the zone. |
| Glue | Address records in the parent zone for in-bailiwick nameservers. |

`example.com` can be a domain and a zone. `dev.example.com` can be delegated as its own zone, or it can remain ordinary names inside the parent zone.

## Apex Constraints

The zone apex must have SOA and NS records. A standard CNAME cannot coexist with those records, which is why apex aliases usually require provider-specific flattening records such as ALIAS or ANAME.

## SOA Serial and Drift

Authoritative nameservers should serve the same zone data. If one server has an older SOA serial, recursive resolvers can get inconsistent answers depending on which authoritative server they ask.

## Wildcards

Wildcard records synthesize answers for names that do not otherwise exist, but they do not override existing names. They can make debugging harder because typos may return valid-looking answers instead of NXDOMAIN.

## Debugging Flow

1. Use `dig +trace` to confirm the delegation path.
2. Query every authoritative nameserver directly.
3. Compare SOA serials across authoritative servers.
4. Check parent NS records and child apex NS records.
5. Confirm glue exists when nameservers are in-bailiwick.
6. Check whether wildcard records are hiding missing explicit names.
7. Avoid recursive resolver output until authoritative data is known.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is a DNS zone?" answer="A delegated or administered portion of the DNS namespace served by authoritative nameservers." %}
  {% include study-card.html question="Why compare SOA serials?" answer="Different serials across authoritative servers indicate zone data drift." %}
  {% include study-card.html question="Why does an in-bailiwick nameserver need glue?" answer="The parent must provide address records so resolvers can reach the child zone's nameserver." %}
</div>

## References

- [RFC 1034: Domain Names - Concepts and Facilities](https://www.rfc-editor.org/rfc/rfc1034)
- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 4592: The Role of Wildcards in the DNS](https://www.rfc-editor.org/rfc/rfc4592)
