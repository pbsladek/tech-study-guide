---
title: Istio Service Mesh
layout: page
permalink: /docs/istio/service-mesh/
summary: "Service mesh architecture, request paths, Envoy sidecars, ambient ztunnel and waypoint proxies, mTLS, policy, telemetry, and troubleshooting."
tags:
  - istio
  - service-mesh
  - envoy
  - mtls
---

# Istio Service Mesh

A service mesh moves cross-cutting network behavior into infrastructure. Instead of every service implementing retries, mTLS, metrics, tracing, routing, circuit breaking, and policy, the mesh handles those concerns in proxies controlled by a shared control plane.

## Request Path Checks

```bash
istioctl proxy-status
istioctl proxy-config routes <pod> -n <namespace>
istioctl proxy-config clusters <pod> -n <namespace>
istioctl ztunnel-config workloads -n <namespace>
kubectl logs -n istio-system deploy/istiod
kubectl logs -n istio-system -l app=ztunnel
```

## What Changes With a Mesh

Without a mesh, service A connects directly to service B through Kubernetes networking. With a mesh, traffic is intercepted and policy-aware proxies participate in the path. The proxy can identify the source workload, enforce mTLS, emit telemetry, route by L7 metadata, and reject unauthorized requests.

## Sidecar Mode

Sidecar mode runs Envoy in each participating workload pod. Traffic redirection sends inbound and outbound workload traffic through Envoy. This mode gives mature L7 functionality close to the workload, but introduces sidecar injection, proxy resource sizing, startup ordering, and upgrade coordination.

## Ambient Mode

Ambient mode uses a layered model:

- ztunnel: per-node L4 proxy providing secure overlay, mTLS, identity, L4 authorization, and TCP telemetry,
- waypoint proxy: optional Envoy proxy used for L7 routing, HTTP authorization, metrics, and richer policy.

This model reduces per-pod overhead and can be adopted namespace by namespace, but operators must know whether a feature is enforced by ztunnel, waypoint, gateway, or sidecar.

## mTLS and Identity

Istio workload identity is usually based on SPIFFE-style identities and X.509 certificates. PeerAuthentication controls mTLS mode. AuthorizationPolicy controls what authenticated identities may do. RequestAuthentication handles end-user JWTs.

Important split:

- mTLS authenticates service-to-service identity,
- AuthorizationPolicy decides whether a request is allowed,
- RequestAuthentication validates user or client tokens,
- Gateway TLS controls edge certificate presentation and termination.

## Debugging Split

| Symptom | First Area |
| --- | --- |
| Pod has no proxy | injection label, ambient enrollment, CNI, namespace labels. |
| Proxy not synced | istiod, xDS, network reachability, version skew. |
| 503 or no healthy upstream | Service endpoints, DestinationRule, subsets, mTLS mismatch. |
| 404 or wrong route | Gateway host, VirtualService hosts, match order, HTTP path. |
| TLS failure | Gateway credential, SNI, PeerAuthentication, DestinationRule TLS mode. |
| Denied request | AuthorizationPolicy, principal, namespace, path, method, JWT claims. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What problem does a service mesh solve?" answer="It centralizes cross-cutting traffic, security, and telemetry behavior outside application code." %}
  {% include study-card.html question="What is ztunnel in Istio ambient mode?" answer="A per-node L4 proxy that provides secure overlay, mTLS, identity, L4 policy, and TCP telemetry." %}
  {% include study-card.html question="When do you need a waypoint proxy?" answer="When ambient workloads need L7 features such as HTTP routing, L7 authorization, access logs, or HTTP metrics." %}
</div>

## References

- [Istio ambient overview](https://istio.io/latest/docs/ambient/overview/)
- [Istio ambient data plane](https://istio.io/latest/docs/ambient/architecture/data-plane/)
- [Istio waypoint proxies](https://istio.io/latest/docs/ambient/usage/waypoint/)
- [Istio PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/)
- [Istio authorization tasks](https://istio.io/latest/docs/tasks/security/authorization/)
