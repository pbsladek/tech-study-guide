---
title: Networking
layout: page
permalink: /docs/networking/
summary: "Practical systems networking: OSI layers, NICs, ARP, IP routing, TCP/UDP, DNS, TLS, and packet debugging."
tags:
  - networking
  - infrastructure
  - troubleshooting
---

# Networking

Networking is a stack of encapsulation, addressing, forwarding, control messages, name resolution, encryption, proxy behavior, and state. The key is to know what each layer is responsible for and where to observe it when something breaks.

The practical command patterns are embedded in the topic pages where the failures happen. Start with [Cross-Layer Incident Runbooks](cross-layer-incident-runbooks/) when the symptom crosses application, Linux, Kubernetes, DNS, proxy, and network boundaries.

## Mental Model

A request from a browser to a service crosses several boundaries:

1. Application builds an HTTP request.
2. TLS may encrypt it.
3. TCP establishes a connection and segments bytes.
4. IP chooses a destination address and route.
5. Ethernet or Wi-Fi frames the packet for the local link.
6. The NIC transmits bits.
7. Switches, routers, firewalls, NAT, load balancers, and proxies may transform or forward traffic.

Each boundary can fail independently.

## Data Plane and Control Plane

Many systems have a data plane and a control plane:

| Plane | Job | Examples |
| --- | --- | --- |
| Data plane | Moves packets, bytes, or requests. | NIC forwarding, kernel routing, Envoy proxying, load-balancer forwarding. |
| Control plane | Decides or programs how the data plane should behave. | Routing protocols, Kubernetes controllers, Istio control plane, cloud load-balancer APIs. |

This separation matters during incidents. A control plane outage may prevent new changes while existing flows keep working. A data-plane failure may drop traffic even though APIs and dashboards look healthy.

## Critical Subtopics

| Topic | Why It Matters |
| --- | --- |
| [Request Path](request-path/) | Traces one request through DNS, client behavior, TCP, TLS, proxies, Kubernetes Service routing, CNI, Pod, app, database, and response path. |
| [Cross-Layer Incident Runbooks](cross-layer-incident-runbooks/) | Moves from symptoms such as HTTP 504, connection refused, TLS timeout, DNS intermittent, large requests hanging, and Pod-only failures through the relevant layers. |
| [Packet Path](packet-path/) | Tracks packets through sockets, routing, neighbor lookup, firewall hooks, qdisc, NIC queues, and return paths. |
| [Packet Capture and Analysis](packet-capture-analysis/) | Covers `tcpdump`, Wireshark, capture filters, retransmits, resets, DNS, TLS SNI, VLAN tags, MTU, and ring-buffer captures. |
| [Routing, NAT, and Firewalls](routing-nat-firewalls/) | Covers route selection, policy routing, NAT state, conntrack, asymmetric routing, and load-balancer edge cases. |
| [BGP and Dynamic Routing](bgp-dynamic-routing/) | Covers ASNs, peering, route advertisement, route selection, communities, ECMP, anycast, and route-leak failure modes. |
| [Datacenter L2/L3 Operations](datacenter-l2-l3-operations/) | Covers LACP, MLAG/vPC, STP/RSTP, ARP/NDP instability, EVPN/VXLAN, ECMP, anycast, and fabric incident evidence. |
| [Cloud Networking](cloud-networking/) | Covers VPCs/VNets, subnets, route tables, security groups, private endpoints, peering, transit gateways, NAT, and load balancers. |
| [Network Namespaces and Virtual Networking](network-namespaces-virtual-networking/) | Covers `ip netns`, veth pairs, Linux bridges, macvlan, ipvlan, tun/tap, VXLAN, overlays, and CNI-style packet paths. |
| [IPv6 Operations](ipv6-operations/) | Covers SLAAC, DHCPv6, Router Advertisements, NDP, link-local addresses, privacy addresses, dual-stack, NAT64, DNS AAAA, and firewalling. |
| [NAT Gateways and NAT](nat-gateways/) | Covers SNAT, DNAT, PAT, masquerade, cloud NAT gateways, port exhaustion, hairpin NAT, Kubernetes egress, and NAT troubleshooting. |
| [Firewalls, iptables, and Netfilter](firewalls-iptables-netfilter/) | Covers netfilter hooks, nftables, iptables, chains, tables, conntrack, NAT, counters, logging, and policy troubleshooting. |
| [VPNs and IPsec Tunnels](vpn-ipsec-tunnels/) | Covers VPN types, IPsec tunnel mode, IKEv2, ESP, NAT-T, selectors, route-based tunnels, split tunneling, and MTU. |
| [DHCP, Routers, and Switches](dhcp-routers-switches/) | Deep DHCP coverage: DORA, leases, options, default gateways, DNS options, relay/helper addresses, Option 82, VLAN boundaries, DHCP snooping, DHCPv6, SLAAC, and Router Advertisements. |
| [Switching, VLANs, and Hosts](switching-vlans-hosts/) | Covers switches, MAC learning, access and trunk ports, 802.1Q VLAN tags, Linux bridges, and `/etc/hosts`. |
| [IP Addressing and Subnetting](ip-addressing-subnetting/) | Covers CIDR, prefixes, private ranges, default gateways, IPv6, source address selection, and overlapping networks. |
| [ICMP, MTU, and Path Testing](icmp-mtu-path-testing/) | Covers ping, traceroute, tracepath, Path MTU Discovery, fragmentation, tunnel overhead, loss, latency, and jitter. |
| [TCP and Sockets](tcp-sockets/) | Explains listen queues, socket buffers, TIME_WAIT, ephemeral ports, keepalive, and kernel TCP state. |
| [UDP, QUIC, and Connectionless Traffic](udp-quic-connectionless/) | Covers UDP datagrams, DNS/DHCP/NTP, QUIC, HTTP/3, conntrack timers, UDP 443, and packet capture. |
| [Load Balancers and Proxies](load-balancers-proxies/) | Covers L4/L7 balancing, reverse proxies, health checks, TLS termination, source IP preservation, forwarding headers, and timeouts. |
| [Resilience, Timeouts, and Draining](resilience-timeouts-draining/) | Covers timeout budgets, retries, backoff, connection pools, keepalive, load-balancer draining, DNS TTLs, and zero-downtime deploy behavior. |
| [Forward and Reverse Proxies](proxies-forward-reverse/) | Covers explicit forward proxies, reverse proxies, transparent interception, CONNECT tunnels, proxy env vars, headers, and TLS interception. |
| [HTTP and Proxy Debugging](http-proxy-debugging/) | Covers `curl -v`, headers, redirects, keepalive, chunking, HTTP/2, gRPC, WebSockets, proxy variables, and timeout alignment. |
| [Certificates and HTTPS](certificates-https/) | Covers certificate chains, SANs, SNI, CA stores, trust failures, and Ubuntu certificate operations. |
| [Zero-Trust Networking](zero-trust-networking/) | Covers host firewall policy, nftables, mTLS, certificate rotation, SNI, ALPN, service identity, SSH hardening, auditd, SELinux, and AppArmor. |
| [TCP, TLS, and HTTP](tcp-tls-http/) | Separates transport, encryption, and application-layer failures in the request path. |

## OSI Layers for Troubleshooting

| Layer | Name | Practical Checks |
| --- | --- | --- |
| 7 | Application | HTTP status, DNS names, auth, app logs |
| 6 | Presentation | TLS versions, certificates, SNI, encoding |
| 5 | Session | Connection reuse, proxies, timeouts |
| 4 | Transport | TCP handshake, ports, retransmits, UDP loss |
| 3 | Network | IP address, route, NAT, ICMP, TTL |
| 2 | Data Link | MAC address, VLAN, ARP, switch port |
| 1 | Physical | Cable, optics, signal, link state, duplex |

The OSI model is not a perfect map of modern systems, but it is a useful checklist.

## NIC and Link Layer

A NIC sends and receives frames. Important operational details:

- Link state can be up while the path is still broken upstream.
- MTU mismatches cause fragmentation or black-hole behavior.
- Offloads can hide what packets look like before the NIC modifies them.
- VLAN tagging changes which L2 domain a host participates in.
- Interface counters reveal drops, errors, overruns, and carrier problems.

Switches learn source MAC addresses and forward frames inside a VLAN. If the wrong VLAN is assigned, the host can have a perfectly healthy NIC and still be isolated from the expected gateway or peers. Access ports usually send untagged traffic for one VLAN; trunk ports carry multiple VLANs with 802.1Q tags.

## ARP

ARP maps IPv4 addresses to MAC addresses on a local broadcast domain. If a host wants to send to an IP on the same subnet, it broadcasts "Who has this IP?" and caches the reply.

Quirks:

- ARP is local-link only; routers do not forward ARP broadcasts.
- Stale ARP entries can send traffic to the wrong MAC after failover.
- Duplicate IPs create unstable ARP behavior.
- Gratuitous ARP announces ownership and helps update neighbor caches.
- IPv6 uses Neighbor Discovery instead of ARP.

## IP Routing

Routing answers: "Where should this packet go next?"

The host checks:

1. Is the destination local?
2. Is there a more specific route?
3. Use the default gateway if no specific route matches.

CIDR longest-prefix match is fundamental. `10.0.1.0/24` beats `10.0.0.0/8`, and both beat `0.0.0.0/0`.

## TCP and UDP

TCP provides reliable byte streams with connection state, retransmission, ordering, flow control, and congestion control. Connection setup uses a three-way handshake: SYN, SYN-ACK, ACK.

UDP is message-oriented and connectionless. It is common for DNS, QUIC, telemetry, and latency-sensitive protocols. Reliability, ordering, and retransmission must be handled by the application or higher protocol when needed.

DHCP also uses UDP and is often the first protocol that proves whether a VLAN, switch port, relay agent, router interface, and address-management policy agree. For a focused runbook, see [DHCP, Routers, and Switches](dhcp-routers-switches/).

## NAT and Load Balancing

NAT rewrites addresses and/or ports. It is useful, but it creates state and can hide the original source. Load balancers may operate at:

- L4: route by IP/port and connection metadata.
- L7: route by HTTP host, path, headers, or protocol semantics.

Common pitfalls:

- Connection tracking tables fill up.
- Idle timeouts close connections.
- Source IP preservation changes routing requirements.
- Health checks do not match real user traffic.

## MTU and Fragmentation

MTU is the largest frame payload for a link. Tunnels and overlays add headers, reducing effective MTU. If Path MTU Discovery fails because ICMP is blocked, large packets can disappear while small packets work.

Symptoms:

- SSH works but file transfer hangs.
- TLS handshake stalls after ClientHello or certificate exchange.
- HTTP small responses work but large responses fail.

## Debugging Commands

```bash
ip addr
ip link
ip route
ip neigh
ss -tuna
traceroute example.com
ping -M do -s 1472 example.com
tcpdump -nn -i any host example.com
```

## Debugging Order

1. Confirm local interface and IP.
2. Confirm switch port, VLAN, and trunk/access expectations.
3. Confirm route selection.
4. Confirm ARP/neighbor resolution for local next hop.
5. Confirm local firewall and listening sockets.
6. Test `/etc/hosts`, NSS, and DNS separately from connectivity.
7. Test TCP handshake or UDP request.
8. Capture packets on both sides when possible.
9. Check intermediate NAT/load balancer/firewall state.
10. Check ICMP, MTU, timeout, and proxy behavior when only large or long-lived requests fail.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does ARP resolve?" answer="For IPv4 on a local link, ARP maps an IP address to a MAC address." %}
  {% include study-card.html question="Why can small packets work while large packets fail?" answer="MTU or Path MTU Discovery problems can black-hole larger packets, especially through tunnels or blocked ICMP." %}
  {% include study-card.html question="What routing rule wins when multiple routes match?" answer="The most specific prefix wins; longest-prefix match beats broader routes." %}
  {% include study-card.html question="What does TCP add over IP?" answer="Connection state, reliable ordered byte streams, retransmission, flow control, and congestion control." %}
  {% include study-card.html question="Why is OSI still useful?" answer="It gives operators a structured troubleshooting checklist even though real protocols do not fit the model perfectly." %}
</div>

## Practice Deck

{% include study-card-deck.html deck="networking" %}

## References

- [RFC 826: Address Resolution Protocol](https://www.rfc-editor.org/rfc/rfc826)
- [RFC 4632: Classless Inter-domain Routing](https://www.rfc-editor.org/rfc/rfc4632)
- [RFC 792: Internet Control Message Protocol](https://www.rfc-editor.org/rfc/rfc792)
- [RFC 768: User Datagram Protocol](https://www.rfc-editor.org/rfc/rfc768)
- [RFC 9293: Transmission Control Protocol](https://www.ietf.org/rfc/rfc9293.html)
- [RFC 9000: QUIC](https://www.rfc-editor.org/rfc/rfc9000)
- [RFC 8446: The Transport Layer Security Protocol Version 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 5280: PKIX Certificate and CRL Profile](https://www.rfc-editor.org/rfc/rfc5280)
- [hosts(5) Linux manual page](https://man7.org/linux/man-pages/man5/hosts.5.html)
- [IEEE 802.1Q VLANs](https://www.ieee802.org/1/pages/802.1Q.html)
- [Linux kernel networking documentation](https://docs.kernel.org/networking/index.html)
- [VPNs and IPsec tunnels](vpn-ipsec-tunnels/)
- [Firewalls, iptables, and Netfilter](firewalls-iptables-netfilter/)
- [Forward and reverse proxies](proxies-forward-reverse/)
- [TechTarget: OSI model overview](https://www.techtarget.com/searchnetworking/definition/OSI)
