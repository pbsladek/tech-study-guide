---
title: Forward and Reverse Proxies
layout: page
permalink: /docs/networking/proxies-forward-reverse/
summary: "Forward proxies, reverse proxies, CONNECT tunnels, transparent proxies, TLS interception, proxy headers, egress control, caching, environment variables, and troubleshooting."
tags:
  - networking
  - proxy
  - http
  - troubleshooting
---

# Forward and Reverse Proxies

A proxy is an intermediary that receives traffic from one side and creates or forwards traffic on the other side. The word is broad: a browser proxy, egress proxy, reverse proxy, service mesh sidecar, TLS-terminating gateway, and caching proxy all change the path in different ways.

## First Checks

```bash
env | grep -i proxy
curl -v --proxy http://proxy.example:3128 https://example.com/
curl -v --noproxy '*' https://example.com/
openssl s_client -proxy proxy.example:3128 -connect example.com:443 -servername example.com
dig proxy.example
tcpdump -nn -i any host proxy.example
```

Use these checks to prove whether the client is using a proxy, whether the proxy can resolve and connect, and whether TLS is end-to-end or intercepted.

## Forward Versus Reverse Proxy

| Type | Client Thinks It Talks To | Proxy Usually Protects |
| --- | --- | --- |
| Forward proxy | An external origin server through a configured proxy. | Clients and egress policy. |
| Reverse proxy | The service name or public endpoint. | Backend services and ingress policy. |
| Transparent proxy | The original destination, with interception in the path. | Policy enforcement without explicit client config. |
| SOCKS proxy | A generic TCP endpoint through a proxy protocol. | Application egress without HTTP semantics. |

Forward proxies are common for corporate egress, package downloads, controlled internet access, and audit. Reverse proxies are common for ingress, TLS termination, request routing, compression, caching, and backend protection. A transparent proxy sits in the path without explicit client proxy configuration, which can make failures harder to explain from the client alone.

## CONNECT Tunnels

HTTP `CONNECT` asks a proxy to open a TCP tunnel to a target host and port. It is commonly used so a client can run TLS through an explicit HTTP proxy. After the tunnel is established, the proxy may blindly forward bytes, or in a TLS inspection environment it may terminate and reissue TLS with an enterprise root CA.

Security implications:

- proxies should restrict CONNECT destinations and ports,
- proxy authentication applies to the proxy hop, not the origin server,
- TLS inspection requires client trust in the inspecting CA,
- SNI, certificate SANs, and Host routing can still fail after CONNECT succeeds.

## Proxy Configuration

Many command-line tools use environment variables:

| Variable | Purpose |
| --- | --- |
| `HTTP_PROXY` / `http_proxy` | Proxy for HTTP URLs. |
| `HTTPS_PROXY` / `https_proxy` | Proxy for HTTPS URLs, often using CONNECT. |
| `NO_PROXY` / `no_proxy` | Destinations that should bypass the proxy. |

`NO_PROXY` behavior is not perfectly consistent across tools. Test the exact client when bypass rules matter for metadata services, cluster services, internal domains, or RFC1918 ranges.

## Headers and Client Identity

Reverse proxies often add headers to preserve original request context:

| Header or Protocol | Purpose |
| --- | --- |
| `Forwarded` | Standardized client/proxy metadata header. |
| `X-Forwarded-For` | Common de facto client IP chain header. |
| `X-Forwarded-Proto` | Original scheme such as `https`. |
| `X-Forwarded-Host` | Original Host value. |
| PROXY protocol | L4 preface carrying source and destination metadata. |

Trust forwarding headers only from known proxy hops that sanitize inbound client-supplied values. Otherwise a client can forge its own source IP or scheme.

## TLS Patterns

| Pattern | What Happens |
| --- | --- |
| TLS passthrough | Proxy routes without decrypting application payload. |
| TLS termination | Proxy decrypts client TLS and forwards plaintext or a new upstream TLS connection. |
| TLS re-encryption | Proxy terminates client TLS and starts separate TLS to the backend. |
| TLS interception | Forward proxy terminates and reissues TLS using a trusted local CA. |

TLS changes where certificates, SNI, ALPN, HTTP version negotiation, and client certificate authentication are checked. A backend might be healthy directly while failing through a proxy because the proxy changes Host, SNI, scheme, or client certificate behavior.

## Caching, Auth, and Egress Control

Forward proxies can cache content, require authentication, restrict destinations, log requests, and enforce data-loss controls. Reverse proxies can cache responses, rate-limit clients, enforce auth, and absorb slow clients.

Operational failure modes:

- stale cached content or negative cache entries,
- proxy auth challenge not supported by the client,
- package managers using different proxy settings than shells,
- no-proxy bypass too broad or too narrow,
- CONNECT blocked for non-standard ports,
- idle timeout shorter than application request time,
- proxy DNS view differs from client DNS view.

## Troubleshooting Flow

1. Confirm whether the client is explicitly configured, transparently intercepted, or direct.
2. Compare proxied and direct behavior with `curl --proxy` and `curl --noproxy`.
3. Check proxy DNS resolution separately from client DNS resolution.
4. Separate TCP connection, CONNECT tunnel, TLS handshake, and HTTP response.
5. Inspect forwarding headers and PROXY protocol only at trusted proxy boundaries.
6. Check timeout, body-size, header-size, auth, and cache policy.
7. Capture on client, proxy, and backend sides when possible.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is a forward proxy?" answer="A proxy configured by or placed in front of clients to control and observe outbound traffic to origin servers." %}
  {% include study-card.html question="What is a reverse proxy?" answer="A proxy that clients reach as the service endpoint while it routes to backend services." %}
  {% include study-card.html question="What does HTTP CONNECT do?" answer="It asks a proxy to establish a TCP tunnel to the requested host and port." %}
  {% include study-card.html question="Why is NO_PROXY tricky?" answer="Bypass matching differs across clients, so internal domains, CIDRs, and metadata endpoints must be tested with the actual tool." %}
</div>

## References

- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 7239: Forwarded HTTP Extension](https://www.rfc-editor.org/rfc/rfc7239)
- [NGINX reverse proxy documentation](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [HAProxy PROXY protocol](https://www.haproxy.org/download/2.9/doc/proxy-protocol.txt)
