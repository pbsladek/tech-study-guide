---
title: Kubernetes NetworkPolicy
layout: page
permalink: /docs/kubernetes/network-policy/
summary: "NetworkPolicy isolation, ingress and egress rules, podSelector, namespaceSelector, ipBlock, default deny, DNS egress, CNI enforcement, and policy debugging."
tags:
  - kubernetes
  - networking
  - security
---

# Kubernetes NetworkPolicy

NetworkPolicy is Kubernetes' built-in L3/L4 policy API. It describes which Pods may talk to which peers on which ports. The API is portable, but enforcement is not automatic; the CNI plugin must implement it.

## First Checks

```bash
kubectl get networkpolicy -A
kubectl describe networkpolicy <policy>
kubectl get pods --show-labels
kubectl get namespace --show-labels
kubectl exec -it <pod> -- nc -vz <service> <port>
kubectl exec -it <pod> -- nslookup kubernetes.default.svc.cluster.local
```

## Isolation Model

Pods are non-isolated by default. A Pod becomes isolated for ingress when at least one NetworkPolicy selects it for ingress. It becomes isolated for egress when at least one NetworkPolicy selects it for egress. Once isolated, only traffic allowed by applicable policies is permitted.

Policies are additive. There is no explicit deny rule in the standard NetworkPolicy API. If any policy allows a flow, that flow is allowed.

## Selectors

NetworkPolicy rules combine:

- `podSelector` for Pods in the policy namespace,
- `namespaceSelector` for namespaces,
- `ipBlock` for CIDR ranges outside normal Pod selector logic,
- ports and protocols.

A small YAML indentation error can change meaning. `namespaceSelector` and `podSelector` in the same list item mean both must match. Separate list items mean either may match.

## DNS and Egress

Default-deny egress often breaks DNS first. Applications then fail with confusing name resolution errors even though Service objects are healthy. If egress is isolated, allow DNS to the cluster DNS Service on UDP and TCP 53, or to the intended DNS endpoints.

## Limitations

Standard NetworkPolicy is not a full firewall language:

- it is namespace-scoped,
- it targets Pods, not arbitrary nodes,
- it is L3/L4, not HTTP-aware,
- it does not define explicit deny precedence,
- behavior can vary where CNIs add extensions,
- some traffic involving hostNetwork or node-local paths may not behave like normal Pod traffic.

## Debugging Flow

1. Confirm the CNI enforces NetworkPolicy.
2. List policies in the source and destination namespaces.
3. Check whether policies select the affected Pods.
4. Check labels on Pods and namespaces.
5. Test DNS separately from application traffic.
6. Test ingress and egress directions separately.
7. Check CNI policy logs or flow observability if available.
8. Use a temporary debug Pod with matching labels to reproduce intentionally.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="When is a Pod isolated for ingress?" answer="When at least one ingress NetworkPolicy selects that Pod; then only allowed ingress traffic is permitted." %}
  {% include study-card.html question="Why do default-deny egress policies often break DNS?" answer="DNS to cluster DNS on UDP and TCP 53 must be allowed explicitly when egress is isolated." %}
  {% include study-card.html question="Does Kubernetes enforce NetworkPolicy by itself?" answer="No. The CNI plugin must implement NetworkPolicy enforcement." %}
</div>

## References

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
