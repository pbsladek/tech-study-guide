---
title: Linux Processes and Threads
layout: page
permalink: /docs/linux/processes-threads/
summary: "Linux processes, threads, tasks, PIDs, TIDs, fork, exec, wait, zombies, signals, scheduling, cgroups, namespaces, and process troubleshooting."
tags:
  - linux
  - processes
  - threads
  - troubleshooting
---

# Linux Processes and Threads

Linux represents execution as tasks. What users call a process is usually a thread group with a process ID, address space, file descriptor table, credentials, signal state, namespaces, and cgroup membership. Threads are tasks that share many of those resources.

## Command Examples

```bash
ps -eLf
pstree -ap
top -H -p <pid>
cat /proc/<pid>/status
ls /proc/<pid>/task
cat /proc/<pid>/limits
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `ps -eLf` | `PID, PPID, thread count, CPU, memory, and command rows.` | Shows process ownership, ancestry, and hot threads. |
| `pstree -ap` | `PID, PPID, thread count, CPU, memory, and command rows.` | Shows process ownership, ancestry, and hot threads. |
| `top -H -p <pid>` | `PID, PPID, thread count, CPU, memory, and command rows.` | Shows process ownership, ancestry, and hot threads. |

## Process, Thread, PID, and TID

Important distinctions:

| Term | Meaning |
| --- | --- |
| PID | Process ID shown by many user tools, often the thread group ID. |
| TID | Thread ID for an individual task. |
| Thread group | Set of threads that usually share address space and appear as one process. |
| Parent PID | Process that receives child exit status unless reparenting occurs. |
| PID namespace | Namespace that changes which PIDs are visible to a process. |

`/proc/<pid>/task/` lists threads in a process. `ps -eLf` and `top -H` show thread-level views.

## fork, exec, and wait

`fork()` creates a child process. Linux uses copy-on-write memory, so the child initially shares pages until one side writes. `execve()` replaces the current program image. `wait()` collects child exit status.

Failures in this lifecycle create common incidents:

- zombie children when parents do not wait,
- fork failures from PID limits or memory pressure,
- inherited file descriptors after exec,
- process trees that keep old deployments alive,
- PID namespace confusion in containers.

## Zombies, Orphans, and Reparenting

A zombie has exited but still has an entry so the parent can collect status. Zombies do not use CPU, but they consume PID table entries. If the parent exits, children are reparented to a subreaper or PID 1.

In containers, PID 1 has special responsibilities. If it does not reap children or handle signals correctly, shutdown and zombie behavior can be surprising.

## Signals and Shutdown

Signals are process notifications. `SIGTERM` asks a process to terminate. `SIGKILL` forces termination and cannot be caught. `SIGHUP` often means reload, but that is application convention.

Operational points:

- graceful shutdown depends on signal handling,
- process groups matter for shells and supervisors,
- systemd service `KillMode=` changes which processes receive signals,
- containers need a sane PID 1 or init wrapper when child reaping matters.

## Scheduling and Thread Debugging

High CPU or latency often hides in one thread. Use `top -H`, `pidstat -t`, and `/proc/<pid>/task/<tid>/status` to separate process-wide state from thread state. Thread count also matters for stack memory, scheduler overhead, cgroup PID limits, and application pools.

## Troubleshooting Flow

1. Identify process tree and parent with `pstree`.
2. Check process and thread counts with `ps -eLf`.
3. Inspect `/proc/<pid>/status`, limits, cgroup, namespaces, and file descriptors.
4. Use `top -H` or `pidstat -t` for hot threads.
5. Check zombies and parent reaping behavior.
6. Check signals, service manager policy, and shutdown logs.
7. Check cgroup PID, CPU, and memory limits before blaming application code.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Where can you list a process's threads?" answer="/proc/PID/task lists task IDs for the threads in that process." %}
  {% include study-card.html question="Why do zombies exist?" answer="The child has exited, but the parent has not collected its exit status with wait." %}
  {% include study-card.html question="Why is PID 1 special in containers?" answer="It receives orphaned children and must handle signals and reaping well for clean shutdown." %}
</div>

## References

- [proc(5)](https://man7.org/linux/man-pages/man5/proc.5.html)
- [pthreads(7)](https://man7.org/linux/man-pages/man7/pthreads.7.html)
- [clone(2)](https://man7.org/linux/man-pages/man2/clone.2.html)
- [fork(2)](https://man7.org/linux/man-pages/man2/fork.2.html)
- [wait(2)](https://man7.org/linux/man-pages/man2/wait.2.html)
- [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)
