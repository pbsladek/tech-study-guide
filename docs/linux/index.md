---
title: Linux
layout: page
permalink: /docs/linux/
summary: "Linux fundamentals for developers and operators: processes, fork/exec, memory, CPU, kernel params, caches, paging, GPUs, and troubleshooting."
tags:
  - linux
  - operating-systems
  - troubleshooting
  - gpu
---

# Linux OS and Fundamentals

Linux is the layer that turns hardware into process isolation, files, sockets, memory mappings, timers, signals, device drivers, and resource accounting. Developers need it because code eventually becomes processes, syscalls, pages, sockets, and file descriptors. Operators need it because incidents show up as CPU pressure, memory pressure, IO waits, scheduler latency, kernel logs, device-driver behavior, access failures, broken scheduled jobs, SSH lockouts, and host identity drift.

## Mental Model

A Linux system is a set of cooperating boundaries:

| Boundary | What It Controls | What Breaks |
| --- | --- | --- |
| Process | Execution context, PID, open files, signal handling, credentials. | Stuck workers, zombies, runaway children, bad signal handling. |
| Virtual memory | Per-process address space mapped to RAM, files, anonymous pages, and swap. | OOM kills, paging storms, leaks, fragmentation. |
| Scheduler | Which runnable tasks get CPU time. | High load, latency spikes, CPU starvation. |
| VFS | Common file abstraction over filesystems, devices, sockets, procfs, sysfs. | File descriptor leaks, mount issues, inode pressure. |
| Network stack | Interfaces, routes, sockets, queues, conntrack, firewall hooks. | Drops, retransmits, queue buildup. |
| Device drivers | Kernel code that talks to hardware. | GPU resets, NIC errors, storage timeouts. |
| Cgroups and namespaces | Resource limits and isolation for containers and services. | Container OOM, throttling, misleading host-vs-container metrics. |

The kernel is not only "the thing under user space." It is the shared arbiter for memory, CPU, IO, devices, and security boundaries.

## Critical Subtopics

| Topic | Why It Matters |
| --- | --- |
| [Boot and Userspace](boot-userspace/) | Explains how firmware, bootloader, kernel, initramfs, root mounts, and PID 1 turn hardware into services. |
| [Network Boot and Automated Provisioning](network-boot-automated-provisioning/) | Covers PXE, UEFI HTTP Boot, iPXE, DHCP, TFTP, Ubuntu autoinstall, cloud-init NoCloud, Kickstart, inventory-driven provisioning, and reinstall-loop prevention. |
| [Kernel Modules and Devices](kernel-modules-devices/) | Covers loadable and built-in modules, `modprobe`, module aliases and parameters, sysfs, devtmpfs, udev, device nodes, initramfs, Secure Boot, and DKMS. |
| [Filesystems and IO](filesystems-io/) | Connects application file operations to VFS, page cache, mounts, inodes, block devices, and durable writes. |
| [Block Devices and Partitioning](block-devices-partitions/) | Covers `/dev` block devices, NVMe/SCSI naming, GPT, UUIDs, labels, udev, stable paths, and safe disk identity. |
| [Mounts and fstab](mounts-fstab/) | Covers persistent mounts, `findmnt`, `/etc/fstab`, systemd mount units, automounts, bind mounts, and mount options. |
| [Mount Namespaces and Propagation](mount-namespaces-propagation/) | Covers per-process mount views, bind mounts, shared subtree propagation, chroot, pivot_root, overlay, tmpfs, and container mount debugging. |
| [ext4, XFS, and Repair](ext4-xfs-repair/) | Covers ext4/XFS differences, inodes, quotas, journals, online growth, repair tools, TRIM, and safe repair workflows. |
| [Storage Drives, RAID, and Database Performance](storage-drives-raid-database-performance/) | Covers SSD, HDD, NVMe, RAID 0/1/5/6/10, striping, mirroring, parity, disk-failure recovery, rebuild risk, and PostgreSQL and Elasticsearch storage tradeoffs. |
| [RAID, Multipath, and Device Mapper](raid-multipath-device-mapper/) | Covers md RAID, dm-crypt/LUKS, device mapper, multipath, NVMe multipath, WWIDs, and layered storage troubleshooting. |
| [Storage Health and Performance](storage-health-performance/) | Covers `iostat`, SMART, NVMe health, kernel I/O errors, discard, queueing, latency, saturation, and failure response. |
| [Containerization, OCI, and VMs](containerization-oci-vms/) | Explains containers versus VMs, OCI standards, image layers, overlayfs, namespaces, cgroups, bridge networking, macOS/Windows behavior, KVM, and hypervisors. |
| [Network Stack](network-stack/) | Shows how sockets, routes, namespaces, Linux bridges, netfilter, conntrack, queues, and NICs move packets. |
| [Kernel Network Performance](kernel-network-performance/) | Covers NAPI, softirq, NIC rings, RSS, RPS, RFS, XPS, offloads, qdisc, drops, and packet-processing bottlenecks. |
| [TCP Kernel Tuning](tcp-kernel-tuning/) | Covers listen queues, `somaxconn`, SYN backlog, socket buffers, ephemeral ports, TIME_WAIT, keepalives, and conntrack limits. |
| [Sockets and IPC](sockets-ipc/) | Covers TCP, UDP, Unix domain sockets, socket files, listen queues, buffers, file descriptors, pipes, shared memory, and IPC troubleshooting. |
| [Processes and Threads](processes-threads/) | Covers tasks, PIDs, TIDs, thread groups, fork/exec/wait, zombies, signals, PID namespaces, scheduling, and thread debugging. |
| [Debian and Ubuntu Operations](debian-ubuntu/) | Uses Ubuntu Server as the default distro lens for packages, services, Netplan, UFW, logs, and certificates. |
| [Users, Permissions, and sudo](users-permissions-sudo/) | Covers UIDs, GIDs, `/etc/passwd`, `/etc/shadow`, mode bits, ACLs, service users, and sudo policy. |
| [SSH Access](ssh-access/) | Covers OpenSSH server policy, keys, host keys, PAM, account state, firewalls, and login troubleshooting. |
| [Logs and Observability](logs-observability/) | Covers journald, kernel logs, `/var/log`, log rotation, metrics, PSI, and incident evidence collection. |
| [Scheduled Automation](scheduled-automation/) | Covers cronjobs, crontab formats, anacron, systemd timers, job safety, idempotency, environment pitfalls, locking, and logs. |
| [Backup and File Transfer](backup-transfer-rsync-scp-snapshots/) | Covers `rsync`, `scp`, snapshot backups, consistency, restore testing, exclusions, permissions, and automation. |
| [Time, Hostname, and Identity](time-hostname/) | Covers time sync, timezone, hostname, DNS identity, machine-id, certificates, and incident timelines. |
| [Linux GPU Drivers](gpu-drivers/) | Covers AMD and NVIDIA GPU stacks, kernel modules, firmware, Mesa, ROCm, CUDA, `nvidia-smi`, Secure Boot, containers, and troubleshooting. |
| [LVM](lvm/) | Covers the storage mapping layer behind many Linux volumes. |
| [systemd](systemd/) | Covers service lifecycle, dependencies, logs, cgroups, timers, and resource controls. |
| [systemd Networking](systemd-networking/) | Covers systemd-networkd, systemd-resolved, `.network`, `.netdev`, `.link`, network targets, and wait-online behavior. |
| [systemd Socket Activation](systemd-socket-network-services/) | Covers `.socket` units, `ListenStream`, `ListenDatagram`, `Accept=yes`, service activation, and network service controls. |
| [resolv.conf](resolv-conf/) | Covers local DNS resolver behavior, search paths, and systemd-resolved interactions. |

Unless a page is explicitly distro-neutral, examples prefer Debian-family Linux with Ubuntu Server as the default operational target. That means `apt`, `dpkg`, `systemctl`, `journalctl`, Netplan, UFW, `/etc/ssl/certs`, `update-ca-certificates`, OpenSSH, `sudo`, `timedatectl`, and systemd timers are the expected baseline tools.

## Processes, Forking, Exec, and Wait

A Linux process is an execution context with a PID, virtual address space, file descriptor table, credentials, signal dispositions, and scheduling state.

Common lifecycle:

1. A process calls `fork()` or `clone()` to create a child.
2. The child often calls `execve()` to replace its memory image with a new program.
3. The parent calls `wait()` or `waitpid()` to reap the child exit status.

`fork()` is efficient because Linux uses copy-on-write memory. The child does not immediately copy all parent memory. Instead, parent and child initially share physical pages as read-only. If either writes, the kernel copies the modified page.

Important process states:

| State | Meaning |
| --- | --- |
| Running / runnable | On CPU or waiting for CPU. |
| Interruptible sleep | Waiting for an event and can be interrupted by signals. |
| Uninterruptible sleep (`D`) | Usually waiting on IO or kernel path that cannot be interrupted. |
| Stopped | Paused by job control or tracing. |
| Zombie (`Z`) | Exited, but parent has not reaped it. |

Zombies do not consume CPU or normal memory, but they consume PID table slots. Many zombies mean the parent is not reaping children.

## File Descriptors

File descriptors point at open files, sockets, pipes, eventfds, epoll instances, devices, and more. Many production failures are FD failures:

- process hits `ulimit -n`,
- system hits global file table pressure,
- app leaks sockets,
- logs rotate but process keeps old deleted file open,
- child processes inherit FDs that should have had `close-on-exec`.

Useful commands:

```bash
ls -l /proc/<pid>/fd
lsof -p <pid>
ulimit -n
cat /proc/sys/fs/file-nr
```

## CPU and Scheduler Basics

High CPU means runnable work is consuming CPU time. High load average means tasks are runnable or in uninterruptible sleep. Those are not identical.

What to separate:

- **User CPU:** application code.
- **System CPU:** kernel work on behalf of processes.
- **IO wait:** CPU idle while tasks wait for IO.
- **Steal:** virtual CPU time taken by the hypervisor.
- **Softirq:** deferred network/block/kernel work.

`nice` affects CPU scheduling priority for normal tasks. Real-time policies can starve normal tasks if misused.

High CPU workflow:

```bash
uptime
mpstat -P ALL 1
top -H -p <pid>
pidstat -t -p <pid> 1
perf top
cat /proc/pressure/cpu
```

First determine whether the CPU is in user code, kernel code, interrupts/softirqs, or virtualization steal. Then drill into process, thread, syscall, or interrupt source.

## RAM, Virtual Memory, and Caches

Linux memory accounting is often misunderstood. "Free memory" being low is normal because Linux uses RAM for page cache and buffers. Cache can usually be reclaimed when applications need memory.

Key terms:

| Term | Meaning |
| --- | --- |
| RSS | Resident Set Size: physical memory currently mapped for a process. |
| VIRT | Virtual address space size; not the same as physical memory used. |
| Page cache | Cached file contents. Usually reclaimable. |
| Anonymous memory | Heap/stack/private memory not backed by a file. |
| Slab | Kernel object caches. Some reclaimable, some not. |
| Swap | Disk-backed extension for anonymous memory pressure. |
| OOM killer | Kernel mechanism that kills processes when memory cannot be reclaimed. |

Memory workflow:

```bash
free -h
cat /proc/meminfo
vmstat 1
slabtop
ps aux --sort=-rss | head
cat /proc/pressure/memory
dmesg -T | grep -i -E 'oom|out of memory|killed process'
```

Do not clear caches as a routine "fix." It can make performance worse by forcing rereads. Clear cache only for controlled experiments when you understand what you are measuring.

## Paging, Swap, and Memory Pressure

Paging is moving pages between memory states: active, inactive, file-backed, anonymous, swapped, reclaimed. Swap is not automatically bad. It can improve system behavior by moving cold anonymous pages out of RAM. Swap storms are bad: the system spends most time moving pages instead of doing useful work.

Signs of dangerous memory pressure:

- rising `si`/`so` in `vmstat`,
- high memory PSI,
- direct reclaim latency,
- OOM kills,
- application latency during GC/allocation,
- cgroup memory events increasing.

Container warning: cgroup memory limits include more than just app heap. Page cache, tmpfs, and some kernel accounting can matter. A container can OOM while the host still has plenty of memory.

## Kernel Parameters and sysctl

Kernel parameters are configured in a few places:

- boot-time kernel command line: `/proc/cmdline`,
- runtime sysctls: `/proc/sys/...`,
- persistent sysctl files: `/etc/sysctl.conf` and `/etc/sysctl.d/*.conf`,
- module parameters: `/sys/module/<module>/parameters/...`,
- systemd unit limits and cgroup controls.

Common sysctl areas:

| Path | What It Affects |
| --- | --- |
| `vm.swappiness` | Kernel tendency to swap anonymous memory versus reclaiming page cache. |
| `vm.dirty_ratio` / `vm.dirty_background_ratio` | Dirty page writeback thresholds. |
| `vm.max_map_count` | Maximum memory map areas per process, relevant to JVMs, databases, and search engines. |
| `fs.file-max` | System-wide file handle maximum. |
| `net.core.somaxconn` | Listen backlog cap. |
| `net.ipv4.ip_local_port_range` | Ephemeral port range. |
| `net.ipv4.tcp_tw_reuse` | TCP TIME_WAIT reuse behavior for clients. |

Treat sysctl changes as production changes: document the reason, observe before/after, and know whether the workload is host-level or cgroup-limited.

```bash
sysctl vm.swappiness
sysctl -a | grep '^vm\.'
cat /proc/cmdline
cat /sys/module/amdgpu/parameters/* 2>/dev/null
```

## cgroups, Containers, and systemd

Modern Linux systems use cgroups to account and limit CPU, memory, IO, PIDs, and other resources. systemd uses cgroups for services; containers use cgroups for isolation.

Important signals:

- CPU quota throttling can look like mysterious latency.
- Memory limits can OOM a service even when host memory is available.
- PID limits can prevent fork/exec.
- IO limits can make a service slow without high CPU.
- Pressure Stall Information (PSI) shows time lost waiting on CPU, memory, or IO pressure.

```bash
systemctl status <service>
systemd-cgls
systemd-cgtop
cat /proc/pressure/cpu
cat /proc/pressure/memory
cat /proc/pressure/io
```

## GPU Interactions: General Model

Linux GPU stacks involve PCIe enumeration, kernel modules, firmware, device files, display or compute userspace, and sometimes container runtime hooks. GPU incidents often cross user/kernel boundaries. An application may report CUDA, ROCm, Vulkan, OpenGL, or display errors, while the root cause is kernel driver mismatch, missing firmware, permissions, PCIe reset, thermal throttling, or device memory pressure.

General GPU checks:

```bash
lspci -nnk | grep -A3 -E 'VGA|3D|Display'
ls -l /dev/dri /dev/nvidia* 2>/dev/null
dmesg -T | grep -i -E 'drm|gpu|amdgpu|nvidia|xid'
lsmod | grep -E 'amdgpu|nvidia'
```

For deeper AMD, NVIDIA, ROCm, CUDA, Secure Boot, containers, `nvidia-smi`, and NVIDIA persistence mode details, see [Linux GPU Drivers](gpu-drivers/).

## High CPU Runbook

1. Check system shape: `uptime`, `top`, `mpstat -P ALL 1`.
2. Determine user vs system vs IO wait vs steal.
3. If one process dominates, inspect threads: `top -H -p <pid>`.
4. If system CPU is high, inspect syscalls, perf, interrupts, and network softirq.
5. If load is high but CPU is not, look for D-state tasks and IO stalls.
6. Check cgroup CPU throttling for containers and systemd services.
7. Preserve evidence before restarting.

## High RAM Runbook

1. Check `free -h` and `/proc/meminfo`.
2. Separate application RSS, page cache, slab, tmpfs, and cgroup memory.
3. Check `vmstat 1` for swap activity.
4. Check PSI memory pressure.
5. Look for OOM kills in `dmesg`.
6. For a process, inspect `/proc/<pid>/smaps_rollup`.
7. For containers, inspect cgroup memory events and limits.
8. Avoid clearing caches unless testing a hypothesis.

## Commands

```bash
uname -a
cat /proc/cmdline
ps -eo pid,ppid,stat,comm,%cpu,%mem --sort=-%cpu | head
free -h
vmstat 1
mpstat -P ALL 1
pidstat -durh 1
cat /proc/pressure/{cpu,memory,io}
dmesg -T | tail -100
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is fork usually cheaper than copying an entire process?" answer="Linux uses copy-on-write pages, so parent and child initially share physical pages until one writes." %}
  {% include study-card.html question="What is the difference between high CPU and high load average?" answer="High CPU means CPU time is busy; load average also includes runnable tasks and tasks stuck in uninterruptible sleep." %}
  {% include study-card.html question="Why is low free memory not automatically bad on Linux?" answer="Linux uses available RAM for page cache and buffers, much of which can be reclaimed when applications need memory." %}
  {% include study-card.html question="What does vm.swappiness influence?" answer="The tendency to reclaim anonymous memory via swap versus reclaiming file-backed page cache." %}
  {% include study-card.html question="What does a zombie process indicate?" answer="The child exited, but its parent has not called wait to reap the exit status." %}
  {% include study-card.html question="What is Pressure Stall Information useful for?" answer="It shows time workloads lose because CPU, memory, or IO resources are unavailable." %}
  {% include study-card.html question="What is amdgpu?" answer="The mainline Linux kernel DRM driver for supported AMD Radeon GPU families including GCN, RDNA, and CDNA." %}
  {% include study-card.html question="What does NVIDIA persistence mode do?" answer="It keeps the GPU initialized when no clients are connected, reducing initialization latency and lifecycle churn on Linux GPU systems." %}
</div>

## Practice Deck

{% include study-card-deck.html deck="linux" %}

## References

- [Linux kernel sysctl VM documentation](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html)
- [Linux kernel cgroup v2 documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)
- [Linux kernel Pressure Stall Information](https://www.kernel.org/doc/html/latest/accounting/psi.html)
- [proc(5) Linux manual page](https://man7.org/linux/man-pages/man5/proc.5.html)
- [fork(2) Linux manual page](https://man7.org/linux/man-pages/man2/fork.2.html)
- [execve(2) Linux manual page](https://man7.org/linux/man-pages/man2/execve.2.html)
- [wait(2) Linux manual page](https://man7.org/linux/man-pages/man2/wait.2.html)
- [Linux kernel AMDGPU documentation](https://docs.kernel.org/gpu/amdgpu/index.html)
- [NVIDIA driver persistence documentation](https://docs.nvidia.com/deploy/driver-persistence/index.html)
- [Linux GPU drivers](gpu-drivers/)
- [Linux boot and userspace](boot-userspace/)
- [Linux kernel modules and devices](kernel-modules-devices/)
- [Linux filesystems and IO](filesystems-io/)
- [Linux block devices and partitioning](block-devices-partitions/)
- [Linux mounts and fstab](mounts-fstab/)
- [Linux mount namespaces and propagation](mount-namespaces-propagation/)
- [ext4, XFS, and filesystem repair](ext4-xfs-repair/)
- [RAID, multipath, and device mapper](raid-multipath-device-mapper/)
- [Linux storage health and performance](storage-health-performance/)
- [Linux network stack](network-stack/)
- [Linux kernel network performance](kernel-network-performance/)
- [Linux TCP kernel tuning](tcp-kernel-tuning/)
- [Linux sockets and IPC](sockets-ipc/)
- [Linux processes and threads](processes-threads/)
- [Debian and Ubuntu operations](debian-ubuntu/)
- [Users, permissions, and sudo](users-permissions-sudo/)
- [SSH access](ssh-access/)
- [Logs and observability](logs-observability/)
- [Scheduled automation](scheduled-automation/)
- [Time, hostname, and identity](time-hostname/)
- [Linux LVM](lvm/)
- [systemd](systemd/)
- [systemd networking](systemd-networking/)
- [systemd socket activation and network services](systemd-socket-network-services/)
- [resolv.conf](resolv-conf/)
