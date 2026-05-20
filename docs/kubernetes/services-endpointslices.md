---
title: Kubernetes Services and EndpointSlices
layout: page
permalink: /docs/kubernetes/services-endpointslices/
summary: "Service types, selectors, ClusterIP, NodePort, LoadBalancer, headless Services, EndpointSlices, kube-proxy, readiness, and service debugging."
tags:
  - kubernetes
  - networking
  - services
---

# Kubernetes Services and EndpointSlices

Services decouple clients from changing Pods. The Service object defines a stable frontend; EndpointSlices describe the current backend endpoints. The datapath is then implemented by kube-proxy or a replacement such as an eBPF-based CNI datapath.

## First Checks

```bash
kubectl get svc <service> -o wide
kubectl describe svc <service>
kubectl get endpointslice -l kubernetes.io/service-name=<service>
kubectl get pods -l <selector> -o wide
kubectl describe pod <pod>
kubectl get events --sort-by=.lastTimestamp
```

## Service Object

The Service defines:

- selector labels,
- port and protocol,
- `targetPort`,
- type such as `ClusterIP`, `NodePort`, `LoadBalancer`, or `ExternalName`,
- optional session affinity,
- traffic policy fields such as `externalTrafficPolicy` and `internalTrafficPolicy`.

Selector drift is a common outage. A Service can exist, have a ClusterIP, and still have no usable backends if labels do not match ready Pods.

## EndpointSlices

EndpointSlices are the scalable backend source of truth for Services. They group endpoints by address family, protocol, port, and Service. Endpoint conditions include readiness and terminating state, which affects whether Service traffic should be sent to a Pod.

Operational details:

- EndpointSlices are normally created for selector-based Services.
- Ready endpoints usually map to Pods passing readiness.
- Headless Services publish endpoint records directly.
- Dual-stack Services may have separate EndpointSlices by address family.
- Older Endpoints objects are not the main scalability path.

## kube-proxy and Service Virtual IPs

For non-ExternalName Services, kube-proxy implements virtual IP behavior by watching Services and EndpointSlices. Depending on cluster mode, that implementation may use iptables, IPVS, nftables, eBPF, or a CNI-integrated datapath.

Debugging implication: the API object can be correct while the node datapath is stale, missing rules, or blocked by host firewall policy.

## LoadBalancer and NodePort Details

`NodePort` opens a port on nodes. `LoadBalancer` asks infrastructure integration to publish an external address and point it at the Service. On bare metal this requires something like MetalLB or another controller.

`externalTrafficPolicy: Local` can preserve client source IP, but it only sends traffic to nodes with local ready endpoints. That improves source visibility but can create uneven traffic and black holes if health checks do not account for local endpoints.

## Debugging Flow

1. Confirm the Service selector matches the intended Pods.
2. Confirm Pods are Ready and expose the expected container port.
3. Inspect EndpointSlices and endpoint conditions.
4. Test the Service name and ClusterIP from a debug Pod.
5. Test direct Pod IP only to isolate Service datapath from workload behavior.
6. Check kube-proxy or CNI datapath logs on affected nodes.
7. For LoadBalancer, check external address assignment, health checks, node ports, and source IP policy.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What do EndpointSlices represent?" answer="The current backend network endpoints for a Service, grouped by address family, protocol, port, and Service." %}
  {% include study-card.html question="Why can a Service have no usable backends?" answer="Its selector may not match Pods, the Pods may not be Ready, or endpoint conditions may exclude them." %}
  {% include study-card.html question="What is a risk of externalTrafficPolicy: Local?" answer="Traffic only goes to nodes with local ready endpoints, so health checks and endpoint placement matter." %}
</div>

## References

- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- [Virtual IPs and Service Proxies](https://kubernetes.io/docs/reference/networking/virtual-ips/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
