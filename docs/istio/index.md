---
title: Istio
layout: page
permalink: /docs/istio/
summary: "Istio service mesh fundamentals: control plane, data plane, sidecar mode, ambient mode, traffic management, security, observability, and operations."
tags:
  - istio
  - kubernetes
  - service-mesh
  - networking
---

# Istio

Istio is a Kubernetes-centered service mesh that adds traffic management, service identity, mutual TLS, policy, telemetry, and gateway capabilities without requiring every application to implement those features itself.

## Core Checks

```bash
istioctl version
istioctl proxy-status
istioctl analyze --all-namespaces
kubectl get pods -n istio-system
kubectl get gateway,virtualservice,destinationrule --all-namespaces
kubectl get peerauthentication,authorizationpolicy --all-namespaces
```

## Mental Model

| Layer | Role |
| --- | --- |
| Control plane | Watches Kubernetes and Istio config, computes desired proxy configuration, and distributes it. |
| Data plane | Proxies that actually handle traffic. In sidecar mode this is Envoy beside each workload. In ambient mode this is ztunnel plus optional waypoint proxies. |
| Traffic APIs | Gateway, VirtualService, DestinationRule, ServiceEntry, Sidecar, and related resources. |
| Security APIs | PeerAuthentication, RequestAuthentication, AuthorizationPolicy, and certificate/trust configuration. |
| Telemetry | Metrics, logs, traces, and access logs emitted by proxies and control-plane components. |

## xDS and Envoy Configuration

Istio's control plane computes Envoy configuration and sends it to data-plane proxies through xDS APIs. The application does not normally know this happened; traffic changes because the proxy received new listeners, routes, clusters, endpoints, and secrets.

| xDS Area | What It Represents |
| --- | --- |
| Listener | Where Envoy accepts traffic and which filter chain handles it. |
| Route | HTTP host, path, header, and weighted routing decisions. |
| Cluster | Upstream service or endpoint group Envoy can send traffic to. |
| Endpoint | Concrete backend IPs and ports for a cluster. |
| Secret | TLS certificates and validation material. |

This is why mesh troubleshooting compares Kubernetes objects, Istio config, and proxy config. A VirtualService can look correct while a proxy has not received it, or a proxy can have correct config while the application itself returns errors.

## Sidecar and Ambient Modes

Sidecar mode injects an Envoy proxy into workload pods. It gives rich L7 features at the pod boundary but adds sidecar resource overhead and injection lifecycle concerns.

Ambient mode avoids per-pod sidecars. It uses a per-node L4 ztunnel secure overlay and optional waypoint proxies for L7 features. That split lets teams adopt mTLS and basic policy first, then add L7 routing, authorization, and telemetry where needed.

## Traffic Management

Istio traffic management is not the same as Kubernetes Services. Kubernetes selects endpoints. Istio can add routing by host/header/path, weighted traffic splits, retries, timeouts, fault injection, locality preferences, circuit breaking, and TLS origination.

## Security

Istio can issue workload identities and certificates, enforce mTLS, validate JWTs, and apply authorization policies. In practice, the hardest parts are usually trust boundaries, policy scope, namespace labels, gateway TLS mode, and understanding whether a policy applies at L4 or L7.

## Operations Runbook

1. Confirm Istio version and install profile.
2. Confirm whether the namespace uses sidecar injection or ambient enrollment.
3. Run `istioctl analyze --all-namespaces`.
4. Check proxy readiness and sync state.
5. Inspect VirtualService, DestinationRule, Gateway, PeerAuthentication, and AuthorizationPolicy.
6. Confirm mTLS mode and certificate trust.
7. Compare Kubernetes Service endpoints with Istio routing rules.
8. Use access logs and metrics to separate routing, TLS, authz, and application failures.

## Service Mesh

See [Istio Service Mesh](service-mesh/) for deeper coverage of why service meshes exist, what changes in the request path, and how to reason about sidecars, ambient, ztunnel, waypoints, Envoy, mTLS, and policy.

## Practice Deck

{% include study-card-deck.html deck="istio" %}

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is Istio's control plane responsible for?" answer="It watches platform and mesh configuration, computes desired proxy configuration, and distributes it to the data plane." %}
  {% include study-card.html question="What is the difference between sidecar and ambient mode?" answer="Sidecar mode runs Envoy in each workload pod; ambient mode uses ztunnel plus optional waypoint proxies." %}
  {% include study-card.html question="Why inspect xDS config during mesh troubleshooting?" answer="The proxy behavior comes from received listeners, routes, clusters, endpoints, and secrets, not just from the YAML you applied." %}
  {% include study-card.html question="What is the split between Kubernetes Services and Istio routing?" answer="Kubernetes selects endpoints; Istio can add host, path, header, TLS, retry, timeout, and traffic-split behavior." %}
</div>

## References

- [Istio: What is Istio?](https://istio.io/latest/docs/overview/what-is-istio/)
- [Istio traffic management concepts](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio security concepts](https://istio.io/latest/docs/concepts/security/)
- [Istio observability concepts](https://istio.io/latest/docs/concepts/observability/)
- [Istio ambient overview](https://istio.io/latest/docs/ambient/overview/)
