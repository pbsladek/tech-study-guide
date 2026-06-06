---
title: HTTP and Proxy Debugging
layout: page
permalink: /docs/networking/http-proxy-debugging/
summary: "Practical HTTP and proxy debugging with curl, headers, redirects, keepalive, chunking, HTTP/2, gRPC, WebSockets, proxy variables, and timeout alignment."
tags:
  - networking
  - http
  - proxy
  - tls
  - troubleshooting
---

# HTTP and Proxy Debugging

HTTP failures can sit above a healthy TCP and TLS path. Debugging requires separating DNS, TCP, TLS, proxy selection, request headers, routing, application status, connection reuse, protocol version, and timeout behavior.

## Command Examples

```bash
curl -v https://api.example.com/healthz
curl -vk --resolve api.example.com:443:203.0.113.10 https://api.example.com/healthz
curl -v --http1.1 https://api.example.com/
curl -v --http2 https://api.example.com/
env | grep -i proxy
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `curl -v https://api.example.com/healthz` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `curl -vk --resolve api.example.com:443:203.0.113.10 https://api.example.com/healthz` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `curl -v --http1.1 https://api.example.com/` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |

`curl -v` exposes DNS choice, TCP connection, TLS handshake, ALPN, request headers, response headers, redirects, and connection reuse.

## Request Anatomy

| Layer | Evidence |
| --- | --- |
| DNS | resolved address, A/AAAA choice, split-horizon result. |
| TCP | connect success, resets, timeouts. |
| TLS | SNI, certificate chain, ALPN, protocol version. |
| HTTP | method, path, host, headers, status, body. |
| Proxy | CONNECT tunnel, forwarded headers, proxy auth, egress policy. |
| App | route match, auth, upstream dependency, error body. |

Do not jump from HTTP `503` to "network problem" without checking which proxy or upstream generated it.

## Headers and Redirects

Useful commands:

```bash
curl -I https://api.example.com/
curl -v -L https://api.example.com/login
curl -H 'Host: api.example.com' http://203.0.113.10/
curl -H 'X-Request-ID: debug-123' https://api.example.com/
```

Headers to inspect:

| Header | Why It Matters |
| --- | --- |
| `Host` | L7 routing and virtual hosts. |
| `X-Forwarded-For` | Original client chain when proxies preserve it. |
| `X-Forwarded-Proto` | Whether app thinks request was HTTP or HTTPS. |
| `Forwarded` | Standardized forwarding metadata. |
| `Location` | Redirect target and scheme. |
| `Connection` | Keepalive and hop-by-hop behavior. |
| `Transfer-Encoding` | Chunked body behavior. |

Redirect loops often come from wrong `X-Forwarded-Proto`, TLS termination mismatch, or app base URL configuration.

## HTTP Versions

| Version | Operational Notes |
| --- | --- |
| HTTP/1.1 | Text framing, keepalive, chunked transfer, head-of-line per connection. |
| HTTP/2 | Multiplexed streams over one connection, binary framing, ALPN negotiation. |
| HTTP/3 | QUIC over UDP, different middlebox and capture behavior. |
| gRPC | Usually HTTP/2 with status in trailers and long-lived streams. |
| WebSockets | HTTP upgrade to a long-lived bidirectional stream. |

Force versions when isolating protocol-specific failures:

```bash
curl -v --http1.1 https://api.example.com/
curl -v --http2 https://api.example.com/
```

## Proxy Environment Variables

Many CLI tools obey proxy environment variables:

```bash
env | grep -iE 'http_proxy|https_proxy|no_proxy'
curl -v --noproxy '*' https://api.example.com/
curl -v -x http://proxy.example.com:3128 https://api.example.com/
```

`NO_PROXY` matching varies by tool. CIDRs, leading dots, wildcard behavior, and ports are not handled consistently everywhere.

## CONNECT, TLS Interception, and mTLS

For HTTPS through an HTTP proxy, the client usually sends `CONNECT host:443`, then negotiates TLS through the tunnel. TLS-intercepting proxies terminate and reissue certificates, which changes the trust boundary.

Risks:

- mTLS fails because the proxy cannot present the client certificate end-to-end.
- ALPN or HTTP/2 support changes.
- Certificate pinning fails.
- SNI or policy routing differs from direct traffic.

## Timeout Alignment

Every hop has timeouts: client, forward proxy, reverse proxy, load balancer, service mesh, app server, upstream client, and database client. Good timeout alignment makes each upstream and downstream boundary fail in the intended order.

Common mismatch:

```text
client timeout > load balancer idle timeout > app processing time
```

The middle hop closes an otherwise valid slow request, causing resets or `504` responses.

## Runbook

1. Reproduce with `curl -v` from the same network and namespace.
2. Force DNS target with `--resolve` to separate DNS from HTTP.
3. Compare HTTP/1.1 and HTTP/2.
4. Print proxy variables and test direct path with `--noproxy '*'`.
5. Inspect response headers to identify which hop generated the status.
6. Check redirects, forwarded headers, and scheme handling.
7. Align timeouts from client through every proxy and upstream.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does curl --resolve isolate?" answer="It forces a hostname to a specific IP while preserving the Host header and SNI name." %}
  {% include study-card.html question="Why can X-Forwarded-Proto cause redirect loops?" answer="The application may think HTTPS traffic arrived as HTTP and redirect back to HTTPS repeatedly." %}
  {% include study-card.html question="What does HTTP CONNECT do?" answer="It asks an HTTP proxy to open a TCP tunnel to a target host and port." %}
  {% include study-card.html question="Why can proxy TLS interception break mTLS?" answer="The proxy terminates TLS, so the original client certificate may not reach the upstream service end-to-end." %}
</div>

## References

- [curl everything](https://everything.curl.dev/)
- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 9113: HTTP/2](https://www.rfc-editor.org/rfc/rfc9113)
- [RFC 6455: WebSocket Protocol](https://www.rfc-editor.org/rfc/rfc6455)
