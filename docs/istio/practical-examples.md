---
title: Istio Service Mesh Examples
layout: page
permalink: /docs/istio/practical-examples/
summary: "Practical Istio examples for VirtualService traffic splitting, DestinationRule subsets, and AuthorizationPolicy."
tags:
  - examples
  - istio
  - service-mesh
---

# Istio Service Mesh Examples

These examples complement [Istio](/docs/istio/), [traffic management](/docs/istio/traffic-management/), and [security, mTLS, and policy](/docs/istio/security-mtls-policy/).

## Istio Examples

Traffic split with a VirtualService:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: example-api
  namespace: apps
spec:
  hosts:
    - example-api.apps.svc.cluster.local
  http:
    - route:
        - destination:
            host: example-api.apps.svc.cluster.local
            subset: stable
          weight: 90
        - destination:
            host: example-api.apps.svc.cluster.local
            subset: canary
          weight: 10
```

DestinationRule subsets:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: example-api
  namespace: apps
spec:
  host: example-api.apps.svc.cluster.local
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

AuthorizationPolicy that allows only one namespace:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: example-api-allow-ingress
  namespace: apps
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: example-api
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces:
              - ingress
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a VirtualService traffic split control?" answer="It controls the percentage of matching traffic sent to each destination route." %}
  {% include study-card.html question="Why does DestinationRule define subsets?" answer="Subsets map routing names such as stable and canary to workload labels." %}
  {% include study-card.html question="What does AuthorizationPolicy add beyond mTLS identity?" answer="It decides which authenticated source identities or namespaces are allowed to reach a workload." %}
</div>

## References

- [Istio VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [Istio DestinationRule](https://istio.io/latest/docs/reference/config/networking/destination-rule/)
- [Istio AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
