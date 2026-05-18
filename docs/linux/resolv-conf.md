---
title: resolv.conf
layout: page
permalink: /docs/linux/resolv-conf/
summary: "Linux resolver configuration, nameservers, search domains, ndots, timeouts, attempts, rotation, and systemd-resolved behavior."
tags:
  - linux
  - dns
  - resolv-conf
  - troubleshooting
---

# resolv.conf

`/etc/resolv.conf` configures the traditional libc stub resolver used by many Linux programs. It tells local processes which recursive resolver to ask, which search suffixes to try, and how aggressive retry behavior should be.

## File Shape

```text
nameserver 127.0.0.53
search corp.example.com svc.cluster.local cluster.local
options ndots:2 timeout:2 attempts:3 rotate
```

| Directive | Meaning |
| --- | --- |
| `nameserver` | Resolver IP address to query. Up to three are commonly honored by libc resolver behavior. |
| `search` | Suffix list tried for relative names. |
| `domain` | Older single-domain form; do not use with `search` for modern configs. |
| `options` | Resolver behavior such as `ndots`, `timeout`, `attempts`, `rotate`, `single-request`, and `no-aaaa`. |

## Search and ndots

`ndots:n` controls when a name is tried as absolute before applying search suffixes. If the name has fewer dots than `n`, search suffixes are tried first.

This matters in Kubernetes. Pods often have a high `ndots` value so short service names resolve inside cluster search domains, but that can create extra failed queries for external names.

Examples:

- `api` with search `default.svc.cluster.local svc.cluster.local` tries service-like names first.
- `example.com` with `ndots:5` may still be treated as relative before being tried as absolute.
- `example.com.` with a trailing dot is absolute.

## Timeouts and Attempts

`timeout:n` controls how long the resolver waits for a response before retrying. `attempts:n` controls how many tries are made before giving up. Large values can turn DNS loss into long application latency.

## Rotation

Without `rotate`, many resolver implementations prefer the first nameserver and only try later servers after failures. `rotate` spreads queries across configured nameservers, but it is not a health-checking load balancer.

## systemd-resolved

Many distributions point `/etc/resolv.conf` at a local stub such as `127.0.0.53` managed by `systemd-resolved`. In that setup, the real upstream DNS servers may be visible through `resolvectl status`, not by reading `/etc/resolv.conf` alone.

```bash
readlink -f /etc/resolv.conf
cat /etc/resolv.conf
resolvectl status
resolvectl query example.com
journalctl -u systemd-resolved -b
```

## Troubleshooting Runbook

1. Confirm which resolver file is actually in use: symlink, container mount, NetworkManager, or systemd-resolved.
2. Query with the application name and with a trailing dot.
3. Compare libc behavior to direct resolver queries with `dig`.
4. Inspect search suffix expansion and `ndots`.
5. Check whether the nameserver is reachable over UDP and TCP 53.
6. In Kubernetes, compare Pod `/etc/resolv.conf`, CoreDNS health, and NodeLocal DNSCache if present.

```bash
cat /etc/resolv.conf
getent hosts example.com
getent hosts example.com.
dig example.com
dig example.com. @$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
resolvectl query example.com
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does nameserver mean in resolv.conf?" answer="It names a recursive resolver IP address that the local stub resolver can query." %}
  {% include study-card.html question="What does search do?" answer="It defines suffixes tried for relative names before or after the absolute name depending on ndots." %}
  {% include study-card.html question="What does ndots change?" answer="It changes whether names with fewer dots are expanded through search domains before being queried as absolute names." %}
  {% include study-card.html question="Why can DNS failures cause slow application startup?" answer="High timeout, attempts, ndots, and search-list expansion can multiply failed queries before the resolver gives up." %}
  {% include study-card.html question="Why might resolv.conf only show 127.0.0.53?" answer="The host may use systemd-resolved as a local stub resolver, with upstream DNS visible through resolvectl." %}
</div>

## References

- [resolv.conf(5) Linux manual page](https://man7.org/linux/man-pages/man5/resolv.conf.5.html)
- [systemd-resolved documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html)
- [resolved.conf documentation](https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html)
