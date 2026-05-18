---
title: TCP, TLS, and HTTP
layout: page
permalink: /docs/networking/tcp-tls-http/
summary: "Transport and application handshake layers: TCP state, retransmits, flow control, congestion control, TLS SNI/certificates, and HTTP behavior."
tags:
  - networking
  - tcp
  - tls
  - http
---

# TCP, TLS, and HTTP

Most full-stack requests cross at least three protocol layers after DNS: TCP creates a reliable byte stream, TLS authenticates and encrypts it, and HTTP carries application semantics. Debugging is faster when you can identify which handshake failed.

## Layer Checks

```bash
nc -vz example.com 443
openssl s_client -connect example.com:443 -servername example.com
curl -v https://example.com/
ss -ti dst example.com
tcpdump -nn -i any host example.com and port 443
```

## TCP

TCP provides connection state, ordered delivery, retransmission, flow control, and congestion control. A successful three-way handshake proves only that SYN, SYN-ACK, and ACK crossed the path. It does not prove TLS, HTTP, auth, or backend correctness.

Important TCP states:

- `LISTEN`: service is accepting connection attempts,
- `SYN-SENT`: client is waiting for SYN-ACK,
- `SYN-RECV`: server received SYN and replied,
- `ESTAB`: connection established,
- `TIME-WAIT`: closed connection identity retained for delayed packets.

## TLS

TLS adds server authentication, key agreement, encryption, integrity, and optional client authentication. Common production failures include missing intermediate certificates, SNI mismatch, expired certificates, unsupported protocol versions, and clients trusting a different CA bundle than expected.

SNI matters because many servers select certificates and virtual hosts based on the hostname sent in the TLS ClientHello.

## HTTP

HTTP failures can happen after transport is healthy. Host headers, path routing, redirects, proxy headers, keepalive, connection pooling, compression, and timeout budgets all affect user-visible behavior.

Debugging split:

- TCP failure: connection refused, timeout, retransmits, reset.
- TLS failure: certificate, SNI, protocol, cipher, trust chain.
- HTTP failure: status code, routing, auth, app timeout, proxy behavior.

## Deeper Study

- [TCP and Sockets](tcp-sockets/) expands on listen queues, socket buffers, TIME_WAIT, ephemeral ports, and Linux TCP observability.
- [Certificates and HTTPS](certificates-https/) expands on X.509 chains, SAN validation, SNI, CA stores, Ubuntu trust-store operations, and certificate troubleshooting.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a completed TCP handshake prove?" answer="Only that both endpoints exchanged SYN, SYN-ACK, and ACK; upper layers may still fail." %}
  {% include study-card.html question="Why does SNI matter?" answer="It lets a TLS server choose the correct certificate and virtual host for the requested name." %}
  {% include study-card.html question="Why use curl -v after openssl s_client?" answer="openssl isolates TLS details, while curl exercises HTTP behavior, redirects, headers, and application response." %}
</div>

## References

- [RFC 9293: Transmission Control Protocol](https://www.rfc-editor.org/rfc/rfc9293)
- [RFC 8446: The Transport Layer Security Protocol Version 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
