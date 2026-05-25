---
title: Packet Capture and Analysis
layout: page
permalink: /docs/networking/packet-capture-analysis/
summary: "Practical tcpdump and Wireshark packet analysis for filters, handshakes, retransmits, resets, DNS, TLS SNI, VLAN tags, MTU, and rolling captures."
tags:
  - networking
  - packet-analysis
  - tcpdump
  - wireshark
  - troubleshooting
---

# Packet Capture and Analysis

Packet capture is the evidence layer between guesses and facts. A good capture can prove whether a packet left, arrived, was reset, was fragmented, was retransmitted, used the wrong VLAN, hit the wrong DNS server, or carried the wrong TLS SNI.

The skill is not just running `tcpdump`; it is choosing the right interface, filter, capture point, and time window.

## First Checks

```bash
ip addr
ip route get 203.0.113.10
tcpdump -D
sudo tcpdump -nn -i any host 203.0.113.10
sudo tcpdump -nn -i eth0 'tcp port 443 and host 203.0.113.10'
```

Use `-nn` to avoid DNS and service-name lookups during incidents. Lookups can add noise or hang when DNS is part of the failure.

## Capture Filters vs Display Filters

| Filter Type | Where It Runs | Example | Purpose |
| --- | --- | --- | --- |
| Capture filter | Before packets are written, using BPF syntax. | `host 203.0.113.10 and port 443` | Keep capture small and safe. |
| Display filter | After capture, usually in Wireshark/tshark. | `tcp.analysis.retransmission` | Inspect already captured packets. |

Capture filters reduce overhead and file size, but they can accidentally discard evidence. When unsure, capture slightly broader and analyze later.

## TCP Handshake Analysis

Healthy TCP setup:

```text
client -> server  SYN
server -> client  SYN, ACK
client -> server  ACK
```

Common patterns:

| Capture Pattern | Meaning |
| --- | --- |
| Repeated SYN, no SYN-ACK | Server unreachable, firewall drop, wrong route, or broken return path. |
| SYN then RST | Service closed, firewall reject, proxy reject, or wrong destination. |
| SYN-ACK returns but client keeps retrying | Client did not receive it, local firewall dropped it, asymmetric path, or capture point mismatch. |
| Handshake succeeds, TLS stalls | Certificate, SNI, ALPN, TLS version, proxy, or application issue. |

Use captures on both sides when possible. One-sided captures prove only what happened at that point.

## Retransmits, Resets, and Windows

Useful Wireshark display filters:

```text
tcp.analysis.retransmission
tcp.analysis.fast_retransmission
tcp.flags.reset == 1
tcp.window_size_value == 0
tcp.analysis.duplicate_ack
```

Interpretation depends on direction. Server-to-client retransmits point at client path, server egress, or client receive pressure. Client-to-server retransmits point at the reverse.

## Packet-Capture Interpretation Gallery

| Pattern | Capture Sign | Likely Meaning |
| --- | --- | --- |
| SYN drop | Repeated SYN, no SYN-ACK. | Firewall drop, missing listener path, route issue, NAT, or return-path failure. |
| RST | `tcp.flags.reset == 1`. | Active refusal, proxy abort, idle timeout, protocol violation, or app close. |
| TLS alert | TLS Alert after ClientHello or certificate exchange. | SNI, ALPN, client cert, trust chain, TLS version, or policy mismatch. |
| DNS truncation | UDP DNS response has TC bit; TCP retry succeeds. | Response too large for UDP path or EDNS/MTU issue. |
| MTU black hole | Large packets retransmit, ICMP Packet Too Big missing. | PMTUD blocked by firewall, tunnel overhead, or wrong MTU. |
| QUIC blocked | TCP 443 works, UDP 443 no response. | Firewall/NAT/load balancer does not support or allow HTTP/3 path. |
| Proxy CONNECT | HTTP `CONNECT host:port` followed by tunnel or proxy error. | Forward proxy policy, auth, DNS, or tunnel setup issue. |
| Asymmetric routing | Request seen at one boundary, response missing or bypassing stateful point. | ECMP, wrong return route, firewall state miss, or NAT asymmetry. |

## Wireshark Display-Filter Cheatsheet

```text
tcp.analysis.retransmission
tcp.flags.reset == 1
tls.handshake.extensions_server_name
tls.handshake.extensions_alpn_str
dns.flags.rcode != 0
dns.flags.truncated == 1
icmp.type == 3 && icmp.code == 4
icmpv6.type == 2
http2
quic
http.request.method == "CONNECT"
```

Use display filters after capture. Do not make capture filters too narrow when the failure may be a response-code, TLS-alert, ICMP, or fallback behavior.

## DNS and TLS Captures

DNS:

```bash
sudo tcpdump -nn -i any 'port 53'
sudo tcpdump -nn -i any 'host 10.0.0.53 and (udp port 53 or tcp port 53)'
```

TLS ClientHello often exposes SNI and ALPN even though application data is encrypted:

```bash
sudo tcpdump -nn -i eth0 -s 0 -w tls-debug.pcap 'tcp port 443'
tshark -r tls-debug.pcap -Y 'tls.handshake.extensions_server_name' -T fields -e tls.handshake.extensions_server_name
```

Encrypted ClientHello can hide SNI in newer deployments, so absence of visible SNI is not always an error.

## VLAN, MTU, and Offload Pitfalls

VLAN tags may only be visible on trunk interfaces or before hardware strips them. MTU problems often look like small packets working while large packets stall. Offloads can show giant TCP segments or bad checksums in local captures because tcpdump sees packets before the NIC finishes work.

Useful checks:

```bash
ip -d link show eth0
sudo tcpdump -e -nn -i eth0 'vlan'
tracepath 203.0.113.10
ethtool -k eth0
```

Do not disable offloads as a first fix. Disable them only briefly when proving whether capture artifacts are misleading.

## Rolling Captures

Use ring buffers when the problem is intermittent:

```bash
sudo tcpdump -nn -s 0 -i eth0 \
  -G 60 -W 10 \
  -w '/tmp/capture-%Y%m%d%H%M%S.pcap' \
  'host 203.0.113.10'
```

This keeps ten one-minute files and prevents captures from filling the disk.

## Runbook

1. Define source, destination, port, protocol, and expected direction.
2. Identify the right namespace and interface.
3. Capture with names disabled and a bounded filter.
4. Record packet counts before and after the test.
5. Look for handshake shape, retransmits, resets, DNS answers, TLS SNI, and MTU clues.
6. If the capture is one-sided, do not infer the middle path without another vantage point.
7. Save the exact command and timestamps with the incident notes.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why use -nn with tcpdump during incidents?" answer="It prevents DNS and service-name lookups from adding delay or confusing output." %}
  {% include study-card.html question="What does repeated SYN with no SYN-ACK usually mean?" answer="A drop or reachability failure before the response returns to the client capture point." %}
  {% include study-card.html question="Why can tcpdump show bad checksums on a healthy host?" answer="Checksum offload may complete checksums after the packet is captured locally." %}
  {% include study-card.html question="Why use tcpdump ring buffers?" answer="They preserve recent evidence for intermittent failures without filling the disk." %}
</div>

## References

- [tcpdump man page](https://www.tcpdump.org/manpages/tcpdump.1.html)
- [Wireshark display filter reference](https://www.wireshark.org/docs/dfref/)
- [tshark man page](https://www.wireshark.org/docs/man-pages/tshark.html)
- [Linux packet socket documentation](https://man7.org/linux/man-pages/man7/packet.7.html)
