---
title: Linux System Call Debugging
layout: page
permalink: /docs/linux/syscall-debugging/
summary: "Linux syscall debugging with strace, errno, blocking calls, file and socket syscalls, poll, epoll, futexes, and production triage boundaries."
tags:
  - linux
  - syscalls
  - debugging
  - troubleshooting
---

# Linux System Call Debugging

System calls are where application intent crosses into the kernel. When logs say "permission denied," "connection refused," "timeout," or "file not found," the syscall layer can prove what path, socket, credentials, flags, and error code were involved.

Use syscall debugging when application logs are vague, code-level tracing is unavailable, or you need to distinguish application behavior from kernel or environment behavior.

## First Checks

```bash
strace -f -p <pid>
strace -ff -o /tmp/trace.log <command>
strace -f -e trace=file,network -p <pid>
strace -ttT -f -p <pid>
strace -yy -s 256 -f -e trace=network,desc -p <pid>
strace -c -f <command>
strace -f -e status=failed <command>
cat /proc/<pid>/syscall
```

`strace` uses `ptrace`, so it can perturb timing and may be blocked by permissions, seccomp, containers, or `kernel.yama.ptrace_scope`.

## What strace Proves

`strace` proves what a traced process asked the kernel to do and what the kernel returned. It does not prove what the application intended, what remote systems saw, or why userspace chose a call. Use it to answer precise boundary questions:

| Question | Useful strace Evidence | Confirm With |
| --- | --- | --- |
| Which path is the process opening? | `openat`, `statx`, `access`, returned `errno`. | `ls -ld`, `namei -l`, `getfacl`, mount options. |
| Which address is it connecting to? | `connect` sockaddr, `sendto`, `recvfrom`, `getsockopt(SO_ERROR)`. | `ss`, `ip route get`, packet capture, DNS query evidence. |
| Is it blocked in userspace or kernel wait? | `epoll_wait`, `futex`, `read`, `recvfrom`, `fsync`, syscall duration with `-T`. | thread dumps, `perf`, `/proc/<pid>/stack`, storage/network metrics. |
| Is a limit being hit? | `EMFILE`, `ENFILE`, `ENOMEM`, `EAGAIN`, short writes. | `ulimit -n`, `/proc/<pid>/limits`, cgroup events, host pressure. |
| Did a child process exec the command? | `clone`, `execve`, `wait4`, exit status. | service logs, `systemctl status`, audit logs. |

Do not treat a missing syscall as proof that nothing happened. The event may be in another process, thread, namespace, library cache, kernel path, or already completed before the attach.

## Reading strace Output

A line has timestamp, process ID when requested, syscall name, arguments, return value, errno, and optional duration:

```text
12:00:03.451234 connect(7<TCP:[10.0.0.5:45122->198.51.100.10:443]>, {sa_family=AF_INET, sin_port=htons(443), sin_addr=inet_addr("198.51.100.10")}, 16) = -1 EINPROGRESS (Operation now in progress) <0.000041>
12:00:03.452119 getsockopt(7<TCP:[10.0.0.5:45122->198.51.100.10:443]>, SOL_SOCKET, SO_ERROR, [0], [4]) = 0 <0.000012>
```

Key flags for readable evidence:

| Flag | Why Use It |
| --- | --- |
| `-f` | Follow child processes and threads created after attach or start. |
| `-ff -o /tmp/trace.log` | Write one trace file per PID so multiprocess output stays readable. |
| `-ttT` | Show absolute timestamps and per-syscall duration. |
| `-s 256` | Avoid truncating useful strings such as paths, DNS names, and SQL snippets. |
| `-yy` | Decode file descriptors with socket, pipe, and path details when available. |
| `-e trace=...` | Restrict tracing to syscall groups or names. |
| `-e status=failed` | Show only failing syscalls when the process is noisy. |
| `-c` | Summarize syscall counts, errors, and time instead of printing every call. |
| `-p <pid>` | Attach to an already-running process. |
| `-P <path>` | Trace calls touching a specific path, useful for config and certificate mysteries. |

Start broad only long enough to learn the shape, then narrow the trace.

### Annotated strace Output Gallery

| Trace Line | Interpretation | Next Check |
| --- | --- | --- |
| `openat(AT_FDCWD, "/etc/myapp/config.yaml", O_RDONLY) = -1 ENOENT` | The exact path is missing from this process namespace. | Check working directory, mount namespace, packaging, and `-P /etc/myapp/config.yaml`. |
| `openat(..., "/var/lib/myapp/db", O_RDWR) = -1 EACCES` | Path exists but mode bits, ACLs, directory execute bits, or LSM policy denies access. | `namei -l`, `getfacl`, audit logs, AppArmor/SELinux status. |
| `connect(7, {AF_INET 10.0.0.10:5432}, 16) = -1 EINPROGRESS` | Nonblocking connect started; not a failure by itself. | Look for later `poll`/`epoll_wait` and `getsockopt(SO_ERROR)`. |
| `getsockopt(7, SOL_SOCKET, SO_ERROR, [111], [4]) = 0` | The asynchronous connect failed; `111` is `ECONNREFUSED`. | Check listener, firewall reject, Service endpoints, or proxy target. |
| `accept4(3, ..., SOCK_CLOEXEC) = -1 EAGAIN` | Nonblocking accept found no completed connection at that moment. | Normal in event loops unless paired with dropped connections/backlog pressure. |
| `futex(0x..., FUTEX_WAIT_PRIVATE, ...) <5.000000>` | Thread is waiting on userspace synchronization. | Check thread dumps, locks, scheduler delay, or off-CPU profiling. |
| `read(5, ..., 8192) = 0` | EOF from file, pipe, or socket. | For sockets, peer closed; inspect protocol and peer logs. |
| `write(2, "error", 5) = -1 EPIPE` | Pipe or socket peer closed while writing. | Check peer lifecycle and SIGPIPE handling. |

## Errno Is Evidence

Linux syscalls usually return `-1` and set `errno` when they fail. The exact error matters.

| Error | Common Meaning |
| --- | --- |
| `ENOENT` | Path component or file does not exist. |
| `EACCES` | Permission denied by mode bits, ACLs, directory execute bit, or policy. |
| `EPERM` | Operation not permitted, often capability, LSM, immutable flag, or namespace policy. |
| `ECONNREFUSED` | Remote host actively refused a TCP connection. |
| `ETIMEDOUT` | Timed out waiting for network progress. |
| `EADDRINUSE` | Local address or port already in use. |
| `EMFILE` | Process file descriptor limit reached. |
| `ENFILE` | System-wide file table pressure. |
| `ENOMEM` | Allocation failed or limit was hit. |

Do not collapse these into "the app failed." Each points at a different layer.

## File and Process Syscalls

Common file path:

```text
openat -> read/write -> fsync/fdatasync -> close
```

Common process path:

```text
clone/fork -> execve -> wait4
```

Useful filters:

```bash
strace -f -e trace=openat,stat,access,read,write,fsync,close -p <pid>
strace -f -e trace=process -p <pid>
strace -f -e fault=openat:error=ENOENT:when=1 <command>
strace -f -P /etc/myapp/config.yaml -e trace=file <command>
```

Fault injection is useful in labs, not production.

File failures are often directory failures. `openat("/srv/app/config.yaml", ...) = -1 EACCES` may mean the file mode is wrong, but it can also mean one parent directory lacks execute permission, the mount is read-only, an LSM denied access, or the process is in a different mount namespace. Confirm the namespace and path:

```bash
readlink /proc/<pid>/root
readlink /proc/<pid>/cwd
namei -l /srv/app/config.yaml
grep ' /srv ' /proc/<pid>/mountinfo
```

## Socket Syscalls

TCP client setup often looks like:

```text
socket -> connect -> getsockopt -> sendto/write -> recvfrom/read -> close
```

Server setup often looks like:

```text
socket -> setsockopt -> bind -> listen -> accept4 -> read/write
```

Useful filters:

```bash
strace -f -e trace=network -p <pid>
strace -f -e trace=connect,accept4,sendto,recvfrom,getsockopt -p <pid>
strace -ttT -yy -s 256 -f -e trace=network,poll,epoll_wait -p <pid>
ss -tulpen
```

`connect()` returning `EINPROGRESS` can be normal for nonblocking sockets. The final result may appear later through `poll`, `epoll_wait`, or `getsockopt(SO_ERROR)`.

Network interpretation:

| strace Pattern | Likely Meaning | Next Check |
| --- | --- | --- |
| `connect(...) = -1 ECONNREFUSED` | Remote stack or local firewall actively rejected the connection. | `ss -ltnp` on server, packet capture for RST, firewall reject rules. |
| `connect(...) = -1 ETIMEDOUT` | SYNs did not complete or a middlebox silently dropped traffic. | `ip route get`, `tcpdump`, firewall drops, security groups. |
| `connect(...) = -1 ENETUNREACH` / `EHOSTUNREACH` | No route or neighbor/path failure. | route table, policy routing, ARP/NDP, VPN or CNI route state. |
| `sendto(...) = -1 EPIPE` plus `SIGPIPE` | The peer closed or reset before the write. | proxy/backend logs, TCP resets, app write-after-close behavior. |
| `recvfrom(...) = -1 EAGAIN` | Nonblocking socket had no data ready. | event-loop readiness, timeout settings, socket queues. |
| `getsockopt(... SO_ERROR ...) = [111]` | Nonblocking connect completed with stored error. | treat the SO_ERROR value as the connection result. |

## DNS Through strace

`strace` is useful when a program says "DNS failed" but you need to know whether it asked libc, read `/etc/hosts`, queried a resolver, or used a runtime cache. Trace both file and network calls:

```bash
strace -ttT -f -s 256 -e trace=file,network getent hosts api.example.com
strace -ttT -f -s 256 -e trace=openat,connect,sendto,recvfrom,poll getent ahosts api.example.com
strace -ttT -f -s 256 -e trace=file,network curl -v https://api.example.com/health
```

Look for:

| Evidence | Interpretation |
| --- | --- |
| reads `/etc/nsswitch.conf` then `/etc/hosts` | libc/NSS may answer before DNS. |
| opens `/etc/resolv.conf` | process is using resolver config visible in its mount namespace. |
| `connect` or `sendto` to `127.0.0.53:53` | systemd-resolved local stub path. |
| `sendto` to CoreDNS or NodeLocal DNSCache IP | Kubernetes Pod resolver path. |
| no DNS socket calls before connect | application/runtime cache, existing connection pool, literal IP, or another process resolved earlier. |

Pair this with DNS tools: `getent` proves the libc view, `nslookup` and `dig` prove direct DNS query behavior, and packet captures prove whether queries left the host or Pod.

## Process Trees and Services

Services often fork, exec helpers, reload config in a child, or run under a supervisor. Use `-f` and `-ff` when startup behavior matters:

```bash
strace -ff -ttT -s 256 -o /tmp/myapp.trace systemctl start myapp.service
strace -ff -ttT -s 256 -e trace=process,file -o /tmp/myapp.exec /usr/bin/myapp --check-config
ls -1 /tmp/myapp.trace.*
```

For a systemd service, tracing `systemctl` usually traces the client, not the service workload after systemd starts it. Prefer a foreground check command when available, or attach to the service process after startup:

```bash
systemctl show myapp.service -p MainPID
strace -ttT -f -p "$(systemctl show myapp.service -p MainPID --value)"
```

## Blocking Calls

When a process looks hung, find what it is blocked on:

```bash
cat /proc/<pid>/syscall
cat /proc/<pid>/stack
strace -ttT -p <pid>
```

Common blockers:

| Syscall | Interpretation |
| --- | --- |
| `epoll_wait` | Event loop waiting for file descriptor readiness. |
| `futex` | Thread synchronization, locks, condition variables. |
| `read` / `recvfrom` | Waiting for file, pipe, socket, or terminal input. |
| `connect` | Waiting on network connection progress. |
| `fsync` | Waiting for durable storage completion. |
| `wait4` | Parent waiting for child exit. |

High time in `futex` is often application lock contention, not a kernel bug.

## Common Troubleshooting Recipes

| Symptom | Command | What To Read |
| --- | --- | --- |
| Program exits immediately | `strace -ff -ttT -s 256 -e trace=process,file <command>` | Last failed file lookup, missing dynamic dependency, failed `execve`, bad cwd. |
| Permission denied | `strace -f -e trace=file -s 256 <command>` | Path, `EACCES` vs `EPERM`, parent directories, namespace root. |
| Cannot connect | `strace -ttT -yy -f -e trace=network,poll <command>` | Destination sockaddr, `ECONNREFUSED`, timeout, `SO_ERROR`. |
| Hangs | `strace -ttT -p <pid>` | Syscall with long duration: `futex`, `epoll_wait`, `read`, `connect`, `fsync`. |
| File descriptor leak | `strace -f -e trace=%desc -p <pid>` | Repeated `openat`, `socket`, `pipe2` without matching close. |
| Too many open files | `strace -f -e status=failed -p <pid>` | `EMFILE` at process limit or `ENFILE` at host limit. |
| Config path mystery | `strace -f -P /etc/myapp/config.yaml -e trace=file <command>` | Whether that exact path is touched. |
| Container behaves differently | `nsenter -t <pid> -m -n strace -f -p <pid>` | Process view from the same mount and network namespace. |

Use `timeout` around exploratory traces when attaching during incidents:

```bash
timeout 20s strace -ttT -yy -s 256 -f -e trace=network,poll,epoll_wait -p <pid>
```

## Containers and Permissions

Attaching to a process may fail even as root inside a container. Common causes are missing `CAP_SYS_PTRACE`, seccomp blocking `ptrace`, Yama `ptrace_scope`, PID namespace mismatch, or tracing from the wrong host. Check the boundary before assuming the process is special:

```bash
cat /proc/sys/kernel/yama/ptrace_scope
grep -E 'CapEff|Seccomp|NoNewPrivs' /proc/<pid>/status
readlink /proc/<pid>/ns/pid
readlink /proc/self/ns/pid
```

In Kubernetes, use an ephemeral debug container or node-level debug workflow only when policy permits it. Tracing production workloads can expose secrets in syscall arguments, environment reads, headers, SQL, and file paths.

## Production Boundaries

- Use filters before tracing high-throughput processes.
- Prefer `-c` summaries for broad syscall counts.
- Use `-ttT` when latency per syscall matters.
- Use `-yy` and `-s` when file descriptors or strings are the evidence.
- Avoid attaching to latency-critical processes for long periods.
- Capture exact timestamps and command lines.
- Treat trace files as sensitive incident artifacts.
- Consider eBPF tracing when ptrace overhead or process attachment is too risky.

## Runbook

1. Identify the process, namespace, user, and container boundary.
2. Reproduce with a narrow command if possible.
3. Trace only relevant syscall classes: file, network, process, signal, or descriptor.
4. Map `errno` to permissions, path, network, resource limit, or policy.
5. If blocked, inspect `/proc/<pid>/syscall`, `strace -ttT`, and thread state.
6. Confirm the finding with a non-`strace` command such as `ss`, `ls -l`, `getfacl`, or `journalctl`.
7. If the issue involves DNS, compare `strace` evidence with `getent`, `nslookup`, `dig`, and packet capture.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is errno important in syscall debugging?" answer="It gives the kernel's specific failure reason, such as ENOENT, EACCES, ECONNREFUSED, or EMFILE." %}
  {% include study-card.html question="Why can EINPROGRESS be normal for connect?" answer="Nonblocking sockets report connection progress asynchronously through readiness APIs and SO_ERROR." %}
  {% include study-card.html question="What does epoll_wait usually indicate?" answer="An event loop is waiting for file descriptor readiness." %}
  {% include study-card.html question="Why can strace change production behavior?" answer="ptrace adds overhead and synchronization that can perturb timing-sensitive workloads." %}
  {% include study-card.html question="Why use strace -yy?" answer="It decodes file descriptors with path, socket, pipe, and peer details when the kernel exposes them." %}
  {% include study-card.html question="What does getsockopt(SO_ERROR) show after a nonblocking connect?" answer="The stored completion result of the connection attempt." %}
  {% include study-card.html question="Why trace file and network syscalls for DNS?" answer="DNS may involve NSS files, resolv.conf, local stubs, UDP/TCP 53, or no query at all if a cache answered." %}
</div>

## References

- [strace documentation](https://strace.io/)
- [syscalls(2)](https://man7.org/linux/man-pages/man2/syscalls.2.html)
- [errno(3)](https://man7.org/linux/man-pages/man3/errno.3.html)
- [epoll(7)](https://man7.org/linux/man-pages/man7/epoll.7.html)
