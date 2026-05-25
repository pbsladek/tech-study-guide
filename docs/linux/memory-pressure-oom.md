---
title: Linux Memory Pressure and OOM
layout: page
permalink: /docs/linux/memory-pressure-oom/
summary: "Linux memory troubleshooting for RSS, VSZ, page cache, slab, THP, NUMA, swap, cgroup memory, PSI, and OOM killer behavior."
tags:
  - linux
  - memory
  - oom
  - performance
  - troubleshooting
---

# Linux Memory Pressure and OOM

Linux memory incidents are usually not "free memory is low." The kernel uses memory for page cache, slab, anonymous pages, file mappings, buffers, kernel stacks, and cgroups. Healthy systems often keep free memory low because unused RAM is wasted RAM.

The operational question is whether reclaim, compaction, swapping, cgroup limits, Pressure Stall Information, or the OOM killer are affecting workloads.

## First Checks

```bash
free -h
cat /proc/meminfo
cat /proc/pressure/memory
vmstat 1
ps -eo pid,ppid,comm,rss,vsz,%mem --sort=-rss | head
journalctl -k -g 'Out of memory|Killed process|oom-kill'
```

Start with system pressure, then separate process RSS, kernel memory, page cache, swap activity, and cgroup limits.

## Memory Types

| Term | Meaning | Incident Signal |
| --- | --- | --- |
| RSS | Resident physical pages mapped into a process. | Large or growing process memory use. |
| VSZ / VIRT | Virtual address space reserved or mapped by a process. | Often high without real pressure; not a leak by itself. |
| Anonymous memory | Heap, stack, and private writable pages not backed by files. | Main source of process memory pressure. |
| Page cache | File data cached by the kernel. | Usually reclaimable, but writeback or dirty pages can stall. |
| Slab | Kernel object caches. | Can reveal dentries, inodes, conntrack, or filesystem pressure. |
| Buffers | Block-device metadata buffers. | Usually less important than page cache/slab. |
| Swap | Disk-backed memory extension. | Sustained swap-in/out indicates pressure and latency risk. |

`available` memory is usually a better quick signal than `free` memory because it estimates memory that can be used without heavy reclaim.

## Page Cache and Reclaim

Linux aggressively caches file data. Page cache is useful until reclaim has to fight active workloads.

Useful checks:

```bash
grep -E 'MemAvailable|Cached|Dirty|Writeback|Slab|SReclaimable|SUnreclaim' /proc/meminfo
sar -B 1
vmstat 1
```

Watch for sustained page scanning, dirty writeback stalls, and low `MemAvailable`. Dropping caches is rarely a fix; it can hide evidence and make the next read path slower.

## OOM Killer

The OOM killer chooses a victim when the kernel cannot satisfy memory allocation after reclaim. The decision uses badness scoring, memory use, privileges, and `oom_score_adj`.

Inspect scores:

```bash
cat /proc/<pid>/oom_score
cat /proc/<pid>/oom_score_adj
grep -E 'VmRSS|VmSize|RssAnon|RssFile|RssShmem' /proc/<pid>/status
```

In containers, the kernel can kill a process because the cgroup limit is hit even when the host has memory available.

## Cgroups and Containers

For cgroup v2:

```bash
cat /sys/fs/cgroup/memory.current
cat /sys/fs/cgroup/memory.max
cat /sys/fs/cgroup/memory.high
cat /sys/fs/cgroup/memory.events
cat /sys/fs/cgroup/memory.pressure
```

Important events:

| Event | Meaning |
| --- | --- |
| `high` | Workload exceeded `memory.high` and was throttled/reclaimed. |
| `max` | Workload hit `memory.max`. |
| `oom` | Cgroup allocation failed and OOM handling ran. |
| `oom_kill` | A task in the cgroup was killed. |

Kubernetes memory limits map to cgroup limits. A pod can be OOMKilled while the node looks mostly healthy.

## OOM Comparison Matrix

| OOM Shape | Boundary | Evidence | Common Fix |
| --- | --- | --- | --- |
| Host OOM | Whole node memory is exhausted after reclaim. | `dmesg`, `journalctl -k`, low available memory, host OOM victim. | Reduce node pressure, add memory, tune workload placement, fix leaks. |
| cgroup OOM | A service or container cgroup hits `memory.max`. | `memory.events` `oom_kill`, container exit, host may still have memory. | Raise limit, reduce heap/native/page-cache use, split sidecars, fix leaks. |
| kubelet eviction | Node pressure crosses eviction thresholds. | Pod `Evicted`, kubelet events, node pressure conditions. | Adjust requests, free ephemeral storage/memory, fix noisy workloads. |
| Application heap OOM | Runtime heap limit is hit before cgroup limit. | JVM/Go/Python/node error logs, heap dumps, process exit. | Tune runtime heap, fix allocations, account for native memory. |

Do not assume every `OOMKilled` is a node outage. The first split is host boundary, cgroup boundary, kubelet eviction, or language runtime.

## Runtime Memory Examples

Language runtimes reserve and report memory differently, so a single RSS number does not explain the whole failure.

| Runtime Shape | What Uses Memory | Common Surprise | First Checks |
| --- | --- | --- | --- |
| Java service | Java heap, metaspace, thread stacks, direct buffers, JIT/code cache, mmap files, native libraries. | `-Xmx` is not the container limit; native memory can push RSS beyond heap. | `jcmd <pid> VM.native_memory summary`, GC logs, `-XX:MaxRAMPercentage`, cgroup limit. |
| Go service | Go heap, goroutine stacks, spans, caches, mmap, Cgo/native allocations. | Go may hold memory for reuse after GC, so RSS can stay high after heap drops. | `GODEBUG=gctrace=1`, pprof heap, `runtime.MemStats`, cgroup memory. |
| Native C/C++ service | malloc arenas, thread stacks, mmap regions, file mappings, allocator fragmentation. | Leaks may be outside application metrics, and glibc arenas can grow with thread count. | `/proc/<pid>/smaps_rollup`, `pmap -x`, allocator stats, `perf`, ASAN in test. |
| Python/Node service | Managed heap plus native extensions, buffers, JIT/runtime overhead, mmap files. | Runtime heap limit and cgroup limit can disagree. | Runtime heap tools, `/proc/<pid>/status`, cgroup events. |

Example: a Java container with `memory.max=1GiB` and `-Xmx1g` can still die because thread stacks, direct buffers, metaspace, and libc allocations need memory outside the Java heap. Leave headroom or use container-aware heap sizing.

Example: a Go service can show a stable application heap in pprof while RSS grows from mmap, Cgo, or retained spans. Compare pprof with `/proc/<pid>/smaps_rollup` before blaming the garbage collector.

## THP, NUMA, and Swap

Transparent Huge Pages can improve TLB efficiency for some workloads and hurt latency for others through compaction and allocation stalls. NUMA can make memory access slower when processes run far from their memory. Swap can preserve availability but create latency spikes when hot pages are swapped out.

Checks:

```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
numastat
numastat -p <pid>
swapon --show
cat /proc/swaps
```

Treat THP and swap policy as workload-specific. Databases often need explicit guidance from vendor docs and measured testing.

## Leak Triage

1. Confirm whether RSS is growing or only VSZ is large.
2. Compare process memory, cgroup memory, and node memory.
3. Split anonymous RSS from file-backed RSS.
4. Check whether page cache, slab, or dirty writeback dominates.
5. Review deployment changes, traffic changes, and batch jobs.
6. Capture heap profiles when the application runtime supports them.
7. If kernel memory grows, inspect slab caches and subsystem counters.

Useful commands:

```bash
pmap -x <pid> | tail -20
grep -E 'Rss|Pss|Private|Shared' /proc/<pid>/smaps_rollup
slabtop
```

## Runbook

1. Confirm whether the symptom is latency, allocation failure, swap storm, cgroup OOM, or node OOM.
2. Save `free -h`, `/proc/meminfo`, PSI, `vmstat`, top RSS processes, and kernel OOM logs.
3. Check cgroup memory files for affected services or containers.
4. Identify dominant memory: anonymous RSS, page cache, slab, dirty pages, or swap.
5. Apply the smallest mitigation: reduce concurrency, restart one leaking workload, raise a cgroup limit, disable a batch job, or shed traffic.
6. After recovery, add alerts for PSI, cgroup `oom_kill`, swap activity, and sustained RSS growth.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is low free memory not automatically a Linux problem?" answer="Linux uses otherwise idle memory for cache; MemAvailable and pressure signals are more useful." %}
  {% include study-card.html question="What is the difference between RSS and VSZ?" answer="RSS is resident physical memory; VSZ is virtual address space and can be large without real pressure." %}
  {% include study-card.html question="Why can a container be OOMKilled on a healthy node?" answer="The cgroup memory limit can be exhausted even when the host still has available memory." %}
  {% include study-card.html question="What does memory PSI show?" answer="How much time tasks are stalled because memory reclaim or allocation pressure blocks forward progress." %}
</div>

## References

- [Linux proc meminfo documentation](https://docs.kernel.org/filesystems/proc.html)
- [Linux cgroup v2 documentation](https://docs.kernel.org/admin-guide/cgroup-v2.html)
- [Linux PSI documentation](https://docs.kernel.org/accounting/psi.html)
- [proc_pid_oom_score_adj(5)](https://man7.org/linux/man-pages/man5/proc_pid_oom_score_adj.5.html)
