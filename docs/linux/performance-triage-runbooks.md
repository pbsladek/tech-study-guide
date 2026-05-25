---
title: Linux Performance Triage Runbooks
layout: page
permalink: /docs/linux/performance-triage-runbooks/
summary: "Symptom-driven Linux runbooks for high CPU, high load, memory pressure, disk latency, softirq saturation, file descriptor exhaustion, and cgroup throttling."
tags:
  - linux
  - performance
  - runbooks
  - troubleshooting
---

# Linux Performance Triage Runbooks

Performance triage starts by naming the bottleneck. "The server is slow" is not actionable. The first split is CPU, run queue, memory reclaim, disk latency, network softirq, file descriptor pressure, cgroup throttling, or dependency latency.

These runbooks are meant for the first 10 minutes of an incident.

## First Checks

```bash
uptime
vmstat 1
mpstat -P ALL 1
iostat -xz 1
pidstat -durh 1
cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io
```

Capture before restarting. Restarts often erase the evidence that explains the incident.

## High CPU

Goal: identify whether CPU is user code, kernel work, interrupts, softirq, or steal time.

```bash
mpstat -P ALL 1
top -H -p <pid>
pidstat -t -p <pid> 1
perf top
```

Interpretation:

| Signal | Likely Cause |
| --- | --- |
| High `%usr` | Application code or runtime work. |
| High `%sys` | Syscall-heavy workload, kernel path, filesystem, network, or locks. |
| High `%soft` | Network or block softirq processing. |
| High `%steal` | Hypervisor contention. |

## High Load, Low CPU

High load with low CPU usually means tasks are runnable but not scheduled, or stuck in uninterruptible sleep.

```bash
ps -eo state,pid,ppid,comm,wchan:32 --sort=state | head -50
cat /proc/pressure/cpu
cat /proc/pressure/io
```

Many `D` state tasks point toward storage, filesystem, NFS, block devices, or kernel waits. Many runnable tasks point toward CPU saturation or scheduler contention.

## Memory Pressure

```bash
free -h
cat /proc/meminfo
cat /proc/pressure/memory
vmstat 1
journalctl -k -g 'oom|Out of memory|Killed process'
```

Decide whether pressure is process RSS, page cache/writeback, slab, swap, or cgroup limit. For containers, check cgroup memory files before blaming the node.

## Disk Latency

```bash
iostat -xz 1
pidstat -d 1
lsblk -o NAME,TYPE,MODEL,ROTA,SIZE,MOUNTPOINTS
journalctl -k -g 'I/O error|nvme|scsi|reset|EXT4|XFS'
```

Look for high await, high utilization, queue depth, errors, resets, and one process dominating writes or fsyncs.

## Network Softirq Saturation

```bash
sar -n DEV,TCP,ETCP 1
mpstat -P ALL 1
cat /proc/softirqs
cat /proc/net/softnet_stat
ethtool -S <interface>
```

One CPU doing most softirq work points at queue placement, RSS/RPS/RFS/XPS, IRQ affinity, or one dominant flow.

## File Descriptor Exhaustion

```bash
cat /proc/sys/fs/file-nr
ls -l /proc/<pid>/fd | wc -l
cat /proc/<pid>/limits
lsof -p <pid> | head
ss -s
```

`EMFILE` means the process hit its limit. `ENFILE` means the system-wide file table is under pressure.

## Cgroup Throttling and Noisy Neighbors

```bash
cat /proc/<pid>/cgroup
cat /sys/fs/cgroup/cpu.stat
cat /sys/fs/cgroup/memory.events
cat /sys/fs/cgroup/io.stat
```

CPU throttling, memory high events, and I/O limits can make a service slow while host-level resources look available.

## Runbook

1. Capture `uptime`, `vmstat`, `mpstat`, `iostat`, `pidstat`, and PSI.
2. Pick one dominant bottleneck; do not tune everything at once.
3. Identify affected process, cgroup, device, interface, or dependency.
4. Mitigate with the smallest reversible action: reduce concurrency, shed load, move traffic, pause batch work, raise a limit, or restart one bad process.
5. Save before/after counters.
6. Convert the finding into an alert or dashboard gap.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does high load with low CPU often suggest?" answer="Tasks may be stuck in uninterruptible sleep or waiting on IO rather than consuming CPU." %}
  {% include study-card.html question="Why check PSI during performance triage?" answer="It shows time tasks lost waiting for CPU, memory, or IO resources." %}
  {% include study-card.html question="What is the difference between EMFILE and ENFILE?" answer="EMFILE is a per-process file descriptor limit; ENFILE is system-wide file table pressure." %}
  {% include study-card.html question="Why can cgroup throttling hide behind healthy host metrics?" answer="A workload can hit its cgroup CPU, memory, or IO limit while the host still has spare capacity." %}
</div>

## References

- [Linux PSI documentation](https://docs.kernel.org/accounting/psi.html)
- [proc(5)](https://man7.org/linux/man-pages/man5/proc.5.html)
- [perf top documentation](https://man7.org/linux/man-pages/man1/perf-top.1.html)
- [iostat documentation](https://man7.org/linux/man-pages/man1/iostat.1.html)
