---
title: Glossary
layout: page
permalink: /docs/glossary/
summary: "Search-focused short definitions for operational terms across Linux, networking, Kubernetes, DNS, TLS, and performance."
tags:
  - glossary
  - networking
  - linux
  - kubernetes
---

# Glossary

This glossary is tuned for search. Each entry is short and points to the deeper page that explains the operational behavior.

## Networking and Linux Terms

| Term | Short Definition | Go Deeper |
| --- | --- | --- |
| conntrack | Linux connection tracking state used by NAT and stateful firewall rules. | [NAT Gateways and NAT](/docs/networking/nat-gateways/) |
| EndpointSlice | Kubernetes API object listing Service backend endpoints and readiness/terminating conditions. | [Services and EndpointSlices](/docs/kubernetes/services-endpointslices/) |
| PSI | Pressure Stall Information, Linux metrics that show time lost to CPU, memory, or IO pressure. | [Memory Pressure and OOM](/docs/linux/memory-pressure-oom/) |
| NAPI | Linux network-driver polling model that batches packet receive work and shifts cost into softirq. | [Kernel Network Performance](/docs/linux/kernel-network-performance/) |
| SNI | TLS extension carrying the requested hostname so servers and proxies can choose certificates or routes. | [Certificates and HTTPS](/docs/networking/certificates-https/) |
| ALPN | TLS extension for negotiating application protocols such as HTTP/2. | [HTTP and Proxy Debugging](/docs/networking/http-proxy-debugging/) |
| ECMP | Equal-cost multi-path routing that hashes flows across multiple next hops. | [BGP and Dynamic Routing](/docs/networking/bgp-dynamic-routing/) |
| VXLAN | UDP/IP overlay encapsulation that carries L2 frames across an L3 network. | [Network Namespaces and Virtual Networking](/docs/networking/network-namespaces-virtual-networking/) |
| `memory.high` | cgroup v2 memory throttle/reclaim threshold below the hard `memory.max` limit. | [Containerization, OCI, and VMs](/docs/linux/containerization-oci-vms/) |
| `memory.max` | cgroup v2 hard memory limit that can trigger cgroup OOM handling. | [Containerization, OCI, and VMs](/docs/linux/containerization-oci-vms/) |
| `cpu.max` | cgroup v2 CPU quota and period file. | [Containerization, OCI, and VMs](/docs/linux/containerization-oci-vms/) |
| `cpu.stat` | cgroup v2 CPU usage and throttling counters. | [Containerization, OCI, and VMs](/docs/linux/containerization-oci-vms/) |
| NodeLocal DNSCache | Kubernetes node-local DNS cache that changes DNS cache location and packet-capture point. | [Kubernetes DNS and CoreDNS](/docs/kubernetes/dns-coredns/) |
| kube-proxy | Kubernetes node component that implements Service virtual IP behavior unless replaced. | [Services and EndpointSlices](/docs/kubernetes/services-endpointslices/) |
| NetworkPolicy | Kubernetes L3/L4 Pod traffic policy that requires CNI enforcement. | [NetworkPolicy](/docs/kubernetes/network-policy/) |
| mTLS | Mutual TLS, where both server and client certificates are validated. | [Zero-Trust Networking](/docs/networking/zero-trust-networking/) |
| SPIFFE ID | Workload identity URI shape commonly carried in certificate SANs. | [Zero-Trust Networking](/docs/networking/zero-trust-networking/) |
| QUIC | Encrypted UDP-based transport used by HTTP/3. | [UDP, QUIC, and Connectionless Traffic](/docs/networking/udp-quic-connectionless/) |
| Path MTU Discovery | Method for discovering the smallest MTU along a path using ICMP feedback. | [ICMP, MTU, and Path Testing](/docs/networking/icmp-mtu-path-testing/) |
| LACP | Link aggregation control protocol for bundling physical links. | [Datacenter L2/L3 Operations](/docs/networking/datacenter-l2-l3-operations/) |

## First Checks

```bash
rg -n "conntrack|EndpointSlice|memory.high|ALPN|VXLAN" docs
```

Use glossary terms as search anchors, then follow the linked operational page for commands and runbooks.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is conntrack?" answer="Linux connection tracking state used by NAT and stateful firewall policy." %}
  {% include study-card.html question="What does memory.high do?" answer="It sets a cgroup v2 memory threshold where reclaim and throttling begin before the hard limit." %}
  {% include study-card.html question="What does ALPN negotiate?" answer="The application protocol inside TLS, such as HTTP/2 or HTTP/1.1." %}
</div>

## References

- [Linux cgroup v2 documentation](https://docs.kernel.org/admin-guide/cgroup-v2.html)
- [Kubernetes Services and EndpointSlices](/docs/kubernetes/services-endpointslices/)
- [Certificates and HTTPS](/docs/networking/certificates-https/)
- [Kernel Network Performance](/docs/linux/kernel-network-performance/)
