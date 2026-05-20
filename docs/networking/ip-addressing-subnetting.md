---
title: IP Addressing and Subnetting
layout: page
permalink: /docs/networking/ip-addressing-subnetting/
summary: "IPv4 and IPv6 addressing, CIDR, subnets, default gateways, private address space, source selection, and route troubleshooting."
tags:
  - networking
  - routing
  - troubleshooting
---

# IP Addressing and Subnetting

IP addressing is the shared vocabulary of routing, firewalls, Kubernetes Services, cloud VPCs, VPNs, and load balancers. Operators need to read CIDR notation quickly, identify local versus remote destinations, and understand why the selected source address matters.

## First Checks

```bash
ip addr show
ip route show
ip route get 198.51.100.10
ip -6 route show
ip -6 neigh show
getent ahosts example.com
```

## CIDR and Prefixes

CIDR notation combines an address with a prefix length. The prefix is the network portion. The remaining bits identify hosts or interfaces inside that network.

Examples:

| CIDR | Meaning |
| --- | --- |
| `10.0.0.0/8` | Large private IPv4 block. |
| `10.20.30.0/24` | 256 IPv4 addresses, commonly 254 usable host addresses. |
| `192.0.2.10/32` | One IPv4 host route. |
| `2001:db8::/32` | Documentation IPv6 prefix. |
| `2001:db8:10::/64` | Common IPv6 subnet size for one link. |

Longest-prefix match wins. A `/32` host route beats a `/24`, which beats a `/16`, which beats a default route.

## Local Versus Routed

If the destination is inside a directly connected subnet, the host resolves a link-layer neighbor and sends directly. If not, it sends to a gateway. A wrong subnet mask can make a host ARP for a remote system that should have gone through a router.

## Private, Public, and Special Ranges

Operators should recognize common special ranges:

- RFC 1918 private IPv4: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`,
- loopback: `127.0.0.0/8` and `::1`,
- link-local: `169.254.0.0/16` and `fe80::/10`,
- documentation: `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`, and `2001:db8::/32`.

Cloud and Kubernetes networks often overlap with private ranges. Overlap between a laptop VPN, VPC, Pod CIDR, Service CIDR, and on-prem network can produce confusing route and NAT failures.

## IPv6 Basics

IPv6 is not just bigger IPv4. Hosts often have multiple IPv6 addresses, including link-local addresses. Neighbor Discovery replaces ARP, router advertisements can provide network configuration, and many links use `/64` prefixes.

Dual-stack failures often look like intermittent application timeouts because clients may try IPv6 first, fall back to IPv4, or race both families.

## Source Address Selection

The route lookup chooses not only an egress interface and next hop, but often a source address. Firewalls, replies, TLS certificates, and upstream ACLs may depend on that source address. Use `ip route get` to inspect the decision Linux would make.

## Troubleshooting Flow

1. Confirm the local addresses and prefix lengths.
2. Confirm the selected route with `ip route get`.
3. Confirm whether the destination should be local or routed.
4. Check the default gateway.
5. Check source address selection.
6. Check for overlapping private ranges.
7. For dual stack, test A/AAAA and IPv4/IPv6 paths separately.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a CIDR prefix length describe?" answer="How many leading address bits are the network prefix used for routing decisions." %}
  {% include study-card.html question="What is longest-prefix match?" answer="The most specific matching route wins over broader matching routes." %}
  {% include study-card.html question="Why does source address selection matter?" answer="Return routing, firewall policy, ACLs, and upstream expectations can depend on the chosen source address." %}
</div>

## References

- [RFC 4632: Classless Inter-domain Routing](https://www.rfc-editor.org/rfc/rfc4632)
- [RFC 1918: Address Allocation for Private Internets](https://www.rfc-editor.org/rfc/rfc1918)
- [RFC 8200: Internet Protocol, Version 6](https://www.rfc-editor.org/rfc/rfc8200)
- [RFC 4861: Neighbor Discovery for IP version 6](https://www.rfc-editor.org/rfc/rfc4861)
- [ip-route(8)](https://man7.org/linux/man-pages/man8/ip-route.8.html)
