---
title: Cloud Networking
layout: page
permalink: /docs/networking/cloud-networking/
summary: "Cloud networking fundamentals for VPCs, subnets, route tables, security groups, private endpoints, peering, transit gateways, NAT, load balancers, and overlapping CIDRs."
tags:
  - networking
  - cloud
  - routing
  - nat
  - troubleshooting
---

# Cloud Networking

Cloud networking wraps familiar routing, firewalling, NAT, and load balancing in provider-managed control planes. The data plane still forwards packets, but the configuration source is APIs: VPCs or VNets, subnets, route tables, security groups, load balancers, NAT gateways, private endpoints, peering, and transit fabrics.

The biggest debugging trap is assuming the instance route table is the only route table.

## First Checks

```bash
ip addr
ip route
curl -sS ifconfig.me
traceroute 203.0.113.10
dig api.example.com
```

Then inspect the provider objects for the affected interface, subnet, route table, security policy, NAT, and load balancer. Host-local commands prove the guest view; cloud APIs prove the fabric view.

## Core Objects

| Object | Role | Common Failure |
| --- | --- | --- |
| VPC / VNet | Isolated routing domain. | Overlapping CIDRs block peering or routing. |
| Subnet | Address range mapped to a zone or segment. | Wrong route table or exhausted IPs. |
| Route table | Provider-side next-hop policy. | Missing default route, wrong peering/transit route, blackhole route. |
| Security group | Stateful interface or workload firewall. | Inbound/outbound rule missing. |
| Network ACL | Stateless subnet firewall in some clouds. | Return traffic blocked by ephemeral port rules. |
| NAT gateway | Outbound source NAT for private subnets. | Port exhaustion, missing route, zonal dependency. |
| Load balancer | Managed L4/L7 entry point. | Health check mismatch, source IP change, timeout mismatch. |
| Private endpoint | Private address for a provider service. | DNS points public when clients need private path. |

Cloud networks are policy-rich. Reachability requires route, firewall, identity, DNS, and service health to agree.

## AWS, Azure, and Google Cloud Differences

The concepts rhyme, but the control-plane names and failure modes differ enough that operators should translate terms explicitly.

| Concern | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Network container | VPC | Virtual Network | VPC network |
| Subnet scope | Availability Zone | Region | Region |
| Stateful firewall | Security group | Network Security Group | VPC firewall rule, hierarchical firewall policy |
| Stateless subnet ACL | Network ACL | No exact default equivalent | No exact default equivalent |
| Private service access | PrivateLink / VPC endpoints | Private Endpoint / Private Link | Private Service Connect / Private Google Access |
| Transit fabric | Transit Gateway | Virtual WAN / hub-and-spoke peering | Network Connectivity Center / Cloud Router patterns |
| NAT | NAT Gateway | NAT Gateway | Cloud NAT |
| Flow logs | VPC Flow Logs | NSG flow logs / VNet flow logs | VPC Flow Logs |

Practical implication: a runbook that says "check the security group and NACL" is AWS-shaped. In Azure, check NSGs on subnet/NIC and route tables. In Google Cloud, check VPC firewall rules, hierarchical policy, service account tags, and implied routes.

## Route Tables and Next Hops

Cloud route tables usually apply at subnet, NIC, or gateway scope. A host may show a default route to a local virtual gateway, while the provider route table decides where packets actually go after that.

Questions to ask:

- Which subnet is the source NIC attached to?
- Which route table applies to that subnet or NIC?
- Is the destination matched by the most specific cloud route?
- Does the next hop exist and accept that traffic?
- Is return traffic routed symmetrically?
- Does peering or transit allow route propagation?

Overlapping CIDRs are painful because both sides may believe the destination is local. Avoid overlapping CIDRs before building peering, VPN, or transit gateway designs.

## Security Groups and Stateless ACLs

Security groups are usually stateful: if outbound traffic is allowed, return traffic for that flow is allowed. Network ACLs are often stateless: both request and response directions need explicit rules.

For TCP clients, response traffic returns to ephemeral ports. A stateless ACL that allows destination port `443` but blocks ephemeral return ports will create confusing half-open failures.

## NAT and Egress

Cloud NAT gateways translate many private workloads to a smaller set of public or provider-owned addresses. They are convenient and stateful, but can exhaust ports under high fan-out.

Symptoms:

- New outbound connections fail while existing flows continue.
- Failures affect one zone or subnet more than others.
- Remote services see the NAT IP, not the instance IP.
- Scaling clients increases failures even when CPU is low.

Mitigations include more NAT IPs, per-zone NAT, connection reuse, lower fan-out, private endpoints, or service-specific egress paths.

Cloud NAT port exhaustion often looks like an application or DNS issue because only new outbound connections fail.

```text
high fan-out clients + short connections + few NAT source IPs = source port pressure
```

Prefer connection reuse and private endpoints for high-volume provider-service traffic. For Kubernetes, also inspect node density and Pod distribution because many Pods may share one node or one zonal NAT path.

## Load Balancers and Source IP

Cloud load balancers differ in source IP preservation, proxy protocol support, TLS termination, health-check behavior, and timeout defaults.

Common mismatches:

| Symptom | Likely Cause |
| --- | --- |
| Health check passes but users fail | Health endpoint does not exercise auth, dependency, host header, or TLS path. |
| App sees load balancer IP | L7 proxying or SNAT hides client source. |
| Long requests reset | Idle timeout shorter than app behavior. |
| One zone fails | Zonal target, subnet, NAT, or route dependency. |

## Private Endpoints and DNS

Private endpoints make provider services reachable through private IPs. DNS decides whether clients use the private or public path.

Check:

```bash
dig service.example.internal
getent hosts service.example.internal
ip route get <private-endpoint-ip>
```

Split-horizon DNS mistakes often look like firewall issues because the name resolves to the wrong address for the client location.

## Peering, Transit, and Overlap

Peering is usually non-transitive unless the provider says otherwise. Transit gateways and hub networks centralize routing, but they also centralize blast radius.

Common failure modes:

| Failure | Symptom |
| --- | --- |
| Overlapping CIDRs | Peering rejected, route not propagated, or traffic sent locally. |
| Missing return route | SYN reaches destination but SYN-ACK never returns. |
| Route propagation disabled | One subnet or spoke cannot reach a prefix that others can. |
| Private DNS not linked | Clients resolve public addresses even with private endpoints present. |
| Zonal NAT dependency | One zone fails outbound while others work. |

When comparing clouds, always map route scope, firewall scope, DNS scope, and endpoint scope separately. They rarely have the same attachment point.

## Runbook

1. Identify source workload, destination name/IP, port, protocol, and subnet.
2. Resolve DNS from the same workload environment.
3. Check guest route and provider route table.
4. Check security groups, network ACLs, and service firewall policy.
5. Check NAT gateway, load balancer, private endpoint, peering, or transit gateway state.
6. Verify return path and source IP behavior.
7. Use flow logs or packet capture at the closest available boundary.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is the host route table insufficient in cloud networking?" answer="Provider route tables and virtual network policy decide forwarding after the guest sends packets to the fabric." %}
  {% include study-card.html question="Why do stateless network ACLs often break return traffic?" answer="They require explicit rules for ephemeral response ports as well as request ports." %}
  {% include study-card.html question="What is a common NAT gateway failure mode?" answer="Port exhaustion, where new outbound connections fail while established connections may continue." %}
  {% include study-card.html question="Why do private endpoints depend on DNS correctness?" answer="Clients must resolve the service name to the private endpoint address to use the private path." %}
  {% include study-card.html question="Why are cloud networking runbooks provider-specific?" answer="Route, firewall, private endpoint, NAT, and DNS controls attach at different scopes in AWS, Azure, and Google Cloud." %}
</div>

## References

- [AWS VPC user guide](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [Azure Virtual Network documentation](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
- [Google Cloud VPC documentation](https://cloud.google.com/vpc/docs/vpc)
- [AWS NAT gateway basics](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
