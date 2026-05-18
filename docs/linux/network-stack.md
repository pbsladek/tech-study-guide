---
title: Linux Network Stack
layout: page
permalink: /docs/linux/network-stack/
summary: "Linux sockets, routes, neighbor tables, netfilter, conntrack, qdisc, NIC queues, namespaces, and network troubleshooting."
tags:
  - linux
  - networking
  - troubleshooting
---

# Linux Network Stack

Linux networking is both OS internals and production infrastructure. Containers, Kubernetes, firewalls, service meshes, and load balancers all depend on sockets, namespaces, routes, neighbor tables, netfilter, conntrack, qdisc, and NIC queues.

## First Checks

```bash
ip addr
ip route
ip rule
ip neigh
ss -tulpen
nft list ruleset
cat /proc/net/softnet_stat
```

## Sockets

Sockets are kernel endpoints for network communication. Listening sockets have queues. Established TCP sockets have send and receive buffers, congestion state, retransmission timers, and sequence windows. UDP sockets receive datagrams and leave reliability to the application.

## Namespaces

Network namespaces give isolated network stacks: interfaces, routes, firewall rules, sockets, and neighbor tables. Containers usually run inside their own netns connected to the host through veth pairs, bridges, overlays, or CNI plugins.

## Netfilter and conntrack

Netfilter hooks let nftables or iptables inspect and transform packets. Conntrack records flow state for stateful firewalls and NAT. A full conntrack table can make new connections fail while established traffic continues.

## qdisc, Softirq, and NIC Queues

Packets may queue before transmission or after receive. Under load, drops can happen in NIC rings, qdisc, socket buffers, or softnet backlog. High softirq CPU often points at network packet processing rather than application code.

## Debugging Flow

1. Check the namespace where the process runs.
2. Confirm listening sockets and bound addresses.
3. Confirm route and source address selection.
4. Confirm neighbor resolution.
5. Check firewall and conntrack state.
6. Watch drops, errors, retransmits, and softirq pressure.
7. Capture packets at process namespace, host, and peer when possible.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What changes in a network namespace?" answer="Interfaces, routes, sockets, firewall state, and neighbor tables can be isolated from the host namespace." %}
  {% include study-card.html question="Why does conntrack matter for NAT?" answer="It stores flow state needed to translate packets consistently in both directions." %}
  {% include study-card.html question="What can high softirq CPU indicate?" answer="The kernel is spending significant CPU time processing deferred network work." %}
</div>

## References

- [Linux kernel networking documentation](https://docs.kernel.org/networking/index.html)
- [network_namespaces(7)](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)
- [socket(7)](https://man7.org/linux/man-pages/man7/socket.7.html)
- [nftables documentation](https://wiki.nftables.org/wiki-nftables/index.php/Main_Page)
