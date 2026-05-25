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

Additive allow truth table:

| Selected By Ingress Policy? | Any Ingress Rule Allows Source/Port? | Result |
| --- | --- | --- |
| No | Not needed | Allowed by default for ingress. |
| Yes | No | Denied for ingress. |
| Yes | Yes | Allowed for that matching flow. |

For egress, the same isolation rule applies independently:

| Selected By Egress Policy? | Any Egress Rule Allows Destination/Port? | Result |
| --- | --- | --- |
| No | Not needed | Allowed by default for egress. |
| Yes | No | Denied for egress. |
| Yes | Yes | Allowed for that matching flow. |

## Selectors

NetworkPolicy rules combine:

- `podSelector` for Pods in the policy namespace,
- `namespaceSelector` for namespaces,
- `ipBlock` for CIDR ranges outside normal Pod selector logic,
- ports and protocols.

A small YAML indentation error can change meaning. `namespaceSelector` and `podSelector` in the same list item mean both must match. Separate list items mean either may match.

## DNS and Egress

Default-deny egress often breaks DNS first. Applications then fail with confusing name resolution errors even though Service objects are healthy. If egress is isolated, allow DNS to the cluster DNS Service on UDP and TCP 53, or to the intended DNS endpoints.

## Lab Scenarios

Use a disposable namespace for these patterns. The point is to see how selectors and directions combine before relying on policy during an incident.

Default-deny all ingress and egress:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
```

Allow DNS egress to CoreDNS:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

Allow frontend Pods in namespaces labeled `team=web` to call API Pods on port 8080:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-from-web
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              team: web
          podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 8080
```

Ingress plus egress isolation test:

```bash
kubectl run np-client --image=busybox:1.36 -it --rm --restart=Never --labels role=frontend -- sh
nslookup kubernetes.default.svc.cluster.local
nc -vz api.default.svc.cluster.local 8080
nc -vz api.default.svc.cluster.local 5432
```

If the policy should allow traffic but packets still fail, check CNI enforcement, namespace labels, Pod labels, generated endpoint identities, and whether traffic is hostNetwork or node-local. CNI-specific policy extensions may add explicit deny, L7 rules, or FQDN rules, but standard NetworkPolicy does not.

## Limitations

Standard NetworkPolicy is not a full firewall language:

- it is namespace-scoped,
- it targets Pods, not arbitrary nodes,
- it is L3/L4, not HTTP-aware,
- it does not define explicit deny precedence,
- behavior can vary where CNIs add extensions,
- some traffic involving hostNetwork or node-local paths may not behave like normal Pod traffic.

It also does not define FQDN policy. A standard rule cannot say "allow egress to `api.example.com`" because policy matching happens on Pod selectors, namespace selectors, IP blocks, and ports. Some CNIs add FQDN-aware policy as an extension, but the behavior then depends on DNS cache timing, TTLs, wildcard rules, and the CNI's DNS interception model.

If you need FQDN egress, document whether the CNI resolves names centrally, observes DNS answers from Pods, pins IPs until TTL expiry, handles CNAMEs, and fails open or closed when DNS is unavailable.

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
  {% include study-card.html question="What does namespaceSelector plus podSelector in one from item mean?" answer="Both selectors must match: the source Pod must match the Pod selector inside a namespace matching the namespace selector." %}
</div>

## References

- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
