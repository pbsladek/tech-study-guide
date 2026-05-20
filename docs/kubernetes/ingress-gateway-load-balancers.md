---
title: Kubernetes Ingress, Gateway, and Load Balancers
layout: page
permalink: /docs/kubernetes/ingress-gateway-load-balancers/
summary: "Ingress controllers, Gateway API, Service LoadBalancers, health checks, TLS, SNI, source IP, externalTrafficPolicy, DNS, and edge troubleshooting."
tags:
  - kubernetes
  - ingress
  - gateway-api
  - networking
---

# Kubernetes Ingress, Gateway, and Load Balancers

External traffic crosses several ownership boundaries before it reaches a Pod: public DNS, cloud or bare-metal load balancer, node or proxy datapath, Ingress or Gateway controller, Service, EndpointSlice, CNI, and the workload. Debugging is faster when each boundary is tested separately.

## First Checks

```bash
kubectl get ingress,gateway,httproute --all-namespaces
kubectl describe ingress <name>
kubectl describe gateway <name>
kubectl get svc -A --field-selector spec.type=LoadBalancer
kubectl get endpointslice -l kubernetes.io/service-name=<service>
curl -vk https://<host>/
```

## Ingress

Ingress is a stable API for HTTP and HTTPS routing, but it does nothing without an Ingress controller. The controller watches Ingress objects and configures a proxy or load balancer. Controller-specific annotations are common and can materially change behavior.

Ingress failure points:

- no controller is installed or watching the class,
- `ingressClassName` does not match the controller,
- TLS Secret is missing or wrong namespace,
- Host or path rule does not match,
- backend Service has no ready endpoints,
- controller cannot publish status or provision infrastructure.

## Gateway API

Gateway API splits infrastructure ownership from route ownership. GatewayClass selects an implementation, Gateway represents an entry point, and Routes such as HTTPRoute attach application routing to Gateways.

Useful mental model:

- platform team owns GatewayClass and shared Gateways,
- app teams own Routes,
- status conditions explain attachment, listener, and route acceptance problems.

Gateway API is where much of the newer Kubernetes traffic-management work happens, while Ingress remains stable but limited.

## Service LoadBalancers

`type: LoadBalancer` needs an implementation outside the core Service object: cloud controller manager, MetalLB, appliance integration, or a custom controller. The Service status should show whether an external address was assigned.

Important details:

- health checks may target node ports, proxy Pods, or local endpoints,
- `externalTrafficPolicy: Local` can preserve source IP but requires local ready endpoints,
- cloud security groups or firewalls may block traffic before Kubernetes sees it,
- DNS may point at the wrong load balancer address during migrations.

## TLS, SNI, and Host Routing

TLS, SNI, and HTTP Host must align. A request can reach the right IP but fail because:

- client SNI does not match the certificate,
- certificate SAN does not include the requested host,
- Host header does not match a route,
- TLS terminates at a different layer than expected,
- backend protocol expects HTTP while the proxy speaks HTTPS, or the reverse.

## Troubleshooting Flow

1. Resolve the public name and confirm the load balancer address.
2. Test TCP and TLS to the external address with the expected SNI.
3. Check Ingress or Gateway status conditions.
4. Check controller logs and class selection.
5. Check the backend Service and EndpointSlices.
6. Check health checks and `externalTrafficPolicy`.
7. Test from inside the cluster to the backend Service.
8. Compare direct Service behavior with edge behavior.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why does an Ingress object do nothing by itself?" answer="An Ingress controller must watch it and configure the actual proxy or load balancer." %}
  {% include study-card.html question="What does Gateway API separate?" answer="Infrastructure entry points such as GatewayClass and Gateway from application-owned routes such as HTTPRoute." %}
  {% include study-card.html question="Why can source IP preservation cause traffic gaps?" answer="externalTrafficPolicy: Local sends only to nodes with local ready endpoints, so health checks and endpoint placement matter." %}
</div>

## References

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
