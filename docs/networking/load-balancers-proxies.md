---
title: Load Balancers and Proxies
layout: page
permalink: /docs/networking/load-balancers-proxies/
summary: "L4 and L7 load balancing, reverse proxies, health checks, TLS termination, source IP preservation, PROXY protocol, headers, and timeout failures."
tags:
  - networking
  - load-balancing
  - troubleshooting
---

# Load Balancers and Proxies

Load balancers and proxies are network devices, application infrastructure, and failure domains at the same time. They can fix availability problems, hide backend churn, terminate TLS, change source addresses, retry requests, and introduce their own timeout and protocol behavior.

## First Checks

```bash
curl -v https://example.com/
curl -vk --resolve example.com:443:198.51.100.10 https://example.com/
openssl s_client -connect example.com:443 -servername example.com
dig example.com A
ss -tan state established
tcpdump -nn -i any host 198.51.100.10
```

## L4 Versus L7

Layer 4 load balancers make decisions mostly from IP addresses, ports, and connection metadata. Layer 7 proxies understand application protocols such as HTTP and can route on Host, path, headers, methods, cookies, or protocol-specific data.

The distinction matters because a TCP connection can succeed while an L7 proxy rejects the request for Host, SNI, HTTP version, header size, body size, authentication, or route configuration.

## Health Checks

Health checks are only as good as what they check. A TCP check proves a port accepted a connection. An HTTP check proves one configured path returned an expected result. Neither automatically proves database connectivity, authorization, cache health, or the exact user path.

Common mistakes:

- check path differs from real traffic path,
- health check ignores Host or SNI requirements,
- backend passes shallow checks while dependencies fail,
- intervals and thresholds create slow failover,
- all backends fail because the health check itself is broken.

## Source IP and Headers

Proxies often replace the original source IP at the backend. Applications may need `X-Forwarded-For`, `Forwarded`, or the PROXY protocol to recover client identity. Trust those headers only from known proxies; clients can forge them if the edge does not sanitize input.

## TLS Termination and SNI

TLS can terminate at the edge proxy, pass through to backends, or re-encrypt between proxy and backend. SNI lets a proxy choose a certificate or route before HTTP is visible. A mismatch between DNS name, SNI, certificate SAN, and backend Host routing is a common outage pattern.

## Timeout Budget

Every hop has timeouts:

- client connect and read timeout,
- load balancer idle timeout,
- proxy upstream timeout,
- backend server timeout,
- database or dependency timeout,
- keepalive reuse limits.

Timeouts should form a deliberate budget. If an outer timeout is shorter than an inner timeout, clients may see failures while backends keep working on abandoned requests.

## Troubleshooting Flow

1. Test DNS, TCP, TLS, and HTTP separately.
2. Compare direct backend behavior with load-balanced behavior.
3. Verify health checks use realistic Host, SNI, path, and protocol settings.
4. Inspect source IP preservation and forwarding headers.
5. Check idle, connect, read, and upstream timeouts at every hop.
6. Check whether retries are safe for non-idempotent requests.
7. Capture on client side, proxy side, and backend side when possible.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What can an L7 proxy route on?" answer="Application data such as HTTP Host, path, headers, methods, cookies, or protocol-specific fields." %}
  {% include study-card.html question="Why are shallow health checks risky?" answer="They can mark a backend healthy even when dependencies or the real request path are broken." %}
  {% include study-card.html question="Why should forwarding headers be trusted only from known proxies?" answer="Clients can forge headers such as X-Forwarded-For unless the edge proxy sanitizes them." %}
</div>

## References

- [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
- [RFC 8446: TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 7239: Forwarded HTTP Extension](https://www.rfc-editor.org/rfc/rfc7239)
- [HAProxy PROXY protocol](https://www.haproxy.org/download/2.9/doc/proxy-protocol.txt)
- [NGINX reverse proxy documentation](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
