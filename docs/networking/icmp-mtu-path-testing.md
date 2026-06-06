---
title: ICMP, MTU, and Path Testing
layout: page
permalink: /docs/networking/icmp-mtu-path-testing/
summary: "ICMP, ping, traceroute, path MTU discovery, fragmentation, tunnel overhead, packet loss, jitter, and practical path testing."
tags:
  - networking
  - troubleshooting
  - mtu
---

# ICMP, MTU, and Path Testing

ICMP is control-plane feedback for IP. It is also the basis for familiar tools such as ping and traceroute. Blocking all ICMP can hide useful diagnostics and break Path MTU Discovery, especially through tunnels and overlays.

## Command Examples

```bash
ping -c 4 198.51.100.10
ping -M do -s 1472 198.51.100.10
tracepath 198.51.100.10
traceroute 198.51.100.10
ip link show
tcpdump -nn -i any icmp or icmp6
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `ping -c 4 198.51.100.10` | `Concrete IDs, states, counters, versions, rows, or error strings.` | Turns the example from a command list into evidence for the next debugging step. |
| `ping -M do -s 1472 198.51.100.10` | `Concrete IDs, states, counters, versions, rows, or error strings.` | Turns the example from a command list into evidence for the next debugging step. |
| `tracepath 198.51.100.10` | `Concrete IDs, states, counters, versions, rows, or error strings.` | Turns the example from a command list into evidence for the next debugging step. |

## What ICMP Does

ICMP reports conditions such as destination unreachable, time exceeded, parameter problems, and echo replies. IPv6 relies on ICMPv6 for Neighbor Discovery and packet-too-big messages, so treating ICMPv6 as optional is a common outage source.

Ping proves only that an ICMP echo request and reply worked. It does not prove TCP, UDP, DNS, TLS, HTTP, or application authorization works.

## Traceroute and Tracepath

Traceroute-style tools use TTL or hop-limit behavior to reveal likely layer-3 hops. Results are hints, not absolute topology truth:

- routers can rate-limit or suppress ICMP,
- return paths may differ from forward paths,
- firewalls can block probes,
- ECMP can show different hops for different flows,
- MPLS, tunnels, and proxies can hide internal path details.

## MTU and Fragmentation

MTU is the largest packet size a link can carry at a given layer. Tunnels, VLANs, VPNs, VXLAN, Geneve, IPsec, and cloud overlays add headers, reducing effective payload size.

Path MTU Discovery lets endpoints learn the smallest MTU along the path. If packet-too-big or fragmentation-needed messages are blocked, large packets can disappear while small packets continue to work.

Common symptoms:

- SSH login works but file transfer hangs,
- TLS handshakes stall after larger certificate messages,
- HTTP headers work but larger responses fail,
- DNSSEC or large TXT responses fail through one path,
- only tunneled or VPN traffic is affected.

## Loss, Latency, and Jitter

Packet loss, latency, and jitter are separate signals. A network can have low average latency but high jitter, or no loss for ICMP while TCP retransmits under load. Capture and compare at both ends when possible.

## Troubleshooting Flow

1. Test the application protocol first.
2. Use ping for basic reachability and latency, not application health.
3. Use traceroute or tracepath to look for path changes and MTU hints.
4. Test large packets with DF set for IPv4.
5. Check interface MTU and tunnel overhead.
6. Capture on both sides to distinguish send loss from receive loss.
7. Allow necessary ICMP and ICMPv6 control messages.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why can blocking ICMP break large transfers?" answer="It can prevent Path MTU Discovery from learning that packets are too large for part of the path." %}
  {% include study-card.html question="What does ping prove?" answer="Only that ICMP echo traffic worked on that path; it does not prove application availability." %}
  {% include study-card.html question="Why can traceroute output be misleading?" answer="Routers may filter, rate-limit, use ECMP, or return packets on a different path." %}
</div>

## References

- [RFC 792: Internet Control Message Protocol](https://www.rfc-editor.org/rfc/rfc792)
- [RFC 4443: ICMPv6](https://www.rfc-editor.org/rfc/rfc4443)
- [RFC 1191: Path MTU Discovery](https://www.rfc-editor.org/rfc/rfc1191)
- [RFC 8201: Path MTU Discovery for IPv6](https://www.rfc-editor.org/rfc/rfc8201)
- [tracepath(8)](https://man7.org/linux/man-pages/man8/tracepath.8.html)
