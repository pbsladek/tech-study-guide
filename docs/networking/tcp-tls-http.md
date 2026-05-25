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

Run the checks in order. `nc` proves only that a TCP connection can be opened. `openssl s_client` proves TLS negotiation and certificate presentation. `curl -v` exercises HTTP semantics, redirects, headers, proxy settings, and application response.

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

Certificate validation has separate checks:

| Check | Failure Shape |
| --- | --- |
| Time validity | Expired or not-yet-valid certificate. |
| Hostname | Requested name is missing from the Subject Alternative Name extension. |
| Chain | Missing intermediate or unknown root CA. |
| Purpose | Certificate is not valid for server or client authentication. |
| Revocation policy | Client requires OCSP or CRL behavior that the server or network path does not satisfy. |

## HTTP

HTTP failures can happen after transport is healthy. Host headers, path routing, redirects, proxy headers, keepalive, connection pooling, compression, and timeout budgets all affect user-visible behavior.

Debugging split:

- TCP failure: connection refused, timeout, retransmits, reset.
- TLS failure: certificate, SNI, protocol, cipher, trust chain.
- HTTP failure: status code, routing, auth, app timeout, proxy behavior.

## Failure Ladder Example

Use this ladder when someone says "the site is down":

```bash
dig example.com A
ip route get "$(dig +short example.com A | head -1)"
nc -vz example.com 443
printf '' | openssl s_client -connect example.com:443 -servername example.com -brief
curl -vkI https://example.com/
curl -v --resolve example.com:443:198.51.100.10 https://example.com/healthz
```

Interpretation:

| Observation | Likely Area |
| --- | --- |
| DNS returns the wrong address | Authoritative DNS, caching, split-horizon DNS, search path. |
| Route chooses the wrong interface | Local routing, VPN, policy routing, source address selection. |
| TCP connection refused | Host reachable but nothing is listening or firewall actively rejects. |
| TCP timeout | Drop, routing, NAT, firewall, load balancer, or return path. |
| TLS hostname error | SNI, certificate SAN, wrong virtual host, or wrong endpoint. |
| HTTP 404/503 after TLS works | Proxy route, backend health, Host header, path match, app dependency. |

## Timeout Budget

Each layer consumes time. A client timeout must cover DNS, TCP connect, TLS handshake, request upload, server processing, response headers, and response body. Retries multiply load unless they are bounded, jittered, and safe for the operation.

## Deeper Study

- [TCP and Sockets](../tcp-sockets/) expands on listen queues, socket buffers, TIME_WAIT, ephemeral ports, and Linux TCP observability.
- [Certificates and HTTPS](../certificates-https/) expands on X.509 chains, SAN validation, SNI, CA stores, Ubuntu trust-store operations, and certificate troubleshooting.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a completed TCP handshake prove?" answer="Only that both endpoints exchanged SYN, SYN-ACK, and ACK; upper layers may still fail." %}
  {% include study-card.html question="Why does SNI matter?" answer="It lets a TLS server choose the correct certificate and virtual host for the requested name." %}
  {% include study-card.html question="Why use curl -v after openssl s_client?" answer="openssl isolates TLS details, while curl exercises HTTP behavior, redirects, headers, and application response." %}
  {% include study-card.html question="Why can retries make an outage worse?" answer="Retries add extra load and can duplicate unsafe operations unless bounded, jittered, and idempotent." %}
</div>

## References

- [RFC 9293: Transmission Control Protocol](https://www.rfc-editor.org/rfc/rfc9293)
- [RFC 8446: The Transport Layer Security Protocol Version 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
