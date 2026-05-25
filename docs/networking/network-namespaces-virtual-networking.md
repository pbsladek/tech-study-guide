---
title: Network Namespaces and Virtual Networking
layout: page
permalink: /docs/networking/network-namespaces-virtual-networking/
summary: "Linux network namespaces, veth pairs, bridges, macvlan, ipvlan, tun/tap, VXLAN, overlays, and CNI-style packet paths."
tags:
  - networking
  - linux
  - containers
  - kubernetes
  - troubleshooting
---

# Network Namespaces and Virtual Networking

Linux can give processes separate network stacks with network namespaces. Each namespace has its own interfaces, routes, addresses, neighbor table, firewall rules, sockets, and `/proc/net` view. Containers, Kubernetes pods, test labs, and service meshes all build on this idea.

Virtual networking connects those isolated stacks with veth pairs, bridges, routing, NAT, overlays, and policy.

## First Checks

```bash
ip netns list
lsns -t net
readlink /proc/<pid>/ns/net
nsenter --target <pid> --net -- ip addr
nsenter --target <pid> --net -- ip route
```

Always confirm which namespace owns the socket or interface before debugging routes or captures.

## Core Building Blocks

| Building Block | Role |
| --- | --- |
| Network namespace | Isolated network stack. |
| veth pair | Two connected virtual Ethernet devices; packets entering one exit the other. |
| Linux bridge | L2 switch inside the kernel. |
| macvlan | Gives virtual interfaces distinct MAC addresses on a parent link. |
| ipvlan | Gives virtual interfaces distinct IP identities with different L2 behavior than macvlan. |
| tun/tap | User-space virtual network device for routed or Ethernet-style packets. |
| VXLAN | Encapsulates L2 frames over UDP for overlay networks. |
| nftables/iptables | Firewall, NAT, and policy hooks. |

These are composable. A container may have `eth0` in its namespace, backed by a veth peer on the host, attached to a bridge, then NATed out of the node.

## Minimal Namespace Lab

Create two namespaces connected through veth:

```bash
sudo ip netns add left
sudo ip netns add right
sudo ip link add veth-left type veth peer name veth-right
sudo ip link set veth-left netns left
sudo ip link set veth-right netns right
sudo ip -n left addr add 10.10.0.1/24 dev veth-left
sudo ip -n right addr add 10.10.0.2/24 dev veth-right
sudo ip -n left link set veth-left up
sudo ip -n right link set veth-right up
sudo ip -n left ping -c 3 10.10.0.2
```

Delete when done:

```bash
sudo ip netns del left
sudo ip netns del right
```

This lab teaches the core container pattern without Docker or Kubernetes.

## Bridges and NAT

A common host-container shape:

```text
container netns eth0
  -> veth peer on host
  -> Linux bridge
  -> host route / NAT
  -> physical NIC
```

Useful checks:

```bash
ip link show type bridge
bridge link
bridge fdb show
nft list ruleset
conntrack -L 2>/dev/null | head
```

If the bridge learns no MAC address, L2 is broken. If bridge forwarding works but external traffic fails, check routing, NAT, firewall policy, and return path.

## macvlan, ipvlan, and Host Reachability

macvlan and ipvlan attach virtual interfaces directly to a parent interface model. They are useful when workloads need first-class addresses on the physical network, but host-to-child reachability can surprise people.

| Mode | Common Use | Caveat |
| --- | --- | --- |
| macvlan bridge | Containers appear as separate MACs on the LAN. | Parent network must allow multiple MACs; host reachability needs design. |
| ipvlan L2 | Multiple IPs share parent L2 behavior. | Less MAC churn, but still depends on upstream policy. |
| ipvlan L3 | Host routes to child networks. | Requires explicit routing. |

Cloud networks and hypervisors often restrict unknown MACs, making macvlan a poor fit.

## VXLAN and Overlays

VXLAN wraps L2 frames in UDP, commonly port `4789`, so workloads can share an overlay network across routed underlays.

Key troubleshooting points:

- Underlay IP routing must work first.
- Effective MTU is smaller because encapsulation adds headers.
- Firewalls must allow overlay UDP traffic.
- Control plane must distribute endpoint and VNI information.
- Packet captures may need both overlay and underlay vantage points.

## CNI-Style Packet Paths

Kubernetes CNI plugins combine these primitives differently:

| CNI Shape | Packet Path |
| --- | --- |
| Bridge/NAT | Pod veth to bridge, node NAT for egress. |
| Routed | Pod veth with node routes to pod CIDRs. |
| Overlay | Pod traffic encapsulated across nodes. |
| eBPF datapath | BPF programs replace or shortcut parts of bridge, kube-proxy, or netfilter behavior. |

The first debugging step is identifying the plugin and datapath mode. Do not assume every cluster uses a Linux bridge.

## Runbook

1. Find the process PID and network namespace.
2. Run `ip addr`, `ip route`, and `ss` inside that namespace.
3. Map namespace interfaces to host veth peers with `ip link`.
4. Check bridge membership, FDB entries, routes, NAT, and firewall counters.
5. Capture inside the namespace and on the host peer when possible.
6. For overlays, check underlay reachability, UDP encapsulation, and MTU.
7. For Kubernetes, identify the CNI plugin before applying generic fixes.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a network namespace isolate?" answer="Interfaces, addresses, routes, neighbor tables, sockets, firewall rules, and /proc/net views." %}
  {% include study-card.html question="What is a veth pair?" answer="Two connected virtual Ethernet devices where packets entering one side exit the other." %}
  {% include study-card.html question="Why can VXLAN create MTU problems?" answer="Encapsulation adds headers, reducing the effective payload size available to workload packets." %}
  {% include study-card.html question="Why identify the CNI plugin before debugging pod networking?" answer="Different CNIs use bridge, routing, overlay, or eBPF datapaths with different failure points." %}
</div>

## References

- [network_namespaces(7)](https://man7.org/linux/man-pages/man7/network_namespaces.7.html)
- [veth(4)](https://man7.org/linux/man-pages/man4/veth.4.html)
- [ip-netns(8)](https://man7.org/linux/man-pages/man8/ip-netns.8.html)
- [Linux bridge documentation](https://docs.kernel.org/networking/bridge.html)
- [VXLAN Linux kernel documentation](https://docs.kernel.org/networking/vxlan.html)
