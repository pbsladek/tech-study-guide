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

## Command Examples

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl describe node <node>
kubectl -n kube-system get pods -o wide
kubectl exec -it <pod> -- ip addr
kubectl exec -it <pod> -- ip route
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `kubectl get pods -A -o wide` | Pod IPs such as `10.244.2.17` and node names such as `worker-2`. | Ties a failing Pod to its overlay address and node. |
| `kubectl describe node <node>` | PodCIDR, conditions, taints, and recent node events. | Shows whether node-level CNI allocation or readiness is suspect. |
| `kubectl exec -it <pod> -- ip route` | `default via 10.244.2.1 dev eth0` and Pod CIDR routes. | Confirms the route table inside the Pod namespace. |

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

Common CNI shapes:

| CNI Shape | Typical Datapath | Strength | Common Debug Focus |
| --- | --- | --- | --- |
| Flannel-style overlay | VXLAN/host-gw routes, simple Pod networking. | Simple cluster Pod reachability. | MTU, node routes, overlay interface, lack of NetworkPolicy. |
| Calico-style routed/BGP | Routed Pod CIDRs, optional IP-in-IP/VXLAN, policy. | Policy plus routed networks. | BGP sessions, Felix logs, route tables, policy drops. |
| Cilium-style eBPF | eBPF programs and maps, optional kube-proxy replacement. | Service maps, policy, observability, L7 options. | Cilium agent status, BPF maps, Hubble/drop reasons. |
| Cloud VPC CNI | Pod IPs from cloud VPC/subnet interfaces. | Native cloud routing and security integration. | IP exhaustion, ENI/NIC limits, subnet routes, security groups. |

## Pod Packet Paths

Same-node Pod traffic, cross-node Pod traffic, Service traffic, and external egress can use different paths.

| Path | What To Inspect |
| --- | --- |
| Same-node Pod to Pod | Pod netns, veth pair, bridge or BPF datapath, NetworkPolicy. |
| Cross-node Pod to Pod | Pod CIDR route, tunnel interface, BGP route, cloud route, MTU. |
| Pod to Service | EndpointSlice, kube-proxy mode, eBPF service maps, conntrack. |
| Pod to external | DNS answer, node SNAT, egress gateway, NAT gateway, firewall, private endpoint. |

```bash
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ip route
kubectl exec <pod> -- ping -c 2 <same-node-pod-ip>
kubectl exec <pod> -- ping -c 2 <cross-node-pod-ip>
kubectl exec <pod> -- curl -v http://<service>.<namespace>.svc.cluster.local:<port>
```

Capture comparison for same-node versus cross-node:

```bash
kubectl get pod -o wide -l app=client
kubectl get pod -o wide -l app=server
kubectl exec <client-pod> -- curl -v http://<same-node-pod-ip>:8080
kubectl exec <client-pod> -- curl -v http://<cross-node-pod-ip>:8080
tcpdump -nn -i any host <cross-node-pod-ip>
```

If same-node works and cross-node fails, stop debugging the application listener. Focus on node routes, overlay encapsulation, cloud security groups, tunnel MTU, BGP routes, or CNI node agents.

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

## Hairpin and SNAT Checks

Hairpin traffic happens when a workload reaches a service through an address that loops back through a load balancer or NAT device. It often appears after public DNS is reused inside the cluster.

```bash
kubectl exec <pod> -- getent hosts app.example.com
kubectl exec <pod> -- ip route get <resolved-ip>
kubectl exec <pod> -- curl -v https://app.example.com/
```

If the name resolves to a public load balancer for in-cluster clients, prefer split-horizon DNS, a ClusterIP Service, a private endpoint, or explicit egress-gateway design. Otherwise the return path, source IP, mTLS identity, and firewall policy may differ from the intended internal path.

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
  {% include study-card.html question="Why can Pod-to-Service fail while direct Pod IP works?" answer="The workload listener is reachable, but the Service datapath, EndpointSlice state, kube-proxy replacement, or conntrack path may be broken." %}
</div>

## References

- [Kubernetes cluster networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [Kubernetes networking model](https://kubernetes.io/docs/concepts/services-networking/)
- [Container Network Interface specification](https://github.com/containernetworking/cni/blob/main/SPEC.md)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
