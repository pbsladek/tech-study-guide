---
title: Routing, NAT, and Firewalls
layout: page
permalink: /docs/networking/routing-nat-firewalls/
summary: "Routing tables, policy routing, NAT, connection tracking, firewall state, asymmetric paths, and load-balancer edge cases."
tags:
  - networking
  - routing
  - nat
  - firewall
---

# Routing, NAT, and Firewalls

Routing decides the next hop. NAT rewrites addresses or ports. Firewalls enforce policy. Most production network failures involve these three together, especially when return paths are asymmetric or connection tracking state is exhausted.

## Core Commands

```bash
ip route
ip route get 198.51.100.10
ip rule
nft list ruleset
conntrack -S
conntrack -L | head
```

## Routing

Linux chooses routes by longest-prefix match within the selected routing table. Policy rules can select alternate tables based on source address, fwmark, TOS, interface, or other packet attributes.

Key ideas:

- local routes are special,
- the default route is the fallback,
- policy routing can make `ip route` alone misleading,
- source address selection affects return traffic,
- ECMP can split flows across next hops.

Routers often provide the first routed boundary for DHCP. Because DHCPv4 starts with local broadcast, a router interface or relay agent must forward requests to DHCP servers on other subnets. The relay-selected interface address, commonly recorded in `giaddr`, is how the server chooses the right scope. A routing device can therefore break DHCP even while ordinary routed traffic works.

Router-provided host configuration commonly arrives through DHCP options:

- router/default gateway option,
- DNS server option,
- domain/search suffix,
- classless static routes,
- PXE/TFTP boot information.

## NAT

SNAT changes the source. DNAT changes the destination. Masquerade is dynamic SNAT for changing egress addresses. NAT requires connection tracking for most stateful behavior.

NAT pitfalls:

- ephemeral port exhaustion,
- conntrack table full,
- idle timeout too short,
- source IP loss at the application layer,
- hairpin NAT behavior differs by platform,
- return path must pass the same stateful device unless routing is designed otherwise.

## Firewalls

Stateful firewalls make decisions using connection state, interfaces, addresses, ports, and sometimes marks or zones. When a packet is dropped, the reason may be policy, state mismatch, invalid conntrack state, reverse path filtering, or rate limiting.

## Load Balancers

Load balancers often add their own NAT and health-check behavior. Health checks prove only the configured check path, not the full user path. L7 load balancers can fail on Host headers, SNI, HTTP versions, or backend connection reuse even when TCP is fine.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is longest-prefix match?" answer="The most specific matching route prefix wins over broader routes." %}
  {% include study-card.html question="Why can policy routing make ip route misleading?" answer="Rules can select routing tables other than the main table based on packet attributes." %}
  {% include study-card.html question="Why does stateful NAT care about return paths?" answer="The return packet must match connection-tracking state or the NAT device cannot translate it correctly." %}
</div>

## References

- [ip-rule(8)](https://man7.org/linux/man-pages/man8/ip-rule.8.html)
- [nftables documentation](https://wiki.nftables.org/wiki-nftables/index.php/Main_Page)
- [conntrack-tools manual](https://conntrack-tools.netfilter.org/manual.html)
