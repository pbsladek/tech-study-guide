---
title: Cross-Layer Incident Runbooks
layout: page
permalink: /docs/networking/cross-layer-incident-runbooks/
summary: "Operational runbooks that trace application symptoms through DNS, TCP, TLS, proxies, Linux hosts, Kubernetes Services, CNI, NAT, and cloud networking."
tags:
  - networking
  - linux
  - kubernetes
  - troubleshooting
---

# Cross-Layer Incident Runbooks

Production network incidents rarely stay inside one layer. An HTTP 504 can be an overloaded app, a stale EndpointSlice, a proxy timeout, a DNS answer pointing at the wrong load balancer, a conntrack table at capacity, or a Pod-to-node datapath issue. The job is to preserve evidence and walk from symptom to boundary, not to tune the first knob that looks familiar.

## Command Examples

Capture the exact source, destination name, resolved address, port, protocol, timestamp, and error string before changing state.

```bash
date -Is
getent hosts api.example.com
curl -v --connect-timeout 3 --max-time 10 https://api.example.com/health
ss -tanp '( dport = :443 or sport = :443 )'
ip route get "$(getent ahostsv4 api.example.com | awk 'NR==1 {print $1}')"
journalctl -k --since -10min -g 'TCP|conntrack|DROP|REJECT|martian|oom'
```

In Kubernetes, collect API state and datapath hints together:

```bash
kubectl get pod,svc,endpointslice,ingress,gateway -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -50
kubectl -n kube-system get pods -o wide
kubectl -n kube-system logs deployment/coredns --since=10m
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `date -Is` | `2026-06-06T10:24:33-07:00`. | Pins evidence to a timestamp before logs rotate or retries change state. |
| `curl -v --connect-timeout 3 --max-time 10 https://api.example.com/health` | Connect, TLS, and HTTP status timing. | Places the symptom at the client, edge, proxy, or application boundary. |
| `kubectl -n kube-system logs deployment/coredns --since=10m` | CoreDNS query errors, SERVFAILs, or normal answers. | Checks whether DNS is part of the incident window. |

## HTTP 504

An HTTP 504 means a gateway or proxy timed out waiting for an upstream response. It does not prove the upstream process was down.

| Boundary | What To Prove | Evidence |
| --- | --- | --- |
| Client to edge | DNS, TCP, TLS, and HTTP reach the gateway. | `curl -v`, SNI, access logs. |
| Edge route | Host/path matched the intended backend. | proxy route config, ingress status, Gateway route status. |
| Upstream selection | Backend endpoints were healthy and ready. | EndpointSlices, load-balancer target health, proxy upstream stats. |
| Backend path | The app accepted and completed the request. | app logs, `ss`, latency metrics, dependency traces. |
| Timeout budget | Outer timeouts are longer than expected inner work. | client, LB, proxy, app, database timeout config. |

Practical checks:

```bash
curl -vk --resolve api.example.com:443:198.51.100.10 https://api.example.com/slow
kubectl get endpointslice -l kubernetes.io/service-name=api -o wide
kubectl logs deploy/api --since=10m | grep -E 'timeout|deadline|upstream|cancel'
```

If backend logs show work finishing after the proxy gives up, fix timeout budget or make the operation asynchronous. If backend logs show no request, focus on route matching, EndpointSlices, NetworkPolicy, kube-proxy or CNI state, and proxy upstream health.

## Connection Refused

`ECONNREFUSED` means a TCP reset came back. That usually means the destination host was reachable but no process accepted the port, or a firewall actively rejected the flow.

```bash
nc -vz api.example.com 443
ss -ltnp | grep ':443'
tcpdump -nn -i any 'tcp port 443 and (tcp[tcpflags] & (tcp-rst|tcp-syn) != 0)'
```

In Kubernetes:

```bash
kubectl get svc api -o yaml
kubectl get endpointslice -l kubernetes.io/service-name=api -o yaml
kubectl exec deploy/client -- nc -vz api.default.svc.cluster.local 443
kubectl exec deploy/client -- nc -vz <pod-ip> 8443
```

If direct Pod IP works but Service IP fails, inspect kube-proxy replacement, EndpointSlices, service port and targetPort, and node-local datapath. If Pod IP refuses, inspect container ports, app bind address, readiness, and process listeners.

## Connection Reset

Resets are active aborts. They may come from the app, kernel, proxy, firewall, load balancer, or peer.

```bash
tcpdump -nn -i any 'host 203.0.113.10 and tcp[tcpflags] & tcp-rst != 0'
ss -ti dst 203.0.113.10
journalctl -u nginx --since -10min
journalctl -k --since -10min -g 'reset|conntrack|nf_conntrack'
```

Use sequence numbers and capture position to identify who sent the reset. A reset from the proxy after an idle period points at timeout alignment. A reset immediately after ClientHello often points at TLS policy, SNI, ALPN, or mTLS mismatch.

## TLS Timeout or Handshake Failure

Separate TCP connection, TLS handshake, certificate validation, and HTTP.

```bash
openssl s_client -connect api.example.com:443 -servername api.example.com -showcerts
curl -vk --tlsv1.3 https://api.example.com/
tcpdump -nn -i any 'host 198.51.100.10 and port 443'
```

| Symptom | Likely Boundary |
| --- | --- |
| TCP SYN retransmits | route, firewall, NAT, listener, or return path. |
| ClientHello sent, no ServerHello | TLS policy, SNI routing, proxy, blocked large packet, or backend stall. |
| Certificate verify failed | trust store, missing intermediate, SAN, expiry, or private CA. |
| mTLS alert | missing client certificate, wrong client CA, EKU, SPIFFE/SAN policy, or proxy termination. |

## DNS Intermittent

DNS intermittency is usually cache scope, negative caching, split-horizon routing, resolver health, UDP loss, or search-path amplification.

```bash
getent hosts api.example.com
dig api.example.com A
dig api.example.com AAAA
dig @<configured-resolver> api.example.com A +tries=1 +time=2
dig +tcp @<configured-resolver> api.example.com A
resolvectl status
```

In Kubernetes:

```bash
kubectl exec deploy/client -- cat /etc/resolv.conf
kubectl exec deploy/client -- nslookup api.default.svc.cluster.local
kubectl -n kube-system logs deployment/coredns --since=10m
kubectl get networkpolicy -A
```

If UDP DNS fails but TCP DNS succeeds, check MTU, fragments, firewall state, and conntrack. If only short names fail, inspect search domains and `ndots`.

## Large Requests Hang

Small requests working while large requests hang is a classic MTU, fragmentation, proxy body-size, TLS record, or backend streaming problem.

```bash
tracepath api.example.com
ping -M do -s 1472 api.example.com
curl -v --data-binary @large.bin https://api.example.com/upload
tcpdump -nn -i any 'icmp or host 198.51.100.10'
```

For overlay, VPN, or cloud paths, account for VXLAN, Geneve, IPsec, WireGuard, GRE, and provider encapsulation overhead. MSS clamping can protect TCP, but it does not fix UDP or the underlying PMTUD failure.

## Node Can Reach Service but Pod Cannot

This usually means the node network namespace path differs from the Pod network namespace path.

```bash
kubectl exec deploy/client -- ip addr
kubectl exec deploy/client -- ip route
kubectl exec deploy/client -- curl -v http://api.default.svc.cluster.local:8080
kubectl debug node/<node> -it --image=busybox
```

Check these differences:

| Difference | What It Can Break |
| --- | --- |
| DNS config | Pod search paths, CoreDNS, NodeLocal DNSCache, or NetworkPolicy. |
| Source address | Firewall, cloud security group, app allowlist, or mTLS identity. |
| Route table | CNI routes, overlay tunnel, Pod CIDR route, or egress gateway. |
| NetworkPolicy | Pod egress denied while node traffic is unrestricted. |
| Service datapath | kube-proxy, IPVS, nftables, or eBPF replacement differs per node. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does an HTTP 504 prove?" answer="A gateway or proxy timed out waiting for an upstream response; it does not by itself prove the backend process was down." %}
  {% include study-card.html question="Why test direct Pod IP after Service IP fails?" answer="It separates workload listener behavior from Service, EndpointSlice, kube-proxy, or CNI datapath behavior." %}
  {% include study-card.html question="Why can large requests hang while small requests work?" answer="MTU, fragmentation, PMTUD, proxy body limits, or streaming behavior may affect only larger payloads." %}
</div>

## References

- [Packet Path](/docs/networking/packet-path/)
- [TCP and Sockets](/docs/networking/tcp-sockets/)
- [Certificates and HTTPS](/docs/networking/certificates-https/)
- [Kubernetes Services and EndpointSlices](/docs/kubernetes/services-endpointslices/)
- [Kubernetes Pod Networking and CNI](/docs/kubernetes/pod-networking-cni/)
