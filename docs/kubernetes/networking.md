---
title: Kubernetes Networking
layout: page
permalink: /docs/kubernetes/networking/
summary: Pod networking, Services, CoreDNS, kube-dns history, Ingress, Gateway API, and load balancers.
tags:
  - kubernetes
  - networking
  - dns
  - ingress
---

# Kubernetes Networking

Kubernetes networking starts from a simple model: every Pod gets a cluster-wide IP, containers in the same Pod share a network namespace, and Pods should be able to communicate without manual port mapping. The hard part is that Kubernetes defines the model while plugins implement much of the datapath.

## The Pod Network

A Pod has one IP and one network namespace. Containers inside the Pod share:

- loopback,
- IP address,
- port space,
- routes,
- network interfaces.

This is why two containers in one Pod can talk over `localhost`, but two Pods cannot. Between Pods, traffic uses Pod IPs, Service virtual IPs, or higher-level routing.

The CNI plugin is responsible for connecting Pods to the cluster network. Depending on the plugin, packets may move through bridges, routes, overlays, BGP, eBPF programs, or cloud-native VPC networking.

## Service Networking

A Service gives a stable virtual endpoint for a changing set of Pods. The selector chooses Pods, the EndpointSlice controller writes EndpointSlices, and kube-proxy or a replacement datapath routes traffic.

| Service Type | Use |
| --- | --- |
| `ClusterIP` | Internal virtual IP for Pods inside the cluster. |
| `NodePort` | Opens a port on every node and forwards to the Service. |
| `LoadBalancer` | Asks a cloud or load balancer controller to create an external balancer. |
| `ExternalName` | DNS CNAME-style indirection to an external name. |

Quirky Service details:

- Services route to ready endpoints unless publishing not-ready addresses is configured.
- Service selectors must match Pod labels exactly; selector drift is a common outage.
- `targetPort` can be a number or named container port.
- `externalTrafficPolicy: Local` preserves client source IP for many load balancer setups but only sends traffic to nodes with local ready endpoints.
- Headless Services (`clusterIP: None`) skip the virtual IP and publish endpoint records directly, often for StatefulSets.

## DNS: CoreDNS and kube-dns

Modern clusters commonly run CoreDNS as the cluster DNS server. Older clusters used kube-dns. The job is similar: watch Kubernetes Services and endpoints, then answer DNS queries from Pods.

Default lookup behavior matters:

- A Pod resolving `api` first searches its own namespace.
- Cross-namespace lookup should use `api.other-namespace`.
- Fully qualified Service names look like `service.namespace.svc.cluster.local`.
- Search paths and `ndots` can generate multiple queries for one application lookup.

CoreDNS must have permissions to list and watch Services, namespaces, Pods, and EndpointSlices. Missing EndpointSlice RBAC can cause SERVFAIL or stale answers.

Common Kubernetes DNS failures:

- Node `/etc/resolv.conf` points at a local stub resolver that creates a forwarding loop.
- Too many upstream nameservers hit libc limits.
- Alpine or old musl-based images mishandle large DNS responses without TCP fallback.
- NetworkPolicy blocks UDP/TCP 53 to CoreDNS.
- `ndots:5` amplifies external lookups into several internal search attempts.

## Ingress and Gateway API

Ingress exposes HTTP and HTTPS routing rules, but an Ingress object does nothing without an Ingress controller. Controllers differ in annotations, load balancing behavior, TLS handling, and rewrite support.

Ingress is stable but frozen. New Kubernetes traffic-management work is centered on Gateway API, which separates infrastructure roles from application route ownership and supports richer routing models.

Use this rule of thumb:

- Use `Service type: LoadBalancer` for simple L4 exposure.
- Use Ingress for existing HTTP routing ecosystems.
- Prefer Gateway API for new platform designs that need explicit GatewayClasses, shared gateways, and richer route ownership.

## Load Balancers

`type: LoadBalancer` is not magic inside core Kubernetes. It requires an implementation:

- cloud controller manager in managed clouds,
- MetalLB or similar on bare metal,
- appliance or service mesh integration,
- custom load balancer controller.

The Service status shows whether an external address was assigned:

```bash
kubectl get service <name>
kubectl describe service <name>
kubectl get endpointslice -l kubernetes.io/service-name=<name>
```

## NetworkPolicy

NetworkPolicy is an API for L3/L4 traffic control, but enforcement depends on the CNI plugin. If the CNI does not implement NetworkPolicy, policy objects may exist without effect.

Important behaviors:

- Policies are namespace scoped.
- Once a Pod is selected by an ingress policy, only allowed ingress traffic is permitted.
- Egress isolation is separate from ingress isolation.
- DNS must be allowed explicitly when egress is locked down.

## Packet Walkthrough: Client to Pod via Ingress

1. Client resolves the external DNS name to a load balancer address.
2. The load balancer sends traffic to an Ingress controller or gateway.
3. The controller matches host/path/TLS rules.
4. The controller forwards to a Service backend.
5. Service datapath chooses a ready endpoint.
6. CNI routes the packet to the node and Pod.
7. The Pod receives traffic on its container port.

Break the path at each boundary when debugging.

## Commands

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl -n kube-system logs deployment/coredns
kubectl get svc,endpointslice,ingress,gateway --all-namespaces
kubectl exec -it <pod> -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -it <pod> -- cat /etc/resolv.conf
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What creates DNS records for Kubernetes Services?" answer="Cluster DNS, commonly CoreDNS, watches Service and endpoint data and answers names such as service.namespace.svc.cluster.local." %}
  {% include study-card.html question="Does creating an Ingress object expose traffic by itself?" answer="No. An Ingress controller must watch the object and configure a load balancer or proxy." %}
  {% include study-card.html question="Why can NetworkPolicy objects have no effect?" answer="The selected CNI plugin must implement NetworkPolicy enforcement; Kubernetes only defines the API." %}
  {% include study-card.html question="What does a headless Service do?" answer="It sets clusterIP: None and publishes endpoint records directly instead of routing through a virtual Service IP." %}
</div>

## References

- [Kubernetes Services, Load Balancing, and Networking](https://kubernetes.io/docs/concepts/services-networking/)
- [DNS debugging in Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/)
