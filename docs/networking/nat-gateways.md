---
title: NAT Gateways and Network Address Translation
layout: page
permalink: /docs/networking/nat-gateways/
summary: "Deep operational guide to NAT, NAT gateways, SNAT, DNAT, PAT, masquerade, conntrack, ephemeral ports, cloud egress, hairpin NAT, and NAT troubleshooting."
tags:
  - networking
  - nat
  - cloud
  - troubleshooting
---

# NAT Gateways and Network Address Translation

Network Address Translation changes packet addresses or ports as traffic crosses a boundary. NAT is common in home networks, cloud VPCs, Kubernetes nodes, firewalls, load balancers, VPNs, and service-provider networks. It is useful because it connects address realms, but it also creates state, hides identity, changes troubleshooting evidence, and can become a hard scaling limit.

## Command Examples

```bash
ip route get 198.51.100.10
ip rule
nft list ruleset
conntrack -S
conntrack -L -p tcp --orig-src 10.0.0.10 2>/dev/null | head
ss -tan state established
tcpdump -nn -i any 'host 198.51.100.10 or host 10.0.0.10'
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `ip route get 198.51.100.10` | `198.51.100.10 via 10.0.0.1 dev eth0 src 10.0.0.10`. | Shows which source IP and gateway feed the NAT path. |
| `conntrack -S` | `entries 1048211`, `insert_failed 482`. | Reveals conntrack pressure that can block new NAT state. |
| `conntrack -L -p tcp --orig-src 10.0.0.10 | head` | Entries with original and translated tuples. | Proves whether SNAT state exists for the client flow. |

Use these checks to answer: where will the packet route, which policy table applies, what NAT rules exist, whether conntrack is healthy, whether connection state exists, and what the packet looks like before and after translation.

## NAT Vocabulary

| Term | Meaning |
| --- | --- |
| SNAT | Source NAT: changes the source address or source port. Common for outbound internet egress. |
| DNAT | Destination NAT: changes the destination address or destination port. Common for port forwarding and inbound load-balancing paths. |
| PAT / NAPT | Port Address Translation: many internal flows share one external IP by using different source ports. |
| Masquerade | Dynamic SNAT that uses the current egress interface address. Useful when the public address can change. |
| Static NAT | A stable one-to-one address translation, often called static NAT in runbooks. |
| Hairpin NAT | A client inside a network reaches an internal service through the service's external NAT address. |
| CGNAT | Carrier-grade NAT used by service providers to share public IPv4 across many customers. |
| NAT gateway | A managed or self-hosted egress device that performs NAT for routed networks. |

NAT is usually stateful. The first packet creates a mapping, and return packets must match that mapping so the translator can reverse the rewrite.

## What a NAT Gateway Does

A NAT gateway usually lets private hosts initiate outbound connections to another network while blocking unsolicited inbound connections. In cloud networks, private subnets often route `0.0.0.0/0` to a NAT gateway so instances can reach package repositories, APIs, container registries, and SaaS endpoints without having public IPs.

Typical outbound path:

1. Private instance sends from `10.0.1.25:43210` to `203.0.113.50:443`.
2. Route table sends the packet to the NAT gateway.
3. NAT gateway rewrites source to a public address and selected source port.
4. Internet server replies to the public address and port.
5. NAT gateway uses its state table to translate the reply back to `10.0.1.25:43210`.

Important boundary: a NAT gateway is not a firewall by itself. It blocks unsolicited inbound traffic because no state mapping exists, but outbound policy, destination filtering, and application allow lists still need explicit design.

## Linux NAT Packet Flow

On Linux, NAT is implemented through netfilter and conntrack.

| Operation | Common Hook | Example |
| --- | --- | --- |
| DNAT | `prerouting` or `output` | Public `198.51.100.10:443` to private `10.0.2.20:8443`. |
| SNAT | `postrouting` | Private `10.0.1.25` to public `198.51.100.5`. |
| Masquerade | `postrouting` | Private subnet to dynamic interface address. |

Example nftables shape:

```bash
nft add table ip nat
nft add chain ip nat postrouting '{ type nat hook postrouting priority srcnat; }'
nft add rule ip nat postrouting oifname "eth0" ip saddr 10.0.0.0/8 masquerade
```

The NAT decision is normally made when a new flow is seen. Later packets follow conntrack state. That is why stale conntrack entries, asymmetric return paths, or table exhaustion can create confusing behavior.

## Port Translation and Exhaustion

PAT lets many clients share one external address, but each active mapping consumes a tuple. The practical tuple includes protocol, translated source IP, translated source port, destination IP, destination port, and sometimes zone or interface state.

Port exhaustion patterns:

- many clients connect to the same destination IP and port,
- short-lived HTTP clients churn connections instead of pooling,
- NAT gateway has too few public IPs for the fan-out,
- UDP mappings linger or expire too quickly,
- health checks, scraping, package mirrors, or test runners create synchronized spikes,
- TIME_WAIT and remote tuple reuse rules reduce immediate reuse.

Symptoms:

- new outbound connections time out while existing connections work,
- resets or intermittent TLS handshake failures,
- provider metrics show port allocation errors or connection failures,
- Linux `conntrack -S` shows insert failures or high table use,
- application logs show upstream timeouts without local CPU saturation.

Fixes are design choices, not one magic sysctl:

- reuse connections with keepalive and pooling,
- spread egress across more NAT IPs or gateways,
- shard high-volume clients across source addresses,
- reduce noisy polling and health checks,
- tune conntrack only after sizing memory and state lifetime,
- use private endpoints, private service endpoints, or service endpoints to avoid NAT for internal/cloud services.

## NAT Exhaustion Runbook

When new outbound connections fail but established connections continue, treat NAT exhaustion as a first-class suspect.

| Evidence | Linux / Kubernetes | Cloud Provider |
| --- | --- | --- |
| Conntrack pressure | `conntrack -S`, `nf_conntrack_count`, insert failures. | Flow logs showing drops or failed connection attempts. |
| Ephemeral port pressure | `ss -tan state time-wait`, source tuple fan-out. | NAT port allocation errors, SNAT port usage, connection error metrics. |
| DNS amplification | CoreDNS query rate, `ndots` search expansion, retry spikes. | Resolver rate limiting, many UDP 53 flows from one NAT IP. |
| Kubernetes egress concentration | many Pods per node, egress gateway bottleneck, node SNAT. | one subnet or zone routed through one gateway. |
| Connection churn | short-lived HTTP clients, no pooling, synchronized jobs. | high new connections per second to one destination. |

Practical workflow:

```bash
date -Is
cat /proc/sys/net/netfilter/nf_conntrack_count
sysctl net.netfilter.nf_conntrack_max
conntrack -S
ss -tan state time-wait | wc -l
ss -tan dst 203.0.113.50:443 | wc -l
kubectl -n kube-system logs deployment/coredns --since=10m | tail
```

Fixes to prefer before raw timeout tuning:

- enable HTTP keepalive and database/client pooling,
- reduce synchronized scraping, health checks, and test fan-out,
- add NAT source IPs or per-zone gateways,
- route provider APIs through private endpoints,
- lower DNS search amplification by using fully qualified names where appropriate,
- move bulk jobs to dedicated egress paths.

### NAT Port Budget Estimator

For one NAT source IP talking to one destination IP and port, the practical ceiling is bounded by available source ports and provider reservation rules. The rough model is:

```text
usable_ports_per_nat_ip_to_one_destination ~= ephemeral_port_count - reserved_ports
required_ports ~= concurrent_connections + TIME_WAIT_connections + retry_burst
```

Example:

```text
ephemeral range: 32768-60999 = 28232 ports
one destination: api.vendor.example:443
steady connections: 12000
TIME_WAIT and reconnect burst: 18000
required: 30000+
result: one source IP is too small even before provider-specific reservations
```

Capacity clues:

| Pattern | Design Response |
| --- | --- |
| Many short-lived connections to one destination | Pool/reuse connections before adding ports. |
| Many Pods behind one node SNAT | Spread Pods across nodes or use more egress IPs. |
| One vendor API dominates port use | Dedicated NAT IP, proxy pool, or private connectivity. |
| TIME_WAIT dominates | Reduce churn; do not blindly shorten TCP timeouts without understanding peer behavior. |
| DNS points clients to one endpoint | Load balancing or private endpoints may reduce per-destination concentration. |

## Cloud NAT Gateway Design

Cloud NAT gateways differ by provider, but the same design questions apply.

| Question | Why It Matters |
| --- | --- |
| Which subnets route to it? | Route tables decide which private workloads use the gateway. |
| Is it zonal or regional? | A zone failure or cross-zone path can affect availability and cost. |
| How many public IPs does it use? | Public IP count often affects source-port capacity and destination fan-out. |
| What metrics exist? | Port allocation, packets, bytes, drops, errors, and active connections are critical. |
| What bypass paths exist? | Private service endpoints can avoid NAT, reduce cost, and preserve private routing. |
| What logs exist? | Flow logs may show translated or original addresses depending on capture point. |

High-availability design usually means one NAT gateway per failure domain with private subnets routing to the gateway in the same domain. A single central gateway is easy to draw, but it can become a bottleneck, failure domain, or cross-zone cost source.

## NAT and Firewalls

NAT and firewall policy interact. A firewall rule may match the original address at one hook and the translated address at another. When a packet is denied, first ask which address exists at that point in the packet path.

Examples:

- DNAT changes a public destination to a private backend before forward filtering.
- SNAT changes the source after forward filtering but before the packet leaves.
- Security groups or cloud firewalls may see private addresses before NAT while external services see public addresses after NAT.
- Return traffic must pass the same stateful path unless the design intentionally supports asymmetric routing.

Debugging NAT without knowing the hook order leads to false conclusions.

## Hairpin NAT

Hairpin NAT happens when an internal client uses a service's external address and the NAT device loops traffic back inside. It is common with public DNS names used both inside and outside a network.

Failure modes:

- internal clients cannot reach the public IP,
- backend sees NAT gateway source instead of real client source,
- firewall allows external clients but not internal hairpin flows,
- TLS Host/SNI is correct but routing returns the wrong way,
- split-horizon DNS would have avoided NAT entirely.

Prefer split-horizon DNS or private load balancer names when you can. Hairpin NAT is useful, but it complicates source identity and return-path reasoning.

## NAT and DNS

DNS often decides whether NAT is used at all. The same application name can resolve to a public address, private address, load balancer address, service endpoint, or cluster-local address depending on where the query is made.

Important patterns:

| Pattern | NAT Impact |
| --- | --- |
| Public DNS from private clients | Private clients may hairpin through a NAT gateway or public load balancer to reach an internal service. |
| Split-horizon DNS | Internal clients receive private answers while external clients receive public answers, avoiding unnecessary NAT. |
| Private DNS zones | Cloud or enterprise private DNS zones return private service endpoints for provider APIs or internal services. |
| DNS64/NAT64 | IPv6-only clients receive synthesized AAAA records and reach IPv4 services through NAT64. |
| Proxy or egress gateway DNS | The proxy may resolve the name, so the client's DNS answer may not match the actual egress destination. |
| Short DNS TTLs | NAT state may outlive a DNS answer, so existing connections keep using the old translated path. |

NAT does not translate names. It translates packets after DNS has selected an address. That means a DNS mistake can make traffic use the wrong NAT gateway, bypass private endpoints, cross regions, or hit a public path when a private path exists.

DNS-specific NAT failures:

- an internal name resolves to a public IP and forces hairpin NAT,
- private service endpoint DNS is missing, so traffic exits through the NAT gateway,
- source allow lists use one NAT IP while DNS steers clients to a different egress path,
- a resolver behind NAT sends all queries from one translated IP and hits upstream DNS rate limits,
- UDP 53 NAT mappings expire during retry-heavy or lossy periods,
- EDNS or DNSSEC creates large DNS responses that expose MTU or fragmentation problems through a NAT path,
- DNS cache keeps returning an address after NAT gateway, load balancer, or private endpoint changes.

Troubleshooting flow:

```bash
dig example.com
dig @<resolver-ip> example.com
getent hosts example.com
ip route get $(dig +short example.com A | head -1)
conntrack -L -p udp --dport 53 2>/dev/null | head
tcpdump -nn -i any 'port 53 or host <resolved-ip>'
```

Compare DNS answers from the client, node, NAT gateway subnet, and upstream resolver when possible. The key question is not only "what did the name resolve to?" but "which translated path does that answer force?"

## Kubernetes and NAT

Kubernetes commonly uses NAT at several layers:

| Layer | NAT Behavior |
| --- | --- |
| Pod egress | Node, CNI, or cloud datapath may SNAT Pod IPs to node or gateway IPs. |
| Service virtual IPs | kube-proxy or replacement may DNAT Service IPs to Pod endpoints. |
| NodePort / LoadBalancer | External traffic may be DNATed to node or Pod targets. |
| `externalTrafficPolicy` | Affects source IP preservation and node-local routing. |
| Egress gateway | Centralizes outbound source identity for allow lists and audit. |

This matters for source allow lists. A vendor may need the NAT gateway IP, node IP, egress gateway IP, or load balancer IP depending on the actual path. Capture at the pod, node, and egress boundary when source identity is disputed.

DNS makes this more subtle. A Pod usually sends cluster DNS queries to CoreDNS, but CoreDNS may forward external lookups through node DNS, a cloud resolver, or an upstream resolver that sees the node, NAT gateway, or egress gateway source. For application traffic, the DNS answer determines whether the Pod connects to a ClusterIP, private endpoint, public load balancer, or internet address that then crosses SNAT.

Kubernetes NAT/DNS checks:

```bash
kubectl exec -it <pod> -- cat /etc/resolv.conf
kubectl exec -it <pod> -- nslookup example.com
kubectl exec -it <pod> -- sh -c 'ip route get $(getent hosts example.com | awk "{print \$1; exit}")'
kubectl -n kube-system logs deployment/coredns
kubectl -n kube-system get configmap coredns -o yaml
```

Common Kubernetes failure modes:

- CoreDNS forwards to an upstream resolver that is only reachable through NAT,
- NetworkPolicy allows app egress but blocks UDP/TCP 53 to CoreDNS,
- private endpoint DNS is configured on nodes but not visible from Pods,
- `ndots` search behavior creates extra external lookups and NAT load,
- NodeLocal DNSCache changes the source and cache behavior of DNS traffic,
- egress gateway policy applies to application traffic but not DNS traffic, so name resolution and connection path disagree.

## Observability

At minimum, watch:

- active connections or conntrack count,
- conntrack insert failures and drops,
- NAT gateway port allocation errors,
- DNS query volume through NAT,
- bytes and packets per gateway,
- drops by reason when the provider exposes them,
- top destinations by flow logs,
- SYN retransmits and upstream timeout rates,
- cost and cross-zone/cross-region transfer.

Useful Linux commands:

```bash
cat /proc/sys/net/netfilter/nf_conntrack_count
sysctl net.netfilter.nf_conntrack_max
conntrack -S
nft list ruleset -a
iptables -t nat -L -n -v
```

Counters should be checked before and after one controlled test flow. Aggregate graphs are useful, but they do not prove which specific tuple failed.

## Troubleshooting Flow

1. Identify the client, destination, protocol, and port.
2. Confirm route selection from the client or node.
3. Identify the NAT boundary and whether it performs SNAT, DNAT, or both.
4. Check whether the flow exists in conntrack or provider NAT metrics.
5. Capture before NAT and after NAT if you control both points.
6. Check firewall policy at the hook or service that sees the relevant address.
7. Check port exhaustion, idle timeout, and asymmetric return path.
8. Verify source identity at the destination or upstream logs.

## Common Mistakes

- Thinking NAT is security policy instead of address translation plus state.
- Allow-listing the wrong source IP because the path has multiple NAT layers.
- Routing private subnet egress through one gateway in another failure domain.
- Ignoring DNS and private endpoints, causing needless NAT cost and port pressure.
- Debugging only from the client side when the translated packet is different.
- Forgetting UDP NAT idle timeouts for DNS, QUIC, VPNs, and game/voice traffic.
- Assuming IPv6 needs NAT; most IPv6 designs use routing plus firewalling instead.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a NAT gateway usually provide?" answer="Outbound address and port translation for private workloads so they can initiate connections through shared egress addresses." %}
  {% include study-card.html question="What is the difference between SNAT and DNAT?" answer="SNAT changes the source address or port; DNAT changes the destination address or port." %}
  {% include study-card.html question="Why can NAT gateways run out of ports?" answer="Many flows sharing the same translated source IP and destination tuple can exhaust available source port mappings." %}
  {% include study-card.html question="What is hairpin NAT?" answer="An internal client reaches an internal service through the service's external NAT address, causing traffic to loop through the NAT device." %}
  {% include study-card.html question="Why does NAT complicate allow lists?" answer="The destination may see a translated gateway, node, or egress IP rather than the original client address." %}
</div>

## References

- [nftables NAT documentation](https://wiki.nftables.org/wiki-nftables/index.php/Performing_Network_Address_Translation_(NAT))
- [nftables connection tracking](https://wiki.nftables.org/wiki-nftables/index.php/Connection_Tracking_System)
- [conntrack-tools manual](https://conntrack-tools.netfilter.org/manual.html)
- [AWS NAT Gateway documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [Google Cloud NAT documentation](https://cloud.google.com/nat/docs/overview)
- [Azure NAT Gateway documentation](https://learn.microsoft.com/azure/nat-gateway/nat-overview)
