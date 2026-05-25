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
nslookup example.com
nslookup -type=SRV _ldap._tcp.dc._msdcs.example.com
nslookup -debug example.com
nslookup -vc example.com
```

A typical Linux application calls `getaddrinfo()`. That request may pass through `/etc/hosts`, NSS modules, systemd-resolved, a local caching daemon, a corporate resolver, or a Kubernetes DNS service before any recursive lookup happens.

## Stub, Recursive, and Authoritative Roles

DNS debugging gets easier when each actor has one job:

| Actor | Job | Common Evidence |
| --- | --- | --- |
| Application resolver code | Calls libc, runtime DNS cache, or its own resolver. | App logs, runtime settings, connection pools. |
| Stub resolver | Reads local resolver config and sends queries to a configured resolver. | `/etc/resolv.conf`, NSS config, systemd-resolved state. |
| Recursive resolver | Walks or answers from cache on behalf of clients. | Cache behavior, DNSSEC validation, split-horizon policy. |
| Authoritative server | Serves zone data for names it is responsible for. | SOA, NS, authoritative answer bit, provider zone records. |

`dig @resolver name type` tests one recursive resolver. `dig @authoritative name type +norecurse` tests zone truth. `dig +trace` shows delegation, but it does not exactly reproduce every enterprise resolver policy, DNSSEC validation choice, or split-horizon view.

## Cache Layers

| Layer | What It May Cache |
| --- | --- |
| Application | HTTP client connection pools, DNS cache inside runtimes, JVM resolver cache, browser cache. |
| OS / local resolver | Stub resolver state, systemd-resolved cache, nscd, dnsmasq. |
| Recursive resolver | Positive answers, CNAME chains, NS data, glue, negative answers. |
| Authoritative infrastructure | Zone data, provider-side generated records, load-balancer answers. |

When debugging, ask the same resolver the application uses before comparing public resolvers.

## Resolver Selection on Linux

Name lookup may not be DNS-only. `/etc/nsswitch.conf` controls the order for `hosts`, commonly including `files`, `dns`, `resolve`, or `myhostname`. That means `/etc/hosts`, systemd-resolved, mDNS, LDAP, or another NSS module can answer before normal DNS.

Useful checks:

```bash
getent hosts example.com
cat /etc/nsswitch.conf
readlink -f /etc/resolv.conf
resolvectl status
resolvectl query example.com
nslookup example.com
nslookup example.com "$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)"
```

`dig` bypasses part of the libc/NSS path and is excellent for DNS protocol testing. `getent hosts` is better for testing what many Linux applications see through libc.

`nslookup` is also a DNS protocol client, not proof of the full Linux application lookup path. It is useful because it is widely available on workstations, jump hosts, Windows machines, and minimal debug containers, but it should be paired with `getent` when the question is "what will this Linux application resolve?"

## nslookup Deep Dive

Use explicit query types and explicit resolvers. That keeps output comparable across implementations and avoids guessing whether the tool chose A, AAAA, or both.

```bash
nslookup example.com
nslookup -type=A example.com
nslookup -type=AAAA example.com
nslookup -type=MX example.com
nslookup -type=NS example.com
nslookup -type=SOA example.com
nslookup -type=TXT example.com
nslookup -type=SRV _ldap._tcp.dc._msdcs.example.com
nslookup example.com 1.1.1.1
nslookup -debug example.com
nslookup -timeout=2 -retry=1 example.com
nslookup -vc example.com
```

Useful interactive mode:

```text
nslookup
> server 10.0.0.53
> set type=A
> api.example.com
> set type=AAAA
> api.example.com
> set debug
> api.example.com
> set vc
> api.example.com
```

`server` changes the resolver under test. `set type=` changes the record type. `set debug` prints more protocol detail. `set vc` uses TCP instead of UDP in BIND-style `nslookup` implementations, which helps test truncation, UDP filtering, and TCP fallback behavior.

## nslookup Output Interpretation

| Output | What It Usually Means | Next Check |
| --- | --- | --- |
| `Server:` points at `127.0.0.53` | Query went to systemd-resolved local stub, not directly to upstream DNS. | `resolvectl status`, query the upstream resolver explicitly. |
| `Non-authoritative answer` | A recursive resolver answered from cache or recursion, not as zone authority. | Query authoritative NS with `nslookup name ns1.example.com` or use `dig +norecurse`. |
| `NXDOMAIN` | Queried name does not exist in that resolver view, or a negative answer is cached. | Check authoritative server, spelling, search suffix, and negative TTL. |
| `No answer` / no records | Name may exist but not for that type, such as AAAA missing while A exists. | Query SOA/NS and alternate record types. |
| `SERVFAIL` | Resolver failed to complete lookup, often DNSSEC, upstream, forwarding, loop, or timeout. | Compare another resolver, check DNSSEC validation, CoreDNS or recursive logs. |
| `REFUSED` | Server policy refused recursion or this client. | Confirm resolver ACLs, recursion settings, view policy. |
| `connection timed out; no servers could be reached` | Resolver IP is unreachable, blocked, overloaded, or not listening on UDP/TCP 53. | `ip route get`, firewall, packet capture, `nslookup -vc`, resolver health. |
| A works but AAAA fails | IPv4 and IPv6 data or resolver policy differ. | Test dual-stack client behavior and Happy Eyeballs path. |

Avoid over-reading `Non-authoritative answer`; it is normal when asking a recursive resolver for ordinary cached data.

## nslookup Troubleshooting Workflows

Resolver comparison:

```bash
date -Is
nslookup -type=A api.example.com
nslookup -type=A api.example.com 10.0.0.53
nslookup -type=A api.example.com 1.1.1.1
nslookup -type=A api.example.com ns1.example.com
```

This separates local resolver behavior, corporate or cluster recursive behavior, public recursive behavior, and authoritative data. If the authoritative server has the expected answer but a recursive resolver does not, look at TTL, negative caching, forwarding policy, DNSSEC validation, or split-horizon view.

Search-domain and short-name checks:

```bash
nslookup api
nslookup api.default.svc.cluster.local
nslookup api.example.com.
getent hosts api
getent hosts api.example.com
```

`nslookup api.example.com.` tests the fully qualified name with a trailing dot. `getent` is still needed because application lookup may expand names through NSS and search domains differently from `nslookup`.

Kubernetes Pod DNS checks:

```bash
kubectl exec -it <pod> -- cat /etc/resolv.conf
kubectl exec -it <pod> -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -it <pod> -- nslookup -type=A <service>.<namespace>.svc.cluster.local
kubectl exec -it <pod> -- nslookup -type=SRV _http._tcp.<service>.<namespace>.svc.cluster.local
kubectl exec -it <pod> -- nslookup -timeout=2 -retry=1 example.com
```

If Pod `nslookup` fails while node `nslookup` works, compare Pod resolver config, NetworkPolicy egress to UDP/TCP 53, CoreDNS endpoints, NodeLocal DNSCache, CNI routing, and CoreDNS logs. A successful Service DNS answer does not prove the Service has ready endpoints.

UDP versus TCP:

```bash
nslookup -debug -type=DNSKEY example.com
nslookup -vc -type=DNSKEY example.com
dig +notcp example.com DNSKEY
dig +tcp example.com DNSKEY
```

If TCP works and UDP fails, suspect truncation handling, fragmented UDP, MTU, firewall state, NAT, conntrack, or resolver UDP rate limiting. DNSSEC and large TXT responses are common ways to expose the difference.

## nslookup Limits and Gotchas

- `nslookup` does not prove `/etc/hosts`, NSS module order, or application runtime caches.
- Output format and option support vary between BIND, BusyBox, Windows, and appliance implementations.
- It often hides details that `dig` shows clearly, such as flags, authority sections, EDNS behavior, and exact TTLs.
- Querying a public resolver can bypass corporate, split-horizon, Kubernetes, or VPN DNS views.
- A recursive resolver answer can be stale by design until TTL or negative TTL expires.
- Some environments block direct DNS to the internet; test the resolver path applications actually use.

## Delegation and Bailiwick

Recursive resolvers follow delegation from the root toward the target zone. Parent zones publish NS records for delegated child zones, and may publish glue address records when the child's nameserver name is inside the delegated child.

Bailiwick rules limit which additional records a resolver should trust from a response. This matters because DNS responses can include extra data. A resolver should not blindly trust unrelated additional records just because they arrived with an answer.

Operational implications:

- stale parent NS records can send resolvers to old authoritative servers,
- missing glue can break nameserver reachability,
- changing authoritative providers requires updating registrar/delegation data, not only zone records,
- split-horizon DNS can make the same name resolve differently depending on resolver view.

## TTL and Negative Answers

TTL controls how long a resolver may reuse an answer. Lowering a TTL after the old value is already cached does not flush remote caches. Negative answers such as NXDOMAIN and NODATA can also be cached, usually based on SOA-derived timing.

Important implications:

- create records before clients query them if possible,
- lower TTLs before planned migrations,
- distinguish authoritative truth from recursive cache,
- remember CNAME targets have their own TTLs.

## Search Domains and ndots

Client search behavior can multiply lookups. A Pod looking up `api.example.com` with high `ndots` may try cluster-local suffixes before the absolute name. A trailing dot, as in `api.example.com.`, bypasses search suffix expansion.

## Intermittent DNS Runbook

Intermittent DNS failures usually come from cache scope, negative answers, resolver health, UDP loss, TCP fallback, split-horizon policy, or application-level caching.

```bash
date -Is
getent hosts api.example.com
dig api.example.com A +tries=1 +time=2
dig api.example.com AAAA +tries=1 +time=2
dig +tcp api.example.com A
dig @<configured-resolver> api.example.com A
resolvectl query api.example.com
tcpdump -nn -i any 'port 53'
```

Interpretation:

| Observation | Likely Meaning |
| --- | --- |
| `getent` differs from `dig` | NSS, `/etc/hosts`, systemd-resolved, or application resolver path differs from raw DNS. |
| UDP fails but `dig +tcp` works | Fragmentation, MTU, firewall, conntrack, or resolver UDP handling issue. |
| Some clients get NXDOMAIN | Negative cache, split-horizon view, stale recursive resolver, or wrong search expansion. |
| Fully qualified name works but short name fails | Search domains, namespace, `ndots`, or resolver suffix order. |

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
  {% include study-card.html question="Why use getent hosts when debugging Linux DNS?" answer="It follows the libc/NSS lookup path many applications use, including files and resolver modules." %}
  {% include study-card.html question="What is glue in DNS?" answer="Address records provided by a parent zone so resolvers can reach delegated child nameservers." %}
  {% include study-card.html question="Why compare UDP DNS with TCP DNS?" answer="Large answers, truncation, MTU, or firewall behavior can make UDP fail while TCP succeeds." %}
  {% include study-card.html question="Why use explicit record types with nslookup?" answer="It avoids ambiguity about whether the tool queried A, AAAA, MX, SRV, or another type." %}
  {% include study-card.html question="What does nslookup server 10.0.0.53 change?" answer="It points interactive nslookup queries at that resolver so you can compare resolver views." %}
  {% include study-card.html question="Why is nslookup not enough to prove Linux application DNS behavior?" answer="It tests DNS query behavior, while applications may use NSS, /etc/hosts, caches, search domains, or runtime resolver logic." %}
</div>

## References

- [RFC 1034: Domain Names - Concepts and Facilities](https://www.rfc-editor.org/rfc/rfc1034)
- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 2308: Negative Caching of DNS Queries](https://www.rfc-editor.org/rfc/rfc2308)
- [resolv.conf(5)](https://man7.org/linux/man-pages/man5/resolv.conf.5.html)
- [BIND 9 manual pages: nslookup](https://bind9.readthedocs.io/en/v9.20.23/manpages.html#nslookup-query-internet-name-servers-interactively)
