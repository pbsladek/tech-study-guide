---
title: Firewalls, iptables, and Netfilter
layout: page
permalink: /docs/networking/firewalls-iptables-netfilter/
summary: "Linux firewall fundamentals: netfilter hooks, nftables, iptables, chains, tables, conntrack, NAT, rule ordering, logging, persistence, and troubleshooting."
tags:
  - networking
  - firewall
  - iptables
  - troubleshooting
---

# Firewalls, iptables, and Netfilter

A firewall is policy in the packet path. On Linux, that policy usually uses netfilter in the kernel, with nftables or iptables as user-facing tools. Operators need to understand hooks, chains, rule order, connection tracking, NAT, and the difference between local host traffic and forwarded traffic.

## Command Examples

```bash
nft list ruleset
iptables-save
ip6tables-save
conntrack -S
conntrack -L | head
journalctl -k -g 'DROP|REJECT|nft|iptables|conntrack'
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `nft list ruleset` | `Rules, chains, counters, verdicts, and NAT transforms.` | Shows active packet policy in the kernel. |
| `iptables-save` | `Rules, chains, counters, verdicts, and NAT transforms.` | Shows active packet policy in the kernel. |
| `ip6tables-save` | `Tables, chains, matches, counters, and ACCEPT/DROP rules.` | Shows firewall policy as loaded in the packet filter. |

Run these before changing policy. The active ruleset, counters, conntrack state, and kernel logs are the evidence.

## Netfilter Packet Path

Netfilter hooks sit at key points in the Linux network stack.

| Hook | Common Use |
| --- | --- |
| `prerouting` | See packets before routing decision; common for DNAT and early marking. |
| `input` | Filter packets destined for the local host. |
| `forward` | Filter packets routed through the host. |
| `output` | Filter locally generated packets. |
| `postrouting` | See packets after routing decision; common for SNAT and masquerade. |

The most common debugging mistake is checking `INPUT` for traffic that is actually being forwarded, or checking `FORWARD` for traffic destined to a local service.

## nftables and iptables

`iptables` is the older command family. `nftables` is the newer framework and userspace tool. Many modern distributions run iptables compatibility commands over the nftables backend, so `iptables-save` may not mean the host is using the old kernel implementation.

Useful distinctions:

| Tool | Operational Note |
| --- | --- |
| `nft list ruleset` | Shows nftables tables, chains, rules, counters, sets, and maps. |
| `iptables-save` | Dumps legacy-style IPv4 rules or compatibility rules. |
| `ip6tables-save` | Dumps legacy-style IPv6 rules or compatibility rules. |
| `ufw` | Ubuntu-friendly frontend that writes lower-level firewall rules. |
| `firewalld` | Zone/service-oriented frontend common on Red Hat-family systems. |

Do not mix frontends casually. If UFW, firewalld, Kubernetes, Docker, and manual rules all write policy, rule ownership becomes part of the incident.

## Tables, Chains, and Rule Order

In iptables, tables group rule types:

| Table | Purpose |
| --- | --- |
| `filter` | Packet filtering decisions such as ACCEPT, DROP, REJECT. |
| `nat` | Address and port translation, generally for new flows. |
| `mangle` | Packet marks and header changes. |
| `raw` | Early handling before conntrack for special cases. |
| `security` | Security labeling integration. |

Rules are evaluated in order. A broad accept rule before a narrow drop rule makes the drop rule irrelevant. A default DROP policy requires explicit allows for return traffic, DNS, ICMP, management access, and health checks.

## Conntrack and Stateful Policy

Connection tracking records flow state so rules can allow return traffic without writing mirror-image rules for every service.

Common states:

| State | Meaning |
| --- | --- |
| `NEW` | First packet of a flow or a packet starting a tracked flow. |
| `ESTABLISHED` | Packet belongs to a known bidirectional flow. |
| `RELATED` | Packet is related to an existing flow, such as some ICMP errors or helper-managed protocols. |
| `INVALID` | Packet cannot be associated with a valid tracked flow. |

Conntrack is also fundamental to NAT. A full conntrack table can make new connections fail while existing ones keep working.

```bash
sysctl net.netfilter.nf_conntrack_max
cat /proc/sys/net/netfilter/nf_conntrack_count
conntrack -S
conntrack -L -p tcp | head
```

## DROP, REJECT, Logging, and Counters

`DROP` silently discards packets. `REJECT` discards and sends an error when possible. For public internet noise, DROP is common. For internal troubleshooting, REJECT can make failures faster and clearer.

Logging every denied packet can create a production problem. Prefer rate-limited logging and rule counters:

```bash
nft list ruleset -a
iptables -L -n -v
iptables -t nat -L -n -v
```

Counters are only useful when you know which path the packet should take. Generate one test flow, then check whether the expected rule counter changed.

## Host Firewall Example

This nftables host policy allows established traffic, loopback, SSH from a management subnet, HTTPS from anywhere, and ICMP for diagnostics. It logs denied input at a limited rate before rejecting.

```nft
table inet host_filter {
  chain input {
    type filter hook input priority 0; policy drop;

    iif lo accept
    ct state established,related accept
    ct state invalid drop

    ip saddr 192.0.2.0/24 tcp dport 22 accept
    tcp dport 443 accept
    ip protocol icmp accept
    ip6 nexthdr ipv6-icmp accept

    limit rate 5/second log prefix "nft-drop-input: "
    reject
  }
}
```

Test firewall changes from an existing session and with out-of-band access available. A syntactically valid rule can still lock out SSH if the source range, interface, or default policy is wrong.

## NAT and Firewalls Together

DNAT and SNAT change what later checks see. A packet may arrive for a public address, be DNATed to a private backend, then hit a filter rule using the translated destination. Return packets may be SNATed or masqueraded after routing.

Operational implications:

- capture before and after NAT boundaries when possible,
- know whether policy matches original or translated addresses,
- account for hairpin NAT when clients reach a public IP from inside,
- keep return traffic through the same stateful device unless the design supports asymmetry,
- remember IPv6 often needs firewalling without NAT.

## Troubleshooting Flow

1. Identify whether traffic is local input, local output, or forwarded.
2. Confirm the route and interface before reading firewall rules.
3. Dump active nftables and iptables views.
4. Check conntrack state and table pressure.
5. Generate one test flow and inspect rule counters.
6. Capture packets at ingress, post-NAT, and egress boundaries when possible.
7. Check whether a frontend such as UFW, firewalld, Docker, or Kubernetes owns the rule.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the difference between INPUT and FORWARD?" answer="INPUT handles packets destined for the local host; FORWARD handles packets routed through the host." %}
  {% include study-card.html question="Why does rule order matter?" answer="Rules are evaluated in order, so an earlier broad match can prevent later specific rules from ever applying." %}
  {% include study-card.html question="What does conntrack enable?" answer="Stateful firewall policy and NAT by associating packets with tracked flows." %}
  {% include study-card.html question="Why can mixing firewall frontends be risky?" answer="UFW, firewalld, Docker, Kubernetes, and manual rules can all write policy, making ownership and ordering unclear." %}
  {% include study-card.html question="Why keep ICMP in a firewall policy?" answer="ICMP carries diagnostics and path information such as unreachable and Packet Too Big messages that help MTU and routing work." %}
</div>

## References

- [netfilter/iptables documentation](https://www.iptables.org/documentation/)
- [nftables project documentation](https://www.iptables.org/projects/nftables/index.html)
- [nftables connection tracking](https://wiki.nftables.org/wiki-nftables/index.php/Connection_Tracking_System)
- [nftables netfilter hooks](https://wiki.nftables.org/wiki-nftables/index.php/Netfilter_hooks)
- [iptables(8)](https://man7.org/linux/man-pages/man8/iptables.8.html)
- [nft(8)](https://man7.org/linux/man-pages/man8/nft.8.html)
