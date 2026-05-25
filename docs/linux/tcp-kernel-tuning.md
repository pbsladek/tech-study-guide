---
title: Linux TCP Kernel Tuning
layout: page
permalink: /docs/linux/tcp-kernel-tuning/
summary: "Linux TCP listen queues, SYN backlog, socket buffers, ephemeral ports, TIME_WAIT, keepalives, conntrack pressure, and safe sysctl tuning."
tags:
  - linux
  - networking
  - tcp
  - troubleshooting
---

# Linux TCP Kernel Tuning

TCP tuning is mostly about queues, memory, timers, and state. The common mistake is changing a sysctl because it sounds related instead of proving which queue or state table is actually limiting traffic.

## First Checks

```bash
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_max_syn_backlog
sysctl net.ipv4.ip_local_port_range
sysctl net.ipv4.tcp_fin_timeout
ss -ltn
cat /proc/net/sockstat
```

These checks show backlog caps, handshake queue sizing, outbound port range, FIN timing, listening sockets, and aggregate socket memory/state.

## Listen Backlog and Accept Queues

A TCP server has more than one queue:

| Queue | What It Holds |
| --- | --- |
| SYN backlog | Half-open connections during the handshake. |
| Accept queue | Fully established connections waiting for the application to accept them. |
| Application workers | Requests after the application accepts the socket. |

`net.ipv4.tcp_max_syn_backlog` affects the SYN backlog. `net.core.somaxconn` caps the backlog requested by `listen(2)`. The application also passes its own backlog value, so the effective accept queue is constrained by both kernel and application settings.

Symptoms of pressure include connection timeouts, SYN retransmits, `ListenOverflows`, `ListenDrops`, and full receive queues in `ss -ltn`.

```bash
netstat -s | grep -Ei 'listen|overflow|drop|syn'
ss -ltn
ss -tan state syn-recv
```

### Backlog Saturation Lab

Use a lab host or disposable VM. The goal is to see the difference between half-open SYN pressure and established connections waiting for `accept()`.

Terminal 1: run a deliberately slow listener with a tiny backlog:

```text
python3 - <<'PY'
import socket, time
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", 8080))
s.listen(1)
print("listening on 8080 with backlog=1")
while True:
    time.sleep(30)
PY
```

Terminal 2: create connection pressure:

```text
for i in $(seq 1 200); do nc -vz 127.0.0.1 8080 >/dev/null 2>&1 & done
wait
```

Terminal 3: watch queue evidence:

```text
ss -ltn sport = :8080
ss -tan state syn-recv sport = :8080
netstat -s | grep -Ei 'listen|overflow|drop|syn'
sysctl net.core.somaxconn net.ipv4.tcp_max_syn_backlog
```

Interpretation:

| Evidence | Meaning |
| --- | --- |
| `Recv-Q` on listening socket near `Send-Q` | Established accept queue is full or near full. |
| `ListenOverflows` / `ListenDrops` rising | Application is not accepting fast enough or backlog is too small. |
| Many `SYN-RECV` sockets | Handshakes are stuck before accept queue completion. |
| SYN retransmits from clients | The server or path is dropping or delaying handshake progress. |
| Larger `somaxconn` but unchanged behavior | Application backlog or worker accept loop is still the limiter. |

SYN cookies can help a host survive SYN floods, but they are not a substitute for understanding why legitimate handshakes or accepts are backing up.

## Socket Buffers and Autotuning

TCP receive and send buffers let the kernel absorb bursts and keep the pipe full while applications and peers run at different speeds. Linux autotunes TCP buffers within configured ranges.

Useful tunables:

| Tunable | Meaning |
| --- | --- |
| `net.ipv4.tcp_rmem` | Minimum, default, and maximum TCP receive buffer autotuning values. |
| `net.ipv4.tcp_wmem` | Minimum, default, and maximum TCP send buffer autotuning values. |
| `net.core.rmem_max` | Maximum receive socket buffer requested by applications. |
| `net.core.wmem_max` | Maximum send socket buffer requested by applications. |
| `net.ipv4.tcp_mem` | System-wide TCP memory pressure thresholds. |

Large buffers can improve throughput on high-bandwidth, high-latency paths, but they can also hide application slowness and increase memory use. Confirm bandwidth-delay product before raising buffers broadly.

## Ephemeral Ports

Outbound connections need local ephemeral ports. Port exhaustion can happen on clients, proxies, NAT gateways, health checkers, and busy test runners.

Check the available range and current socket state:

```bash
sysctl net.ipv4.ip_local_port_range
ss -tan state time-wait
ss -tan state established
cat /proc/net/sockstat
```

A wider port range helps only if the real limit is local port availability. NAT, conntrack, remote tuple reuse rules, or application connection churn may still be the actual constraint.

## TIME_WAIT, FIN, and Reuse

`TIME_WAIT` is a correctness state, not automatically a bug. It prevents delayed packets from an old connection being misinterpreted as part of a new one. Aggressively reducing TCP timers can create rare, hard-to-debug failures under load.

Operational guidance:

- Prefer connection pooling and keepalives over constant connect/close churn.
- Tune clients, load balancers, NAT, and servers as one path.
- Avoid old internet advice around unsafe TIME_WAIT reuse settings without checking current kernel behavior.
- Treat `tcp_fin_timeout` as one timer among many, not a general fix for port exhaustion.

## Keepalives and Application Health

TCP keepalive detects dead peers slowly by default. Application protocols, load balancers, proxies, and service meshes often have their own idle timeouts. Align them deliberately.

Useful settings:

```bash
sysctl net.ipv4.tcp_keepalive_time
sysctl net.ipv4.tcp_keepalive_intvl
sysctl net.ipv4.tcp_keepalive_probes
```

Keepalive proves that a TCP peer responds, not that the application is healthy or that a request can complete within its timeout budget.

## Conntrack Pressure

On stateful firewalls, NAT hosts, Kubernetes nodes, and container hosts, connection tracking can be the hidden limit. A full conntrack table can break new connections while existing ones continue.

```bash
conntrack -S
conntrack -L | head
sysctl net.netfilter.nf_conntrack_max
cat /proc/sys/net/netfilter/nf_conntrack_count
```

Raise conntrack limits only after checking memory impact and why entries are accumulating. UDP, DNS, short-lived TCP, and probes can fill conntrack faster than expected.

## Tuning Discipline

1. Identify the failing state: SYN, established, TIME_WAIT, close-wait, retransmits, or no local ports.
2. Check application backlog, worker capacity, and accept rate before changing kernel limits.
3. Check host memory, conntrack, and per-service cgroup limits.
4. Apply persistent sysctls through `/etc/sysctl.d/` with comments and a rollback.
5. Test under representative concurrency, not a single curl loop.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does net.core.somaxconn cap?" answer="The listen backlog requested by applications with listen(2)." %}
  {% include study-card.html question="What does tcp_max_syn_backlog affect?" answer="The queue of half-open TCP handshakes waiting to complete." %}
  {% include study-card.html question="Why can ephemeral ports run out?" answer="A client, proxy, NAT host, or busy service may create more concurrent or recently closed outbound connections than its local port tuples allow." %}
  {% include study-card.html question="Why is TIME_WAIT not automatically bad?" answer="It prevents delayed packets from an old connection being accepted as part of a new connection." %}
</div>

## References

- [Linux kernel IP sysctl documentation](https://docs.kernel.org/networking/ip-sysctl.html)
- [tcp(7)](https://man7.org/linux/man-pages/man7/tcp.7.html)
- [socket(7)](https://man7.org/linux/man-pages/man7/socket.7.html)
- [ss(8)](https://man7.org/linux/man-pages/man8/ss.8.html)
- [sysctl(8)](https://man7.org/linux/man-pages/man8/sysctl.8.html)
