---
title: Istio Observability and Troubleshooting
layout: page
permalink: /docs/istio/observability-troubleshooting/
summary: "Istio metrics, access logs, traces, proxy sync, xDS inspection, response flags, common 503 and policy failures, and practical debugging flows."
tags:
  - istio
  - observability
  - troubleshooting
  - envoy
---

# Istio Observability and Troubleshooting

Istio troubleshooting is about comparing intended configuration with proxy behavior and observed traffic. Kubernetes objects, Istio resources, xDS config, Envoy access logs, metrics, and application logs each answer different questions.

## Signals

| Signal | What It Answers |
| --- | --- |
| `istioctl analyze` | Is mesh config internally inconsistent or invalid? |
| Proxy sync | Did proxies receive current xDS from istiod? |
| Proxy config | What listeners, routes, clusters, endpoints, and secrets are active? |
| Access logs | What happened to individual requests at the proxy? |
| Metrics | Where are latency, volume, errors, and saturation changing? |
| Traces | Which service hop consumed time or returned an error? |

## Core Commands

```bash
istioctl version
istioctl proxy-status
istioctl analyze --all-namespaces
istioctl proxy-config listeners <pod> -n <namespace>
istioctl proxy-config routes <pod> -n <namespace>
istioctl proxy-config clusters <pod> -n <namespace>
istioctl proxy-config endpoints <pod> -n <namespace>
istioctl proxy-config secret <pod> -n <namespace>
kubectl logs -n istio-system deploy/istiod
```

Ambient mode adds ztunnel and waypoint checks:

```bash
istioctl ztunnel-config workloads -n <namespace>
istioctl ztunnel-config services -n <namespace>
istioctl waypoint list -A
kubectl logs -n istio-system -l app=ztunnel
```

## Response Pattern Triage

| Symptom | Likely Area |
| --- | --- |
| 404 at gateway | Host/path mismatch, route order, wrong Gateway attachment. |
| 503 no healthy upstream | Endpoint, subset, DestinationRule, mTLS, readiness, or outlier ejection issue. |
| 403 from proxy | AuthorizationPolicy, JWT requirement, principal mismatch, or deny policy. |
| TLS handshake failure | Secret, SNI, certificate chain, PeerAuthentication, or TLS mode mismatch. |
| Proxy not synced | istiod reachability, version skew, invalid config, or overloaded control plane. |
| Works from pod but not gateway | Gateway listener, route host, TLS, AuthorizationPolicy, or external load balancer. |

## xDS Inspection

xDS names are often verbose, but the pattern is predictable:

- listeners show where Envoy accepts traffic,
- routes show HTTP match and destination decisions,
- clusters show upstream service definitions and TLS settings,
- endpoints show concrete backend IPs,
- secrets show certificates and validation context.

If a VirtualService was applied but routes do not show it, check hosts, export visibility, namespace, gateway binding, and analyzer output. If routes are right but endpoints are empty, check Kubernetes Service selectors, EndpointSlices, subsets, and workload readiness.

## Access Logs and Metrics

Access logs are useful when they include response code, response flags, upstream host, authority, route name, duration, and source identity. Metrics show whether the issue is isolated or systemic.

Common metric questions:

- Which service saw error-rate change first?
- Did request volume spike before latency?
- Are 4xx policy denials or 5xx upstream failures?
- Is the problem isolated to one source, destination, route, or revision?
- Did a rollout or config change precede the shift?

## Practical Debug Flow

1. Reproduce with a single request and capture host, path, headers, source pod, destination, and response.
2. Check `istioctl analyze --all-namespaces`.
3. Confirm proxy sync for the source, destination, gateway, waypoint, or ztunnel.
4. Inspect the proxy config at the enforcement point.
5. Check access logs for response flags and upstream host.
6. Compare with Kubernetes endpoints and application logs.
7. Roll back or narrow the last mesh config change if evidence points to it.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does istioctl proxy-status show?" answer="Whether data-plane proxies are connected to istiod and synchronized with current xDS configuration." %}
  {% include study-card.html question="What does an empty endpoint list usually suggest?" answer="Kubernetes endpoints, subset labels, readiness, or service selection are not producing usable backends." %}
  {% include study-card.html question="Why are access logs useful in Istio?" answer="They show per-request response codes, flags, upstreams, durations, and route behavior at the proxy." %}
  {% include study-card.html question="Why compare YAML with proxy config?" answer="Applied resources are intent; proxy config shows what Envoy actually received and enforces." %}
  {% include study-card.html question="What should you inspect for a proxy-generated 403?" answer="AuthorizationPolicy, RequestAuthentication, source principal, JWT claims, namespace scope, and deny policies." %}
</div>

## References

- [Istio observability concepts](https://istio.io/latest/docs/concepts/observability/)
- [Istio troubleshooting](https://istio.io/latest/docs/ops/common-problems/)
- [istioctl command reference](https://istio.io/latest/docs/reference/commands/istioctl/)
- [Envoy response flags in Istio](https://istio.io/latest/docs/ops/common-problems/network-issues/)
- [Istio proxy configuration debugging](https://istio.io/latest/docs/ops/diagnostic-tools/proxy-cmd/)
