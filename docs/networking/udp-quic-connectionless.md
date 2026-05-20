---
title: UDP, QUIC, and Connectionless Traffic
layout: page
permalink: /docs/networking/udp-quic-connectionless/
summary: "UDP behavior, DNS and DHCP traffic, QUIC, connection tracking, timeouts, packet loss, retries, and operational debugging."
tags:
  - networking
  - udp
  - troubleshooting
---

# UDP, QUIC, and Connectionless Traffic

UDP is simple at the transport layer, but that simplicity pushes reliability, retries, ordering, and congestion behavior into applications and higher protocols. Operators need to debug UDP differently from TCP because there is no handshake, no stream state, and often no obvious error when packets disappear.

## First Checks

```bash
ss -uan
sudo tcpdump -nn -i any udp
conntrack -L -p udp 2>/dev/null | head
dig +notcp example.com A
dig +tcp example.com A
openssl s_client -connect example.com:443 -servername example.com
```

## UDP Model

UDP sends datagrams. A datagram is either delivered as a unit or not delivered. UDP does not provide built-in retransmission, ordering, congestion control, connection setup, or stream semantics.

Common UDP protocols:

- DNS,
- DHCP,
- NTP,
- syslog,
- RTP and media,
- QUIC,
- some telemetry and service discovery protocols.

## Firewalls and Connection Tracking

Stateful devices still create UDP state, but that state is inferred from packets and timers rather than TCP handshakes. UDP idle timeouts can be short. NAT mappings can expire while an application thinks a session is still alive.

For DNS, firewalls must handle both UDP and TCP 53. For QUIC, many networks treat UDP 443 differently from TCP 443, so an HTTPS site can behave differently depending on whether the client uses HTTP/3.

## QUIC and HTTP/3

QUIC runs over UDP and provides encrypted transport features such as streams, loss recovery, congestion control, and connection migration. Because QUIC encrypts most transport metadata, middleboxes cannot inspect it the way they inspect TCP.

Operational implications:

- TCP 443 success does not prove UDP 443 success,
- packet captures show less plaintext detail,
- load balancers need explicit UDP and QUIC support,
- idle timeout and connection migration behavior matter,
- clients may fall back from HTTP/3 to HTTP/2 or HTTP/1.1.

## DHCP and Broadcast Behavior

DHCP commonly starts with broadcast traffic because a host may not have an address yet. DHCP relay agents forward requests across routed networks. A DHCP issue can be a VLAN, relay, firewall, address-pool, or lease-exhaustion issue.

## Troubleshooting Flow

1. Confirm which protocol and port actually uses UDP.
2. Capture packets because failed UDP may produce no local socket error.
3. Check firewall and NAT idle timeouts.
4. Check conntrack state for high-volume UDP.
5. For DNS, test UDP and TCP separately.
6. For QUIC, test UDP 443 separately from TCP 443.
7. Confirm the application implements retries and timeout behavior.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does UDP not provide?" answer="Built-in reliability, ordering, retransmission, connection setup, congestion control, or stream semantics." %}
  {% include study-card.html question="Why can TCP 443 work while HTTP/3 fails?" answer="HTTP/3 uses QUIC over UDP 443, which may be blocked or timed out differently from TCP 443." %}
  {% include study-card.html question="Why are UDP NAT timeouts important?" answer="A NAT mapping can expire while an application still thinks the session is usable." %}
</div>

## References

- [RFC 768: User Datagram Protocol](https://www.rfc-editor.org/rfc/rfc768)
- [RFC 9000: QUIC](https://www.rfc-editor.org/rfc/rfc9000)
- [RFC 9114: HTTP/3](https://www.rfc-editor.org/rfc/rfc9114)
- [RFC 2131: Dynamic Host Configuration Protocol](https://www.rfc-editor.org/rfc/rfc2131)
- [udp(7)](https://man7.org/linux/man-pages/man7/udp.7.html)
