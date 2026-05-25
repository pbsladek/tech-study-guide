---
title: DNS Examples
layout: page
permalink: /docs/dns/practical-examples/
summary: "Practical examples for DNS zones and resolver debugging."
tags:
  - examples
  - dns
---

# DNS Examples

These examples complement [DNS](/docs/dns/), [resolution and caching](/docs/dns/resolution-caching/), [authoritative zones](/docs/dns/authoritative-zones/), and [DNS records, responses, and transport](/docs/dns/records-transport-operations/).

## DNS Zone Example

A minimal authoritative zone shape showing SOA, NS, glue-adjacent host records, web records, mail records, and a service record:

```zone
$ORIGIN example.com.
$TTL 300
@ IN SOA ns1.example.com. dns-admin.example.com. (
  2026052301 ; serial
  3600       ; refresh
  600        ; retry
  1209600    ; expire
  300        ; negative cache TTL
)

@    IN NS ns1.example.com.
@    IN NS ns2.example.com.
ns1  IN A  203.0.113.10
ns2  IN A  203.0.113.11

@    IN A     203.0.113.20
www  IN CNAME example.com.
api  IN A     203.0.113.30

@    IN MX 10 mail.example.com.
mail IN A     203.0.113.40

_nats._tcp.cluster IN SRV 10 10 6222 nats-0.nats-headless.svc.example.com.
```

Resolver debugging comparison:

```bash
getent hosts api.example.com
dig @127.0.0.53 api.example.com A
dig @1.1.1.1 api.example.com A
dig @ns1.example.com api.example.com A +norecurse
dig +trace api.example.com
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why include SOA and NS records in a DNS zone example?" answer="They show the zone authority, serial policy, and authoritative nameservers." %}
  {% include study-card.html question="Why compare resolver answers from multiple servers?" answer="It separates local cache or stub resolver behavior from authoritative and public recursive resolver behavior." %}
  {% include study-card.html question="Why use +norecurse against an authoritative server?" answer="It verifies the zone data served by that authority without asking it to recurse elsewhere." %}
</div>

## References

- [DNS Records, Responses, and Transport](/docs/dns/records-transport-operations/)
