---
title: Kubernetes Pod Networking and CNI
layout: page
permalink: /docs/kubernetes/pod-networking-cni/
summary: "Kubernetes network model, Pod IPs, CNI plugins, routes, overlays, eBPF, MTU, hostNetwork, DNS path, and node-level debugging."
tags:
  - kubernetes
  - networking
  - cni
---

# Kubernetes Pod Networking and CNI

Kubernetes defines the network model; the CNI plugin implements it. Operators need to know where the Kubernetes API ends and the datapath begins, because Pod-to-Pod failures often live in CNI routes, encapsulation, host firewall rules, cloud routing, MTU, or node agents.

## First Checks

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl describe node <node>
kubectl -n kube-system get pods -o wide
kubectl exec -it <pod> -- ip addr
kubectl exec -it <pod> -- ip route
```

## Kubernetes Network Model

The Kubernetes model expects:

- every Pod has its own IP,
- Pods can communicate with Pods on other nodes without NAT,
- nodes can communicate with Pods,
- containers in the same Pod share a network namespace and can use `localhost`,
- Service networking is layered on top of Pod networking.

That model does not mandate how packets move. Common implementations use routed Pod CIDRs, overlays such as VXLAN or Geneve, cloud-native VPC addressing, BGP, iptables, IPVS, nftables, eBPF, or combinations.

## CNI Responsibilities

CNI plugins create Pod network interfaces and connect them to the node and cluster network. A plugin may also implement NetworkPolicy, Service load balancing, encryption, observability, egress gateways, or IPAM.

Operational questions:

- Which CNI plugin is installed?
- What Pod CIDRs are assigned to nodes?
- Is traffic routed, encapsulated, or cloud-native?
- Does the plugin enforce NetworkPolicy?
- Does the plugin replace kube-proxy?
- What MTU does it set for Pods and tunnels?

## MTU, Encapsulation, and Node Boundaries

Overlays add headers. If Pod MTU does not account for tunnel overhead, large requests can fail while small requests pass. Kubernetes incidents involving TLS, DNSSEC, gRPC, image pulls, or large HTTP responses can be MTU incidents.

Node boundaries matter. Pod-to-Pod on the same node may work while cross-node traffic fails. Cross-zone, cross-subnet, or cross-VPC traffic may add cloud routing and security group behavior.

## hostNetwork and Node Locality

Pods using `hostNetwork: true` share the node network namespace instead of getting normal Pod networking. That can be useful for node agents, but it changes port conflicts, DNS policy defaults, source addresses, and NetworkPolicy expectations.

## DNS and NAT Boundaries

Pod DNS and Pod egress are coupled. A Pod may resolve a Service name to a ClusterIP and stay inside Kubernetes service routing, or resolve an external name to a public address and leave through node SNAT, cloud NAT, an egress gateway, or a proxy. If private endpoint DNS is missing, workloads can silently use public NAT egress even when a private route exists.

Operational checks:

- compare `nslookup` from the Pod with `dig` from the node and from outside the cluster,
- check whether CoreDNS forwards external queries through a NATed node path,
- verify NetworkPolicy allows UDP and TCP 53 to CoreDNS,
- confirm whether app egress and DNS egress use the same gateway or policy,
- watch NAT gateway metrics when `ndots` or retry-heavy clients multiply DNS queries.

## Troubleshooting Flow

1. Compare same-node and cross-node Pod-to-Pod traffic.
2. Check Pod IPs, node IPs, and Pod CIDRs.
3. Inspect CNI Pods and node agent health.
4. Check Pod routes and interface MTU.
5. Check host routes, tunnel interfaces, and encapsulation.
6. Check cloud routes, security groups, or firewall policy outside Kubernetes.
7. Check whether kube-proxy replacement or eBPF mode changes Service debugging.
8. Check whether DNS answers select ClusterIP, private endpoint, public load balancer, or NAT egress paths.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does Kubernetes define versus CNI implement?" answer="Kubernetes defines the Pod networking model; the CNI plugin creates interfaces and implements the actual datapath." %}
  {% include study-card.html question="Why compare same-node and cross-node Pod traffic?" answer="It separates local Pod networking from routing, encapsulation, cloud, and node-to-node datapath problems." %}
  {% include study-card.html question="Why does Pod MTU matter?" answer="Overlay or tunnel overhead can black-hole large packets if the Pod MTU is too high for the real path." %}
  {% include study-card.html question="Why compare Pod DNS answers with egress routing?" answer="The DNS answer determines whether traffic stays in-cluster, uses a private endpoint, or exits through NAT." %}
</div>

## References

- [Kubernetes cluster networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Kubernetes networking model](https://kubernetes.io/docs/concepts/services-networking/)
- [Container Network Interface specification](https://github.com/containernetworking/cni/blob/main/SPEC.md)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
