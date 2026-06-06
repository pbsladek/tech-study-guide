---
title: Linux eBPF and Tracing
layout: page
permalink: /docs/linux/ebpf-tracing/
summary: "Practical Linux eBPF tracing with tracepoints, kprobes, uprobes, bpftrace, BCC, tc, XDP, and production-safe observability boundaries."
tags:
  - linux
  - ebpf
  - tracing
  - observability
  - troubleshooting
---

# Linux eBPF and Tracing

eBPF lets Linux run verified programs inside kernel-controlled hooks. For operators, it is most useful as a targeted observability tool: trace syscalls, block I/O, TCP events, scheduler latency, file opens, DNS lookups, or application functions without rebuilding the kernel or the application.

Use eBPF when normal counters show where to look but not why the behavior is happening. Use logs, metrics, `strace`, `perf`, and packet capture first when they already answer the question with less risk.

## Command Examples

```bash
uname -r
bpftool feature probe
bpftool prog show
bpftool map show
bpftrace -l 'tracepoint:syscalls:sys_enter_*' | head
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `uname -r` | `Linux host 6.8.0-xx-generic x86_64.` | Shows kernel version and architecture for driver, eBPF, and tuning checks. |
| `bpftool feature probe` | `Supported eBPF features, loaded programs, maps, and attach points.` | Shows whether tracing or datapath eBPF is available and active. |
| `bpftool prog show` | `Supported eBPF features, loaded programs, maps, and attach points.` | Shows whether tracing or datapath eBPF is available and active. |

Confirm kernel support, available helpers, loaded programs, and traceable events before writing a probe. Production systems may restrict BPF through capabilities, lockdown mode, LSM policy, containers, or managed-node policy.

## Mental Model

An eBPF program is loaded by user space, verified by the kernel, attached to a hook, and executed when that hook fires.

| Piece | Role |
| --- | --- |
| Loader | User-space tool such as `bpftrace`, BCC, Cilium, or `bpftool` that loads and attaches programs. |
| Verifier | Kernel safety gate that rejects unsafe programs, unbounded loops, bad memory access, and unsupported helper use. |
| Program | The eBPF bytecode that runs at a specific hook. |
| Map | Kernel-resident key/value storage used to aggregate state or communicate with user space. |
| Hook | The event source: tracepoint, kprobe, uprobe, socket hook, `tc`, XDP, cgroup hook, or LSM hook. |

This model matters because most failures are attach failures, verifier failures, missing privileges, wrong hook names, or probes that add too much overhead.

## Hook Types

| Hook | Best Use | Caution |
| --- | --- | --- |
| Tracepoint | Stable kernel event tracing, such as syscalls, scheduler, block, and TCP events. | Lower detail than arbitrary probes, but safer across kernel versions. |
| kprobe / kretprobe | Dynamic tracing of kernel functions and returns. | Function names and arguments can change across kernels. |
| uprobe / uretprobe | Dynamic tracing of user-space functions and returns. | Needs matching binaries, symbols, and sometimes debuginfo. |
| perf event | Sampling CPU or hardware events. | Sampling answers "where time went," not every event. |
| `tc` BPF | Packet processing at Linux traffic-control ingress/egress. | Runs in the packet path; mistakes affect traffic. |
| XDP | Very early packet processing in the NIC driver receive path. | Powerful but sharp; bypasses much of the normal stack. |
| Cgroup hooks | Per-cgroup socket, connect, bind, or device policy and tracing. | Great for containers, but must match cgroup layout. |

Prefer tracepoints for durable study examples. Reach for kprobes only when no tracepoint exposes the state you need.

## bpftrace Examples

Symptom-driven one-liners:

| Symptom | bpftrace Probe | What It Shows |
| --- | --- | --- |
| Process exits or execs unexpectedly | `sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("%s pid=%d %s\n", comm, pid, str(args->filename)); }'` | Commands being executed system-wide. |
| Permission errors | `sudo bpftrace -e 'tracepoint:syscalls:sys_exit_openat /args->ret < 0/ { @[comm, args->ret] = count(); }'` | Which processes get failing `openat` returns. |
| TCP retransmits | `sudo bpftrace -e 'tracepoint:tcp:tcp_retransmit_skb { @[comm] = count(); }'` | Processes associated with retransmit events. |
| Slow block I/O | `sudo bpftrace -e 'tracepoint:block:block_rq_complete { @usec = hist(args->nr_sector); }'` | Completion distribution starter; use richer scripts for latency. |
| Run queue latency | `sudo runqlat` | Scheduler delay before threads run. |
| Off-CPU time | `sudo offcputime -p <pid>` | Where a process waits off CPU. |

Treat one-liners as triage, not final proof. Validate field names against your kernel with `bpftrace -lv <probe>` because tracepoint arguments can vary by kernel version.

Show process exec events:

```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("%s pid=%d exec=%s\n", comm, pid, str(args->filename)); }'
```

Count file opens by process name:

```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat { @[comm] = count(); }'
```

Trace TCP retransmits:

```bash
sudo bpftrace -e 'tracepoint:tcp:tcp_retransmit_skb { @[comm] = count(); }'
```

Watch block I/O latency distribution:

```bash
sudo bpftrace -e '
tracepoint:block:block_rq_issue { @start[args->sector] = nsecs; }
tracepoint:block:block_rq_complete /@start[args->sector]/ {
  @usec = hist((nsecs - @start[args->sector]) / 1000);
  delete(@start[args->sector]);
}'
```

## BCC Tools

BCC packages common scripts for fast incident work:

```bash
sudo execsnoop
sudo opensnoop
sudo tcpretrans
sudo biolatency
sudo runqlat
sudo offcputime -p <pid>
```

Use these before writing custom probes. They encode common attach points, map usage, and output formatting.

## Choosing the Right Tool

| Question | Good First Tool |
| --- | --- |
| Which process opened this file? | `opensnoop`, `bpftrace` syscall tracepoint. |
| Why is CPU time high? | `perf top`, `profile`, `offcputime`. |
| Are TCP retransmits happening? | `sar -n TCP,ETCP`, `tcpretrans`, packet capture. |
| Which syscalls are failing? | `strace`, then `bpftrace` when process-wide tracing is too narrow. |
| Is disk latency high? | `iostat`, then `biolatency` or block tracepoints. |
| Is run-queue latency high? | `pidstat`, `runqlat`, PSI. |

eBPF is not a replacement for metrics. It is a way to answer precise questions once metrics point to a layer.

## Safety Boundaries

- Avoid tracing every event on hot paths without filters.
- Prefer counts and histograms over printing every event.
- Test probes on staging or a low-traffic node first.
- Record kernel version, tool version, and exact command.
- Keep probe duration short during incidents.
- Remove loaded programs and pinned maps when finished.

Printing per packet, per syscall, or per scheduler event can create the incident you are trying to debug.

## Runbook

1. State the question in one sentence: process, syscall, packet event, I/O path, or scheduler behavior.
2. Check whether ordinary metrics, logs, `strace`, `perf`, or packet capture already answer it.
3. Pick the most stable hook, usually a tracepoint.
4. Add filters by PID, cgroup, process name, port, or device.
5. Aggregate with counts, histograms, or top-N keys before printing raw events.
6. Run for a bounded window and save the command plus output.
7. Remove probes and verify no unexpected BPF programs or maps remain.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why does the eBPF verifier exist?" answer="It rejects unsafe programs before they run in kernel-controlled contexts." %}
  {% include study-card.html question="Why are tracepoints usually safer than kprobes?" answer="Tracepoints are explicit kernel events with more stable interfaces than arbitrary kernel function probes." %}
  {% include study-card.html question="Why should production probes aggregate instead of printing every event?" answer="High-volume printing can add overhead, drop events, and distort the workload being measured." %}
  {% include study-card.html question="When is eBPF better than strace?" answer="When you need low-overhead, system-wide, filtered, or kernel-path visibility that ptrace-based syscall tracing cannot provide safely." %}
</div>

## References

- [Linux kernel BPF documentation](https://docs.kernel.org/bpf/)
- [bpftrace reference guide](https://bpftrace.org/docs/release_023/language)
- [BCC reference guide](https://github.com/iovisor/bcc/blob/master/docs/reference_guide.md)
- [bpftool documentation](https://man7.org/linux/man-pages/man8/bpftool.8.html)
