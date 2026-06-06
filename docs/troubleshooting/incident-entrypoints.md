---
title: Incident Entry Points
layout: page
permalink: /docs/troubleshooting/incident-entrypoints/
summary: "Symptom-first entry points for timeouts, resets, DNS works on the node but not in Pods, large payload hangs, and intermittent 5xx failures."
tags:
  - troubleshooting
  - networking
  - linux
  - kubernetes
---

# Incident Entry Points

Start with the symptom the caller sees, then move toward the layer that can prove or disprove it. These entry points link back to the deeper pages, but keep the first ten minutes of an incident concrete.

## Command Examples

```bash
date -Is
curl -v --connect-timeout 3 --max-time 15 "$URL"
getent hosts "$HOST"
ip route get "$IP"
ss -tanp
journalctl -k --since -10min -g 'TCP|conntrack|DROP|REJECT|oom|reset'
```

For Kubernetes:

```bash
kubectl get pod,svc,endpointslice,ingress,gateway -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -50
kubectl exec deploy/client -- curl -v "$URL"
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `curl -v --connect-timeout 3 --max-time 15 "$URL"` | Connection timing, TLS details, response headers, or timeout. | Anchors the user-visible symptom in one reproducible request. |
| `journalctl -k --since -10min -g 'TCP|conntrack|DROP|REJECT|oom|reset'` | Kernel log lines for drops, conntrack, resets, or OOM kills. | Finds host-level evidence that dashboards often miss. |
| `kubectl get events -A --sort-by=.lastTimestamp | tail -50` | Recent scheduling, readiness, pull, probe, or endpoint events. | Adds cluster control-plane context to the same incident window. |

## Symptom Map

| Symptom | First Split | Likely Pages |
| --- | --- | --- |
| Timeout | SYN timeout, TLS timeout, HTTP 504, DB timeout, or queue wait. | [Request Path](/docs/networking/request-path/), [Cross-Layer Incident Runbooks](/docs/networking/cross-layer-incident-runbooks/), [Resilience, Timeouts, and Draining](/docs/networking/resilience-timeouts-draining/) |
| Reset | RST before TLS, after idle, during upload, or from proxy. | [TCP and Sockets](/docs/networking/tcp-sockets/), [Packet Capture and Analysis](/docs/networking/packet-capture-analysis/) |
| DNS works on node but not Pod | Resolver config, NetworkPolicy, CoreDNS, NodeLocal DNSCache, or CNI. | [Kubernetes DNS and CoreDNS](/docs/kubernetes/dns-coredns/), [Pod Networking and CNI](/docs/kubernetes/pod-networking-cni/) |
| Large payload hangs | MTU, fragmentation, proxy body limit, TLS record path, or streaming timeout. | [Packet Path](/docs/networking/packet-path/), [ICMP, MTU, and Path Testing](/docs/networking/icmp-mtu-path-testing/) |
| Intermittent 5xx | Endpoint churn, load balancer health, retries, database pool, or partial node datapath. | [Load Balancers and Proxies](/docs/networking/load-balancers-proxies/), [Kubernetes Services and EndpointSlices](/docs/kubernetes/services-endpointslices/) |

## Timeouts

Timeouts are not one failure. Split them by boundary:

```bash
curl -v --connect-timeout 2 --max-time 10 https://api.example.com/
openssl s_client -connect api.example.com:443 -servername api.example.com -brief
tcpdump -nn -i any 'host 198.51.100.10 and tcp'
```

If connect times out, inspect route, firewall, NAT, listener, and return path. If TLS times out, inspect SNI, ALPN, certificate policy, large packets, and proxy routing. If HTTP returns 504, inspect upstream health and timeout budget.

## Resets

Resets are active signals. Identify who sent the RST before changing policy.

```bash
tcpdump -nn -i any 'tcp[tcpflags] & tcp-rst != 0'
ss -tanpi
journalctl -u nginx --since -10min
```

RST immediately after SYN usually means connection refused or reject. RST after idle usually means timeout alignment. RST after ClientHello often means TLS policy, SNI, ALPN, mTLS, or proxy mismatch.

## DNS Works On Node But Not Pod

```bash
kubectl exec deploy/client -- cat /etc/resolv.conf
kubectl exec deploy/client -- nslookup kubernetes.default.svc.cluster.local
kubectl exec deploy/client -- nslookup api.example.com
kubectl -n kube-system logs deployment/coredns --since=10m
kubectl get networkpolicy -A
```

Compare the node resolver, Pod resolver, CoreDNS Service, NodeLocal DNSCache, and NetworkPolicy. A node shell is not proof of Pod DNS.

## Large Payloads Hang

```bash
tracepath api.example.com
ping -M do -s 1472 api.example.com
curl -v --data-binary @large.bin https://api.example.com/upload
tcpdump -nn -i any 'icmp or host 198.51.100.10'
```

If small requests work and large ones hang, inspect MTU, ICMP Packet Too Big, proxy request body limits, upload buffering, and database write latency.

## Intermittent 5xx

Intermittent 5xx is usually partial capacity, partial routing, or partial dependency failure.

```bash
kubectl get endpointslice -l kubernetes.io/service-name=api -o wide
kubectl get pods -l app=api -o wide
kubectl logs deploy/api --since=10m | grep -E '5..|timeout|reset|pool|deadline'
```

Look for one bad node, one bad endpoint, a small subset of failing request IDs, endpoint churn during rollout, or retries amplifying a dependency issue.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why start incidents from symptoms?" answer="The visible error narrows which boundary to test first while preserving evidence from the caller's point of view." %}
  {% include study-card.html question="Why is node DNS not proof of Pod DNS?" answer="Pods have their own resolver config, search paths, NetworkPolicy, CoreDNS path, and sometimes NodeLocal DNSCache behavior." %}
  {% include study-card.html question="What does intermittent 5xx often imply?" answer="A partial failure such as one backend, one node, one route, endpoint churn, or a dependency pool problem." %}
</div>

## References

- [Troubleshooting and Error Handling](/docs/troubleshooting/)
- [Request Path](/docs/networking/request-path/)
- [Cross-Layer Incident Runbooks](/docs/networking/cross-layer-incident-runbooks/)
- [Kubernetes DNS and CoreDNS](/docs/kubernetes/dns-coredns/)
