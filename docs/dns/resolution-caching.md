---
title: DNS Resolution and Caching
layout: page
permalink: /docs/dns/resolution-caching/
summary: "How resolver lookup paths, caches, TTLs, negative answers, CNAME chains, and client search behavior shape DNS outcomes."
tags:
  - dns
  - caching
  - troubleshooting
---

# DNS Resolution and Caching

DNS incidents often look random because the answer depends on where the query starts, which resolver cache is warm, how the client expands names, and whether a previous negative answer was cached. Understanding the resolver path is essential for debugging the full stack from application code to service discovery.

## Lookup Path

```bash
getent hosts example.com
dig example.com A
dig example.com AAAA
dig +trace example.com
dig @1.1.1.1 example.com
```

A typical Linux application calls `getaddrinfo()`. That request may pass through `/etc/hosts`, NSS modules, systemd-resolved, a local caching daemon, a corporate resolver, or a Kubernetes DNS service before any recursive lookup happens.

## Cache Layers

| Layer | What It May Cache |
| --- | --- |
| Application | HTTP client connection pools, DNS cache inside runtimes, JVM resolver cache, browser cache. |
| OS / local resolver | Stub resolver state, systemd-resolved cache, nscd, dnsmasq. |
| Recursive resolver | Positive answers, CNAME chains, NS data, glue, negative answers. |
| Authoritative infrastructure | Zone data, provider-side generated records, load-balancer answers. |

When debugging, ask the same resolver the application uses before comparing public resolvers.

## TTL and Negative Answers

TTL controls how long a resolver may reuse an answer. Lowering a TTL after the old value is already cached does not flush remote caches. Negative answers such as NXDOMAIN and NODATA can also be cached, usually based on SOA-derived timing.

Important implications:

- create records before clients query them if possible,
- lower TTLs before planned migrations,
- distinguish authoritative truth from recursive cache,
- remember CNAME targets have their own TTLs.

## Search Domains and ndots

Client search behavior can multiply lookups. A Pod looking up `api.example.com` with high `ndots` may try cluster-local suffixes before the absolute name. A trailing dot, as in `api.example.com.`, bypasses search suffix expansion.

## Debugging Flow

1. Capture the exact queried name from the application or logs.
2. Inspect the client resolver config and NSS order.
3. Query through the application resolver.
4. Query the configured recursive resolver directly.
5. Query authoritative servers directly.
6. Compare A and AAAA behavior.
7. Check CNAME chain TTLs and negative cache possibilities.
8. Re-test with a trailing dot to avoid search-path expansion.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why can DNS answers differ between two machines?" answer="They may use different resolver paths, caches, search lists, split-horizon views, or validation policies." %}
  {% include study-card.html question="What does a TTL actually control?" answer="How long a resolver may reuse a cached answer before it should refresh it." %}
  {% include study-card.html question="Why can creating a record after a failed lookup still appear broken?" answer="A recursive resolver may have cached the previous negative answer." %}
</div>

## References

- [RFC 1034: Domain Names - Concepts and Facilities](https://www.rfc-editor.org/rfc/rfc1034)
- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 2308: Negative Caching of DNS Queries](https://www.rfc-editor.org/rfc/rfc2308)
- [resolv.conf(5)](https://man7.org/linux/man-pages/man5/resolv.conf.5.html)
