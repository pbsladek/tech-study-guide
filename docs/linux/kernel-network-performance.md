---
title: Linux Kernel Network Performance
layout: page
permalink: /docs/linux/kernel-network-performance/
summary: "Linux kernel packet processing, NAPI, softirq, NIC queues, RPS, RFS, XPS, offloads, qdisc, drops, and practical network performance troubleshooting."
tags:
  - linux
  - networking
  - performance
  - troubleshooting
---

# Linux Kernel Network Performance

Network performance on Linux is a pipeline problem. A packet moves through a NIC queue, interrupt handling, NAPI polling, softirq work, protocol processing, socket buffers, qdisc, and finally application code or the wire. A bottleneck can sit at any layer, so useful troubleshooting separates link errors, packet drops, CPU placement, queueing, retransmits, and application backpressure.

## First Checks

```bash
sar -n DEV,TCP,ETCP 1
ss -s
ip -s link
ethtool -S <interface>
cat /proc/net/softnet_stat
mpstat -P ALL 1
```

Use these commands to separate interface drops, TCP retransmits, socket pressure, softnet backlog drops, and CPU imbalance. One busy CPU doing most softirq work while other CPUs are idle usually means receive processing is not spread well, or a small number of flows dominate.

## Receive Path

On receive, the NIC writes packets into RX descriptor rings and interrupts the host. Modern drivers then use NAPI: interrupts schedule polling, and the kernel drains packets in batches. This avoids one interrupt per packet under load, but it shifts visible cost into softirq CPU.

Important receive checkpoints:

| Layer | What To Look For |
| --- | --- |
| NIC RX ring | Drops, missed packets, overruns, no-buffer counters from `ethtool -S`. |
| IRQ affinity | Whether NIC queue interrupts land on useful CPUs. |
| NAPI / softirq | High `%soft` CPU, growing `/proc/net/softnet_stat` drops, or CPU imbalance. |
| Protocol stack | TCP retransmits, resets, backlog pressure, conntrack pressure. |
| Socket receive buffer | Application not reading fast enough, receive queue growth in `ss`. |

Softirq load is still real CPU load. If network processing consumes cores, the application may look slow even though user CPU is low.

## Transmit Path

On transmit, the application writes to a socket, TCP may segment and pace data, qdisc decides when packets are released, and the NIC consumes TX descriptors. Drops can happen because the qdisc is full, the NIC queue is overloaded, shaping is configured, or lower-layer errors exist.

`tc -s qdisc show dev <interface>` is useful when latency or loss appears before the wire. A default qdisc may be fine for simple hosts, but traffic shaping, fq, fq_codel, and classful qdiscs change how queueing and drops behave.

## Scaling Across CPUs

Linux has several mechanisms for spreading network work:

| Mechanism | Purpose |
| --- | --- |
| RSS | NIC hardware hashes flows across receive queues. |
| RPS | Kernel steers receive packet processing to configured CPUs. |
| RFS | Kernel steers receive processing toward the CPU running the consuming application thread. |
| Accelerated RFS | Hardware-assisted steering when the NIC and driver support it. |
| XPS | Kernel chooses transmit queues based on CPU or receive-queue affinity. |

These tools are not automatically better in every environment. On a host with one hardware queue and many CPUs, RPS may help. On a host where RSS already maps queues cleanly to CPUs, extra RPS can add overhead. For latency-sensitive work, NUMA locality and cache locality matter as much as raw parallelism.

Useful places to inspect:

```bash
cat /proc/interrupts
cat /proc/softirqs
cat /sys/class/net/<interface>/queues/rx-0/rps_cpus
cat /sys/class/net/<interface>/queues/rx-0/rps_flow_cnt
cat /sys/class/net/<interface>/queues/tx-0/xps_cpus
```

## Offloads

NIC and kernel offloads reduce per-packet CPU cost by doing larger chunks of work at once.

| Offload | What It Does |
| --- | --- |
| Checksum offload | NIC computes or verifies packet checksums. |
| TSO | TCP segmentation offload: NIC splits large TCP buffers into wire-sized packets. |
| GSO | Generic segmentation offload in the kernel. |
| GRO | Generic receive offload: kernel coalesces related received packets before upper-layer processing. |
| LRO | Large receive offload, usually avoided on routers/bridges because it can distort packets being forwarded. |

Offloads can make packet captures confusing because tcpdump may see packets before segmentation or checksum completion. Disable offloads briefly only for controlled debugging; leaving them off can waste CPU.

```bash
ethtool -k <interface>
ethtool -K <interface> gro off tso off gso off
```

## Drops, Retransmits, and Queue Pressure

Do not treat every drop counter the same. A drop at the NIC ring, softnet backlog, qdisc, conntrack table, or socket buffer points at a different fix.

Common interpretations:

- RX errors or missed packets: physical link, driver, NIC ring, or host CPU not draining fast enough.
- `/proc/net/softnet_stat` drops: per-CPU network backlog pressure.
- TCP retransmits: loss, reordering, overloaded middleboxes, bad path, or receiver pressure.
- Large send or receive queues in `ss`: application, peer, congestion window, or buffer pressure.
- Full conntrack table: new stateful connections can fail even when some established flows continue.

## Sysctls and Limits

Kernel network tunables are sharp tools. Change them only after measuring the bottleneck and recording the old values.

Useful areas:

| Tunable Area | Why It Matters |
| --- | --- |
| `net.core.netdev_max_backlog` | Maximum packets queued on the per-CPU input backlog. |
| `net.core.rmem_max` / `net.core.wmem_max` | Upper bounds for socket buffers. |
| `net.ipv4.tcp_rmem` / `net.ipv4.tcp_wmem` | TCP buffer autotuning ranges. |
| `net.core.somaxconn` | Upper cap on listen backlog. |
| `net.ipv4.tcp_max_syn_backlog` | Queue for half-open TCP handshakes. |

Tune the kernel and the application together. An application backlog of `128` cannot use a host `somaxconn` of `4096`; the effective limit is constrained by both.

## Runbook

1. Confirm which namespace and interface the traffic uses.
2. Check link counters with `ip -s link` and NIC counters with `ethtool -S`.
3. Check TCP health with `sar -n TCP,ETCP`, `ss -s`, and `ss -ti`.
4. Check per-CPU softirq and backlog pressure with `/proc/softirqs`, `/proc/net/softnet_stat`, and `mpstat`.
5. Check RSS/RPS/RFS/XPS, IRQ affinity, and NUMA placement before changing sysctls.
6. Inspect qdisc statistics if latency or drops happen before transmit.
7. Make one change at a time, capture before/after counters, and keep a rollback.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does NAPI change about packet receive handling?" answer="It lets the driver switch from interrupt-driven notification to batched polling, usually processed through softirq context." %}
  {% include study-card.html question="What is RPS?" answer="Receive Packet Steering, a kernel mechanism that spreads receive packet processing across configured CPUs." %}
  {% include study-card.html question="Why can offloads confuse packet captures?" answer="Captures may observe packets before checksum completion or before large buffers are segmented into wire-sized packets." %}
  {% include study-card.html question="What does /proc/net/softnet_stat help reveal?" answer="Per-CPU network backlog pressure, including drops when the kernel cannot drain receive work fast enough." %}
</div>

## References

- [Linux kernel NAPI documentation](https://docs.kernel.org/networking/napi.html)
- [Scaling in the Linux Networking Stack](https://docs.kernel.org/networking/scaling.html)
- [Linux kernel IP sysctl documentation](https://docs.kernel.org/networking/ip-sysctl.html)
- [ethtool documentation](https://man7.org/linux/man-pages/man8/ethtool.8.html)
- [tc documentation](https://man7.org/linux/man-pages/man8/tc.8.html)
