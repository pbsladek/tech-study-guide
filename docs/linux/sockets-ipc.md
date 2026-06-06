---
title: Linux Sockets and IPC
layout: page
permalink: /docs/linux/sockets-ipc/
summary: "Linux sockets, TCP, UDP, Unix domain sockets, socket files, listen queues, buffers, file descriptors, pipes, signals, shared memory, and IPC troubleshooting."
tags:
  - linux
  - sockets
  - ipc
  - troubleshooting
---

# Linux Sockets and IPC

Sockets and IPC are how processes communicate. A socket is also a file descriptor, so socket incidents often overlap with file descriptor limits, process ownership, namespaces, permissions, buffers, queues, and service managers.

## Command Examples

```bash
ss -tulpen
ss -xap
lsof -p <pid>
ls -l /proc/<pid>/fd
cat /proc/net/sockstat
sysctl net.core.somaxconn
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `ss -tulpen` | `Listening, established, TIME_WAIT, queues, PIDs, or socket summaries.` | Shows socket state and whether applications are listening or backpressured. |
| `ss -xap` | `Listening, established, TIME_WAIT, queues, PIDs, or socket summaries.` | Shows socket state and whether applications are listening or backpressured. |
| `lsof -p <pid>` | `FD, type, device, inode, and path or socket rows.` | Shows open files and sockets owned by a process. |

## Socket Families

| Family | Common use |
| --- | --- |
| `AF_INET` / `AF_INET6` | IPv4 and IPv6 network sockets. |
| `AF_UNIX` | Local Unix domain sockets, often represented by filesystem paths. |
| `AF_NETLINK` | Kernel/userspace communication for networking and system state. |

TCP sockets are streams with connection state. UDP sockets send datagrams. Unix domain sockets can be stream or datagram and are common for local daemons, sidecars, databases, container runtimes, and service managers.

## Unix Domain Sockets

Unix domain sockets often appear as filesystem entries such as `/run/docker.sock` or `/var/run/app.sock`. Filesystem permissions and directory execute permissions control who can connect when the socket is path-based.

Operational pitfalls:

- stale socket file after a daemon crash,
- wrong owner or group on the socket path,
- parent directory lacks execute permission,
- service starts before `/run` path exists,
- client is in a different mount namespace and cannot see the socket path,
- systemd socket activation owns the listening socket.

## Listen Queues and Buffers

Listening sockets have queues. If the accept loop stalls, clients can time out even though the process is still listening. Buffers absorb bursts, but they also hide backpressure until writes block, reads lag, or memory pressure grows.

Signals to inspect:

- `ss -ltn` receive/send queue columns,
- `net.core.somaxconn`,
- application backlog setting,
- file descriptor limits,
- cgroup memory and socket pressure,
- dropped packets or retransmits for network sockets.

## Pipes, FIFOs, and Shared Memory

Linux IPC also includes pipes, named pipes, shared memory, futexes, eventfd, signalfd, and message queues. Operators do not always need to design with them, but they need to recognize them in `/proc/<pid>/fd`, `lsof`, and strace output.

## Namespace Effects

Network namespaces have their own interfaces, routes, listening ports, and network socket tables. Mount namespaces affect path-based Unix sockets. PID namespaces affect which process owns a socket from inside a container.

## Troubleshooting Flow

1. Identify whether the IPC path is TCP, UDP, Unix socket, pipe, or another FD type.
2. Check the owning process and file descriptor with `ss`, `lsof`, and `/proc/<pid>/fd`.
3. For Unix sockets, check socket path owner, group, mode, and parent directory permissions.
4. Check namespace differences between client and server.
5. Check listen queues, backlog, and file descriptor limits.
6. Check systemd socket activation if systemd owns the listener.
7. Use packet capture or strace only after basic ownership and namespace checks.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why can a Unix socket fail even when the daemon is running?" answer="The socket path, parent directory permissions, namespace view, stale file, or systemd socket activation may be wrong." %}
  {% include study-card.html question="What does ss -x show?" answer="Unix domain socket state and, when available, owning processes and paths." %}
  {% include study-card.html question="Why are sockets also file descriptor incidents?" answer="Sockets consume file descriptors and appear under /proc/PID/fd, so limits and inherited FDs can break communication." %}
</div>

## References

- [socket(7)](https://man7.org/linux/man-pages/man7/socket.7.html)
- [unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html)
- [tcp(7)](https://man7.org/linux/man-pages/man7/tcp.7.html)
- [udp(7)](https://man7.org/linux/man-pages/man7/udp.7.html)
- [ss(8)](https://man7.org/linux/man-pages/man8/ss.8.html)
