---
title: Istio Gateways, Ingress, and Egress
layout: page
permalink: /docs/istio/gateways-ingress-egress/
summary: "Istio ingress gateways, egress gateways, Kubernetes Gateway API, TLS termination and passthrough, SNI, external services, and gateway troubleshooting."
tags:
  - istio
  - gateway
  - ingress
  - egress
---

# Istio Gateways, Ingress, and Egress

Gateways are where mesh policy meets traffic entering or leaving the cluster. They combine Kubernetes service exposure, Envoy listener configuration, TLS certificates, route attachment, and upstream policy.

## Gateway Shapes

| Shape | Use |
| --- | --- |
| Ingress gateway | Accepts external traffic and routes it to services inside the mesh. |
| Egress gateway | Centralizes selected outbound traffic from mesh workloads. |
| Kubernetes Gateway API | Standard Kubernetes resources such as Gateway and HTTPRoute for traffic routing. |
| Istio Gateway API | Istio networking resources such as Gateway and VirtualService. |
| Waypoint proxy | Ambient L7 policy and routing gateway for enrolled workloads or services. |

Know which API owns the listener and which resource owns routes. Mixing Gateway API and Istio networking APIs can be valid, but only when attachment and hostnames are clear.

## Ingress Path

```bash
kubectl get svc,pod -n istio-system
kubectl get gateway,virtualservice --all-namespaces
kubectl get httproute,gateway --all-namespaces
istioctl proxy-config listeners deploy/<gateway-deploy> -n istio-system
istioctl proxy-config routes deploy/<gateway-deploy> -n istio-system
```

Check layers in order:

1. External DNS resolves to the load balancer.
2. Load balancer forwards to the gateway Service.
3. Gateway listener accepts the host, port, protocol, and TLS mode.
4. Route resource attaches to the gateway and matches host/path/header.
5. Destination service has healthy endpoints.
6. Destination policy permits the request.

## TLS Modes

| Mode | Meaning |
| --- | --- |
| Termination | Gateway presents a certificate and decrypts TLS before routing HTTP. |
| Passthrough | Gateway routes encrypted traffic based on SNI without decrypting it. |
| Mutual TLS | Gateway requires client certificates and validates them against configured trust. |
| Origination | Proxy starts TLS to an upstream service even if the downstream request is plaintext. |

Common failures are missing Kubernetes secrets, wrong secret namespace, SNI mismatch, certificate chain problems, and route hostnames that do not match the request authority.

```bash
kubectl get secret -n istio-system
openssl s_client -connect <host>:443 -servername <host> -showcerts
curl -vk --resolve <host>:443:<lb-ip> https://<host>/
istioctl proxy-config secret deploy/<gateway-deploy> -n istio-system
```

## Egress Control

Egress gateways can centralize outbound traffic for auditing, policy, static source IP, or firewall integration. ServiceEntry models the external service, DestinationRule controls TLS or subsets, and routing decides whether traffic goes through the egress gateway.

```bash
kubectl get serviceentry,destinationrule,virtualservice --all-namespaces
istioctl proxy-config clusters <pod> -n <namespace> | grep <external-host>
kubectl logs -n istio-system deploy/istio-egressgateway
```

Be careful with wildcard hosts and DNS. A broad egress rule can accidentally allow more traffic than intended, while a narrow one can break dependencies that use alternate names or redirects.

## Gateway Debugging Runbook

1. Capture host, SNI, path, method, source, response code, and response flags.
2. Check load balancer and gateway Service endpoints.
3. Inspect gateway listeners and route attachment.
4. Validate TLS secret, certificate chain, and SNI.
5. Confirm VirtualService or HTTPRoute host matching.
6. Check destination endpoints, DestinationRule, mTLS, and AuthorizationPolicy.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does an ingress gateway do?" answer="It accepts external traffic and applies listener, TLS, and route configuration before forwarding into the mesh." %}
  {% include study-card.html question="What is TLS passthrough at a gateway?" answer="The gateway routes encrypted traffic using SNI without decrypting HTTP." %}
  {% include study-card.html question="Why can a gateway route fail even when the Service is healthy?" answer="DNS, load balancer, listener, TLS, host matching, route attachment, or policy can fail before the Service is reached." %}
  {% include study-card.html question="Why use an egress gateway?" answer="To centralize outbound policy, audit, source IP, TLS origination, or firewall integration for selected external traffic." %}
  {% include study-card.html question="Why inspect gateway proxy-config listeners?" answer="It shows which ports, protocols, hosts, and TLS filter chains Envoy actually received." %}
</div>

## References

- [Istio ingress gateway tasks](https://istio.io/latest/docs/tasks/traffic-management/ingress/)
- [Istio egress tasks](https://istio.io/latest/docs/tasks/traffic-management/egress/)
- [Gateway reference](https://istio.io/latest/docs/reference/config/networking/gateway/)
- [Kubernetes Gateway API with Istio](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
- [Istio secure gateways](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/)
