---
title: Resilience, Timeouts, and Draining
layout: page
permalink: /docs/networking/resilience-timeouts-draining/
summary: "Practical network resilience patterns: timeout budgets, retries, backoff, connection pooling, keepalive, idle timeouts, load balancer draining, rolling restarts, DNS TTLs, and zero-downtime deploy behavior."
tags:
  - networking
  - resilience
  - troubleshooting
  - zero-downtime
---

# Resilience, Timeouts, and Draining

Zero-downtime behavior is mostly a contract between clients, load balancers, proxies, applications, orchestrators, and DNS. Linux keepalive settings, proxy idle timers, Kubernetes readiness, connection pool behavior, and retry policy all participate.

## First Checks

```bash
curl -v --connect-timeout 3 --max-time 15 https://api.example.com/health
ss -tan state established '( dport = :443 or sport = :443 )'
sysctl net.ipv4.tcp_keepalive_time
kubectl get deploy,pod,endpointslice -A -o wide
kubectl rollout status deploy/api
```

## Timeout Budget

Every hop needs explicit timeouts. The outer caller should usually wait slightly longer than the inner dependency budget, but the total user-facing deadline must still be bounded.

```text
client total deadline
  > edge proxy request timeout
    > service request timeout
      > dependency connect + TLS + query timeout
```

Bad patterns:

- no client deadline,
- proxy timeout shorter than normal backend work,
- database timeout longer than user request deadline,
- TCP keepalive expected to detect failures faster than application timeouts,
- retries that reset the budget at every hop.

## Timeout-Budget Calculator

Use a simple budget before changing defaults:

```text
user deadline = queue wait + client connect + TLS + proxy + service work + DB work + response write + retry slack
```

Example:

| Component | Budget |
| --- | --- |
| Client total deadline | 3000 ms |
| Queue wait | 100 ms |
| Connect + TLS | 300 ms |
| Edge proxy upstream timeout | 2500 ms |
| Service handler deadline | 2000 ms |
| Database query timeout | 1200 ms |
| Retry slack | one retry only if the first failure happens before 1000 ms |

The database timeout must be shorter than the service handler deadline, and the service handler deadline must be shorter than the proxy/client deadline. Otherwise abandoned work continues after the caller has already failed.

## Retries, Backoff, and Idempotency

Retries are load amplifiers unless they are bounded.

| Rule | Why It Matters |
| --- | --- |
| Retry only safe operations | Repeating non-idempotent writes can duplicate side effects. |
| Use exponential backoff with jitter | Prevents synchronized retry storms. |
| Set a total deadline | Stops retries from outliving the user request. |
| Use idempotency keys for writes | Lets the server deduplicate repeated attempts. |
| Observe retry counts | Hidden retries can mask partial outages until capacity collapses. |

Retry safety checklist:

```text
operation is idempotent or has an idempotency key
retry count is bounded
retry delay uses backoff with jitter
retry budget is part of the total deadline
circuit breaker or load-shedder prevents overload amplification
metrics expose attempts, successes after retry, and final failures
```

Circuit breakers are not a substitute for capacity. They stop callers from making a known-bad dependency worse while preserving the caller's own resources.

## Connection Pooling

Connection pools reduce handshake cost and protect backends from connection churn, but stale pooled connections can fail after proxy, NAT, or load balancer idle timeouts.

Practical checks:

```bash
ss -tan state established '( dport = :443 or sport = :443 )'
ss -tan state time-wait | wc -l
sysctl net.ipv4.tcp_keepalive_time
```

Set pool max lifetime and idle timeout shorter than infrastructure idle timeouts when possible. That makes clients retire connections deliberately instead of discovering stale sockets during a request.

## Keepalive and Idle Timeouts

TCP keepalive proves only that a peer still answers at the TCP layer. It does not prove HTTP routing, mTLS validity, authorization, or dependency health.

Align these timers:

| Layer | Timer |
| --- | --- |
| Client | connect, TLS handshake, read, write, total deadline. |
| Proxy / LB | idle timeout, upstream timeout, drain timeout. |
| App server | request timeout, graceful shutdown timeout. |
| Kernel | TCP keepalive, FIN wait, TIME_WAIT behavior. |
| NAT / firewall | TCP and UDP idle timeouts, conntrack lifetime. |

## Load Balancer Draining

Draining means stop sending new traffic to an instance while allowing in-flight work to finish.

```mermaid
flowchart LR
  A[mark not ready] --> B[EndpointSlice removes endpoint]
  B --> C[LB/proxy stops new traffic]
  C --> D[in-flight requests finish]
  D --> E[SIGTERM grace period ends]
  E --> F[container exits]
```

Kubernetes shape:

```yaml
spec:
  replicas: 3
  strategy:
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
template:
  spec:
    terminationGracePeriodSeconds: 60
    containers:
      - name: app
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
```

The app should fail readiness before it stops accepting new work, keep serving existing requests until the grace period, close listeners deliberately, and handle SIGTERM. The load balancer also needs enough deregistration delay to stop routing to terminating endpoints.

## DNS TTLs and Cutovers

DNS is not a drain mechanism by itself. Caches can keep using old answers until TTL expiry, and clients may cache beyond DNS TTL through connection pools.

For planned cutovers:

1. Lower TTL before the old value is cached by clients.
2. Stand up both old and new targets.
3. Shift traffic gradually when the load balancer or DNS provider supports it.
4. Keep old endpoints serving through the maximum realistic cache and connection lifetime.
5. Monitor old endpoint traffic before removing it.

## Zero-Downtime Deploy Checklist

```text
minimum two ready replicas per failure domain
readiness reflects real ability to serve
startupProbe protects slow boot from premature restarts
preStop and SIGTERM drain cleanly
maxUnavailable and maxSurge allow movement
PDB permits voluntary disruption without blocking all rollout progress
LB health checks match readiness path and Host/SNI needs
client retries are bounded and idempotent where needed
connection pool idle/lifetime aligns with LB idle timeout
DNS TTL and old endpoint retention are planned
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why are retries dangerous without a budget?" answer="They can amplify load and continue after the caller no longer needs the result." %}
  {% include study-card.html question="What is load balancer draining?" answer="Stopping new traffic to a backend while allowing in-flight requests to finish before shutdown." %}
  {% include study-card.html question="Why is DNS not enough for zero-downtime cutover?" answer="Resolvers and clients may cache old answers or keep existing connections beyond the DNS TTL." %}
</div>

## References

- [Load Balancers and Proxies](/docs/networking/load-balancers-proxies/)
- [TCP and Sockets](/docs/networking/tcp-sockets/)
- [Kubernetes Ingress, Gateway, and Load Balancers](/docs/kubernetes/ingress-gateway-load-balancers/)
- [Istio Zero Downtime Upgrades on Kubernetes](/docs/istio/zero-downtime-upgrades/)
