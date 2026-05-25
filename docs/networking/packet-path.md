---
title: Packet Path
layout: page
permalink: /docs/networking/packet-path/
summary: "How packets move through local sockets, routing, neighbor lookup, firewalls, conntrack, qdisc, NIC queues, and return paths."
tags:
  - networking
  - linux
  - packet-analysis
---

# Packet Path

A packet is not just "sent to the network." On a Linux host it crosses sockets, routing tables, policy rules, neighbor tables, firewall hooks, connection tracking, queuing disciplines, NIC drivers, and hardware queues.

## First Checks

```bash
ip addr
ip route get 203.0.113.10
ip rule
ip neigh
ss -tuna
tcpdump -nn -i any host 203.0.113.10
```

## Outbound Flow

1. Application writes to a socket.
2. TCP or UDP builds transport state.
3. IP route lookup chooses egress interface and next hop.
4. Policy routing may override the main table.
5. Netfilter/nftables hooks may permit, drop, mark, NAT, or track the flow.
6. Neighbor lookup resolves the next-hop MAC address.
7. qdisc queues the packet.
8. The NIC driver and hardware transmit frames.

## Inbound Flow

1. NIC receives a frame into a queue.
2. Driver and NAPI move packets toward the kernel network stack.
3. Firewall and conntrack hooks classify the packet.
4. IP local-delivery or forwarding decision happens.
5. TCP validates sequence/window state or UDP delivers the datagram.
6. The socket receive queue wakes the application.

## Where Things Break

| Symptom | Likely Layer |
| --- | --- |
| No route to host | route table, policy rule, missing default gateway. |
| ARP incomplete | local L2, wrong subnet, duplicate IP, next-hop unreachable. |
| SYN leaves, no SYN-ACK | routing, firewall, NAT, service, return path. |
| SYN-ACK returns, app still times out | local firewall, conntrack, socket backlog, TLS/app layer. |
| Drops under load | NIC queue, qdisc, softirq, conntrack table, receive backlog. |

## Observability

Use host-local commands first, then capture at boundaries. A capture on only one side can prove a packet was sent or received, but it cannot prove what happened in the middle.

## Production Packet-Capture Labs

These labs belong with the packet path because each one proves where a packet stopped changing state. Keep captures tight, use timestamps, and capture at the closest safe boundary before restarting services.

| Lab | Capture | What It Proves |
| --- | --- | --- |
| SYN drop | `tcpdump -nn -i any 'host 203.0.113.10 and tcp[tcpflags] & tcp-syn != 0'` | Whether SYNs leave and whether SYN-ACKs return. |
| MTU black hole | `tcpdump -nn -i any 'icmp or host 203.0.113.10'` plus `tracepath` | Whether Packet Too Big or fragmentation-needed messages return. |
| TLS SNI mismatch | `tcpdump -nn -s0 -A -i any 'tcp port 443'` with `openssl s_client -servername ...` | Whether TCP works and the TLS route depends on the requested name. |
| DNS truncation | `tcpdump -nn -s0 -i any 'port 53'` and retry with `dig +tcp` | Whether large UDP DNS answers require TCP fallback. |
| Asymmetric routing | Capture on source, destination, and stateful firewall if possible. | Whether request and reply cross the same stateful device. |
| Conntrack exhaustion | `conntrack -S`, `nf_conntrack_count`, and new-flow captures. | Whether new flows fail while established flows continue. |
| Proxy CONNECT | `curl -v -x http://proxy:3128 https://target` and capture proxy side. | Whether the client reaches the proxy and whether the tunnel is established. |
| QUIC blocked | Compare `curl --http3` with HTTPS over TCP and capture `udp port 443`. | Whether UDP 443 is filtered or timed out differently from TCP 443. |

Example SYN-drop workflow:

```bash
ip route get 203.0.113.10
tcpdump -nn -i any 'host 203.0.113.10 and tcp[tcpflags] & (tcp-syn|tcp-ack|tcp-rst) != 0'
nc -vz 203.0.113.10 443
ss -tan state syn-sent
```

If the SYN leaves and nothing returns, move to route, firewall, NAT, load balancer, service health, and return path. If a RST returns, treat it as connection refused or active rejection rather than silent loss.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does ip route get show?" answer="The route decision Linux would use for a destination, including source address and egress interface." %}
  {% include study-card.html question="Why inspect ip neigh?" answer="Neighbor resolution must map the next-hop IP to a link-layer address before local transmission." %}
  {% include study-card.html question="Why can a SYN leave but no SYN-ACK return?" answer="The failure may be routing, firewall, NAT, service availability, or the return path." %}
  {% include study-card.html question="Why compare QUIC over UDP 443 with HTTPS over TCP 443?" answer="Middleboxes often filter, NAT, or time out UDP 443 differently from TCP 443 even for the same site." %}
</div>

## References

- [Linux kernel networking documentation](https://docs.kernel.org/networking/index.html)
- [ip-route(8)](https://man7.org/linux/man-pages/man8/ip-route.8.html)
- [tcpdump(8)](https://www.tcpdump.org/manpages/tcpdump.1.html)
