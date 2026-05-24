---
title: Containerization, OCI, and VMs
layout: page
permalink: /docs/linux/containerization-oci-vms/
summary: "Container fundamentals, OCI image/runtime/distribution standards, Linux namespaces, cgroups, overlay layers, bridge networking, macOS and Windows container behavior, KVM, hypervisors, and VM/container tradeoffs."
tags:
  - linux
  - containers
  - oci
  - virtualization
  - cgroups
  - namespaces
---

# Containerization, OCI, and VMs

Containers are isolated processes, not tiny full computers. On Linux, container runtimes combine kernel features such as namespaces, cgroups, capabilities, seccomp, filesystem mounts, and networking to make one or more processes see a constrained view of the host. Virtual machines isolate a whole guest operating system behind virtual hardware and a hypervisor.

## First Checks

```bash
docker info
docker image inspect <image>
docker container inspect <container>
cat /proc/<pid>/status
cat /proc/<pid>/cgroup
readlink /proc/<pid>/ns/*
cat /proc/<pid>/mountinfo
lsns -p <pid>
docker network inspect bridge
ip link show type bridge
bridge link
nft list ruleset
```

## VM vs Container

| Feature | Container | Virtual Machine |
| --- | --- | --- |
| Kernel | Shares the host kernel or a VM-provided kernel. | Runs its own guest kernel. |
| Boundary | Process isolation plus kernel-enforced resource and namespace boundaries. | Hardware virtualization boundary around a guest OS. |
| Startup | Usually fast: start processes and set isolation. | Usually slower: boot or resume a guest OS. |
| Image | Application filesystem layers plus metadata. | Disk image with OS, bootloader, kernel, and userspace. |
| Density | High, because containers share one kernel. | Lower, because each VM carries an OS. |
| Compatibility | Must match kernel family and CPU architecture expectations. | Can run different OS kernels supported by the hypervisor. |
| Security model | Strong but still shares kernel attack surface unless nested in a VM. | Stronger kernel boundary, more overhead. |

The practical rule: use containers to package and isolate applications that can share a kernel. Use VMs when you need a different kernel, stronger tenant isolation, kernel modules, full boot behavior, or OS-level compatibility.

## How Linux Containers Work

Linux containers are possible because several kernel features compose:

| Feature | What It Does |
| --- | --- |
| Mount namespace | Gives a process its own view of mounted filesystems. |
| PID namespace | Gives a process tree its own PID view, often making the app PID 1 inside the container. |
| Network namespace | Gives isolated interfaces, routes, sockets, firewall state, and loopback. |
| IPC namespace | Isolates System V IPC and POSIX message queues. |
| UTS namespace | Isolates hostname and domain name. |
| User namespace | Maps container users to different host users, enabling safer rootless behavior. |
| cgroups | Account and limit CPU, memory, I/O, PIDs, and other resources. |
| Capabilities | Split root privileges into smaller privileges such as network admin or raw sockets. |
| seccomp | Filters syscalls available to a process. |
| LSMs | SELinux, AppArmor, and similar systems add mandatory access-control policy. |
| Overlay filesystem | Combines read-only image layers with a writable upper layer. |

A runtime starts a container roughly like this:

1. Prepare the root filesystem from image layers.
2. Create namespaces for the process.
3. Configure mounts, bind mounts, and the working directory.
4. Configure cgroups for CPU, memory, pids, and I/O limits.
5. Drop capabilities, set seccomp/AppArmor/SELinux policy, and set user mappings.
6. Configure networking, often with veth pairs, bridges, NAT, or CNI.
7. `exec` the configured process.

The result feels like a small machine because pathnames, process IDs, network interfaces, users, and resource limits look local. It is still one or more host processes enforced by the kernel.

## From Image to Running Process

A container image is stored data. It does not run. The kernel runs a normal process whose root filesystem, namespace membership, credentials, resource controls, and mounts were prepared by container tooling.

The path from registry image to process usually looks like this:

1. A client asks for a tag such as `app:1.2.3`.
2. The registry returns an OCI image index or manifest. Multi-architecture images use an index to point at per-platform manifests such as `linux/amd64` or `linux/arm64`.
3. The runtime downloads content-addressed blobs: image config and compressed layer blobs.
4. Layers are verified by digest, decompressed, and unpacked into runtime storage.
5. The runtime creates a mounted root filesystem, often through `overlayfs`.
6. The runtime writes or derives an OCI runtime bundle: a root filesystem plus `config.json`.
7. An OCI runtime such as `runc` or `crun` creates namespaces, joins cgroups, sets mounts, applies security policy, and `exec`s the configured command.

Useful inspection commands:

```bash
docker image inspect nginx:latest
docker image history nginx:latest
docker container inspect <container> --format '{% raw %}{{.State.Pid}}{% endraw %}'
findmnt -T /var/lib/docker
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS | grep overlay
readlink /proc/<pid>/root
cat /proc/<pid>/mountinfo
```

The important mental model: container images describe a filesystem and process configuration. The kernel only sees mounted filesystems, tasks, credentials, namespaces, cgroups, sockets, and security labels.

## What the Kernel Enforces

The Linux kernel does not know that an OCI image tag exists. Runtime software translates image metadata into kernel operations.

| Runtime Intent | Kernel Mechanism |
| --- | --- |
| Isolate process IDs | `clone`, `unshare`, `setns`, and PID namespaces. |
| Give a private filesystem view | Mount namespaces, bind mounts, overlay mounts, `pivot_root`, and sometimes `chroot`. |
| Limit memory, CPU, IO, and process count | cgroup controller files under `/sys/fs/cgroup`. |
| Reduce root privilege | Linux capabilities, user namespaces, UID/GID maps, and `no_new_privs`. |
| Restrict syscalls | seccomp filters evaluated on syscall entry. |
| Apply mandatory policy | SELinux, AppArmor, or another Linux Security Module. |
| Isolate network view | Network namespaces, veth devices, routes, bridge ports, and netfilter state. |

That translation is why container debugging often leaves the container CLI quickly and moves into `/proc`, `/sys/fs/cgroup`, `findmnt`, `lsns`, `ip`, `bridge`, `nft`, and `ss`. Those tools show the kernel state that actually enforces the container boundary.

## OCI Standards

The Open Container Initiative defines interoperable container standards. The three practical specs are:

| OCI Spec | Purpose |
| --- | --- |
| Image Specification | Defines container image layout, manifests, configs, layers, descriptors, and digests. |
| Runtime Specification | Defines how to run an unpacked filesystem bundle with a `config.json`. |
| Distribution Specification | Defines registry API behavior for pushing and pulling content-addressed images. |

Common runtime chain:

```text
docker or nerdctl CLI
containerd or CRI-O
runc, crun, or another OCI runtime
Linux kernel namespaces, cgroups, mounts, capabilities, seccomp
```

Kubernetes adds the Container Runtime Interface (CRI) between kubelet and the runtime. kubelet asks a CRI implementation such as containerd or CRI-O to create Pod sandboxes and containers. The low-level OCI runtime still creates the isolated process.

## Images, Layers, and Registries

An image is not one tarball in normal operation. It is a set of content-addressed objects:

- manifest or index,
- image config,
- filesystem layers,
- descriptors with media types, sizes, and digests.

Layers are usually read-only and shared across images when their digests match. A running container gets a writable layer on top. Deleting a container can remove that writable layer, which is why persistent data belongs in volumes, bind mounts, databases, object storage, or another external state path.

Registries store and serve image content. Tags are mutable names. Digests are immutable content identifiers. For production deployment, pinning or recording digests gives stronger evidence of exactly what ran.

## Layer Mechanics and overlayfs

Layering is what makes images reusable, cacheable, and cheap to start.

| Term | Meaning |
| --- | --- |
| Manifest | Points to the image config and layer descriptors for one platform. |
| Index | Points to multiple manifests, usually for different CPU architectures or OS platforms. |
| Config | Stores command, environment, user, working directory, exposed ports, labels, and rootfs diff IDs. |
| Layer blob | A compressed filesystem diff stored by digest in a registry or local content store. |
| diffID | Digest of an uncompressed layer diff. |
| Chain ID | Identifier derived from the ordered sequence of unpacked layer diffs. |
| Writable layer | Per-container upper layer that records changes made after start. |

On Linux Docker installations, the storage driver is often `overlay2`, which uses kernel `overlayfs`.

```text
lowerdir = read-only image layers
upperdir = writable per-container layer
workdir  = overlayfs working directory
merged   = mounted view presented to the container
```

When a process reads a file, overlayfs searches from the top layer down through lower layers. When a process writes to a file that exists in a lower layer, overlayfs performs copy-up: it copies the file into the `upperdir` and modifies that copy. When a process deletes a file from a lower layer, overlayfs records a whiteout in the upper layer so the file disappears from the merged view.

Practical consequences:

- Rewriting a large file from a lower layer can copy the whole file into the writable layer.
- Deleting a file from an earlier image layer does not remove the bytes from that earlier layer; it hides the file in later layers.
- Volumes and bind mounts bypass the image writable layer at their mount paths.
- Image layer count, build cache order, and package manager cleanup affect size and rebuild speed.
- Overlay semantics can matter for databases and write-heavy workloads; persistent database data should live on a real volume or host filesystem chosen for that workload.

Example checks:

```bash
docker inspect <container> --format '{% raw %}{{json .GraphDriver.Data}}{% endraw %}'
findmnt -t overlay
du -sh /var/lib/docker/overlay2/* 2>/dev/null
```

## cgroups and Resource Control

cgroups account for and limit resource use. They do not make a process believe it has a private CPU or private memory bus. Namespaces change what a process can see; cgroups control what it can consume.

Most modern distributions use cgroup v2, a unified hierarchy under `/sys/fs/cgroup`. systemd, container runtimes, and Kubernetes all place processes into cgroup paths and write controller files.

| cgroup v2 File | Meaning |
| --- | --- |
| `cgroup.controllers` | Controllers available below this point in the hierarchy. |
| `cgroup.procs` | Processes in this cgroup. |
| `cpu.max` | CPU quota and period. `max 100000` means no quota with a 100 ms period. |
| `cpu.stat` | CPU usage and throttling counters. |
| `memory.max` | Hard memory limit. |
| `memory.current` | Current charged memory. |
| `memory.events` | OOM, high, max, and pressure event counters. |
| `pids.max` | Maximum number of processes or threads. |
| `io.max` | Per-device I/O throttling limits. |

Useful checks:

```bash
cat /proc/<pid>/cgroup
systemd-cgls
systemd-cgtop
cat /sys/fs/cgroup/<path>/cpu.max
cat /sys/fs/cgroup/<path>/cpu.stat
cat /sys/fs/cgroup/<path>/memory.current
cat /sys/fs/cgroup/<path>/memory.max
cat /sys/fs/cgroup/<path>/memory.events
cat /sys/fs/cgroup/<path>/pids.max
```

Common cgroup surprises:

- CPU quota throttling can make a process slow even when host CPU looks idle.
- Memory limits include more than application heap: page cache, tmpfs, some kernel memory, and allocator fragmentation can matter.
- `pids.max` counts threads too, so highly threaded applications can hit PID limits.
- cgroup OOM kills are local to the cgroup and may happen while the host still has free memory.
- systemd services and containers are both cgroup-managed, so host unit limits can stack with container limits.

## Namespaces and PID 1

Namespaces provide isolated views of kernel resources. A process can be in the host mount namespace but a container network namespace, or in a new PID namespace but the host cgroup hierarchy. These features compose independently.

```bash
readlink /proc/<pid>/ns/pid
readlink /proc/<pid>/ns/mnt
readlink /proc/<pid>/ns/net
readlink /proc/1/ns/net
lsns -p <pid>
nsenter -t <pid> -m -p -n -- ps aux
nsenter -t <pid> -n -- ip addr
```

Inside a PID namespace, the first process becomes PID 1 for that namespace. PID 1 has special responsibilities:

- reap zombie child processes,
- handle `SIGTERM` and other shutdown signals correctly,
- forward signals to child processes when it is a wrapper script or supervisor.

If an application was never designed to be PID 1, use a small init such as `tini`, Docker `--init`, or a container entrypoint that forwards signals and waits correctly.

## Container Networking on Linux

The default Linux container network model uses the same primitives an administrator can create by hand: network namespaces, veth pairs, Linux bridges, routes, netfilter NAT, and conntrack.

| Primitive | Role |
| --- | --- |
| Network namespace | Gives the container its own interfaces, addresses, routes, sockets, and firewall view. |
| veth pair | A virtual Ethernet cable: one end in the container netns, one end on the host. |
| Linux bridge | Software switch that connects veth peers and often has the host gateway IP. |
| IPAM | Allocates container IPs from a bridge subnet. |
| netfilter/nftables/iptables | Applies filtering, DNAT for published ports, and SNAT/MASQUERADE for egress. |
| conntrack | Remembers translated flows so return traffic is mapped back correctly. |

For Docker's default bridge path, the container sees something like `eth0` and a default route through the bridge gateway. The host sees the peer veth attached to a bridge such as `docker0`.

```text
container process
container eth0
veth pair
host bridge docker0 or br-...
host routing table
netfilter SNAT/MASQUERADE
physical or virtual NIC
```

A Linux bridge is a Layer 2 software switch. NAT is separate. The bridge learns MAC addresses and forwards Ethernet frames between ports. netfilter handles address translation and firewall decisions around that path.

## Bridge Networks and Packet Paths

Default bridge network:

- Docker usually creates `docker0`.
- Containers get addresses from the bridge subnet.
- The host bridge address is normally the default gateway for containers.
- Container-to-container communication on the same bridge can stay local to the bridge.
- Egress to outside networks commonly uses MASQUERADE so external peers see the host address.

User-defined bridge networks:

- get their own bridge device, subnet, and rules,
- provide better service-name DNS behavior than the legacy default bridge,
- isolate groups of containers from other bridge networks unless routing or rules allow traffic.

Published port path:

```text
client -> host_ip:published_port
netfilter PREROUTING or OUTPUT DNAT
container_ip:container_port
bridge
veth
container process
```

Egress path:

```text
container_ip:ephemeral_port -> remote_ip:remote_port
veth -> bridge -> host route
POSTROUTING SNAT/MASQUERADE
remote sees host_ip:translated_port
return traffic matched by conntrack
```

Important bridge and NAT details:

- `docker0` is not present for every runtime or every Docker network; user-defined bridges are often named `br-<id>`.
- Hairpin NAT may be needed when a container or host reaches a service through the host's published port and the traffic loops back to the same bridge.
- MTU mismatches are common when bridges, VXLAN, VPNs, or cloud networks add encapsulation overhead.
- Docker Desktop networking has a Linux VM boundary; the bridge and iptables rules live inside that VM, not directly on macOS.
- Containers inherit generated DNS configuration. User-defined Docker bridges commonly provide an embedded DNS resolver for container names.
- Host access is platform-specific. `host.docker.internal` exists on Docker Desktop and can be configured on Linux, but it is not a universal kernel feature.

Networking inspection examples:

```bash
docker network ls
docker network inspect bridge
ip link show type bridge
bridge link
ip addr show docker0
ip route
nft list ruleset
iptables -t nat -S
conntrack -L 2>/dev/null | head
nsenter -t <pid> -n -- ip addr
nsenter -t <pid> -n -- ip route
nsenter -t <pid> -n -- ss -tulpen
tcpdump -ni any host <container-ip>
```

## Other Container Network Modes

| Mode | What Changes | Common Use |
| --- | --- | --- |
| Bridge | Container has its own netns connected through veth and a Linux bridge. | Default single-host application networking. |
| Host | Container shares the host network namespace. | Low overhead or software that must bind host interfaces directly. |
| None | Container gets no external interface beyond loopback. | Batch jobs, manual networking, or high isolation. |
| macvlan | Container gets a MAC address on the physical L2 network. | Legacy apps that must appear as first-class LAN hosts. |
| ipvlan | Similar goal to macvlan with different L2/L3 behavior and fewer MAC scaling issues. | Dense networks where switch MAC table pressure matters. |
| Overlay | Encapsulates container traffic across hosts, commonly with VXLAN. | Multi-host container platforms and some Kubernetes CNIs. |

Kubernetes uses CNI plugins rather than Docker's bridge driver as the main abstraction. Depending on the plugin, Pod traffic may use Linux bridges, veth pairs, routing, VXLAN, Geneve, BGP, eBPF, cloud VPC interfaces, or some combination. The primitives are still Linux networking primitives plus plugin-specific control logic.

## Linux, macOS, and Windows

| Host | What Actually Runs |
| --- | --- |
| Linux host with Docker Engine/containerd | Linux containers run directly as isolated Linux processes on the host kernel. |
| macOS with Docker Desktop | Linux containers run inside a Linux VM managed by Docker Desktop. macOS does not provide a Linux kernel for them directly. |
| Windows with Docker Desktop and WSL 2 | Linux containers run inside a WSL 2 Linux VM/backend. |
| Windows Server containers, process isolation | Windows containers share the Windows host kernel with process isolation. |
| Windows containers, Hyper-V isolation | Each container runs inside a small utility VM and gets a stronger kernel boundary. |

This explains common confusion: a Linux container image expects Linux kernel interfaces. On macOS and Windows developer laptops, Linux containers work because a Linux VM is present under the container tooling. Native Windows containers are a separate world with Windows base images and Windows isolation modes.

## KVM and Hypervisors

A hypervisor runs virtual machines by presenting virtual hardware to guest operating systems.

| Term | Meaning |
| --- | --- |
| Type 1 hypervisor | Runs close to hardware, such as Hyper-V, ESXi, or KVM when the Linux kernel acts as the hypervisor. |
| Type 2 hypervisor | Runs as an application on a host OS, though modern boundaries can be blurry. |
| KVM | Linux kernel virtualization support that turns Linux into a hypervisor for hardware-assisted VMs. |
| QEMU | User-space emulator and device model commonly paired with KVM acceleration. |
| Firecracker/Kata-style isolation | Uses lightweight VMs to give container-like workflows stronger VM boundaries. |

VMs and containers are not enemies. They are often stacked:

- Docker Desktop runs Linux containers inside a VM on macOS and Windows.
- Kubernetes nodes may be VMs running containers.
- Kata Containers and similar systems run each container or Pod in a lightweight VM.
- Windows Hyper-V isolation runs containers inside optimized VMs.

## Why Containers Are Not Full Security Boundaries By Default

Containers can be strong isolation, but defaults and host integration matter. Risk increases with:

- privileged containers,
- host PID, network, IPC, or mount namespaces,
- broad bind mounts such as `/`, `/var/run/docker.sock`, or host credentials,
- added capabilities such as `SYS_ADMIN`,
- disabled seccomp/AppArmor/SELinux profiles,
- running as root without user namespace isolation,
- writable host paths shared with untrusted workloads.

Security improves with least privilege, rootless containers, read-only filesystems, minimal capabilities, seccomp, LSM policy, signed images, SBOMs, digest pinning, and separate nodes or VMs for untrusted tenants.

## Operational Differences

| Symptom | Container Lens | VM Lens |
| --- | --- | --- |
| Out of memory | cgroup memory limit, tmpfs, page cache, application heap. | Guest memory size, ballooning, host pressure, swap. |
| High CPU latency | cgroup quota throttling, host CPU contention, noisy neighbor container. | vCPU scheduling, steal time, host oversubscription. |
| Disk path missing | mount namespace, bind mount, volume driver, overlay layer. | Guest disk attachment, virtio/SCSI/NVMe device, filesystem mount. |
| Network unreachable | network namespace, veth, bridge, NAT, CNI, policy. | virtual NIC, hypervisor switch, guest firewall, host routing. |
| PID 1 behavior | App may need init/reaping and signal handling. | OS init system handles normal service lifecycle. |

## Debugging Flow

1. Identify whether the workload is a process on Linux, a Linux container in a VM, a native Windows container, or a full VM.
2. Find the real host process with `docker inspect`, `crictl inspect`, or runtime tools.
3. Inspect namespaces with `lsns`, `/proc/<pid>/ns`, and `/proc/<pid>/mountinfo`.
4. Inspect cgroups with `/proc/<pid>/cgroup` and cgroup controller files.
5. Check capabilities, seccomp, AppArmor/SELinux labels, and user mappings.
6. For macOS and Windows Linux containers, remember the Linux VM boundary when debugging files, ports, memory, and disk usage.
7. For VMs, inspect hypervisor, guest kernel, virtual devices, and host resource pressure.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is a Linux container?" answer="One or more isolated host processes using namespaces, cgroups, mounts, capabilities, seccomp, and related kernel features." %}
  {% include study-card.html question="What is the biggest VM versus container difference?" answer="A VM runs its own guest kernel; a container usually shares the host or VM-provided kernel." %}
  {% include study-card.html question="What does OCI standardize?" answer="Image format, runtime bundle behavior, and registry distribution behavior for interoperable containers." %}
  {% include study-card.html question="Why do Linux containers run on macOS?" answer="Tooling such as Docker Desktop runs them inside a Linux virtual machine because macOS does not provide a Linux kernel." %}
  {% include study-card.html question="What do cgroups provide for containers?" answer="Hierarchical accounting and limits for resources such as CPU, memory, I/O, and PIDs." %}
  {% include study-card.html question="What do namespaces provide for containers?" answer="Isolated views of resources such as mounts, PIDs, network interfaces, IPC, hostname, and users." %}
  {% include study-card.html question="What does overlayfs provide for containers?" answer="A merged filesystem view made from read-only lower image layers plus a writable upper layer." %}
  {% include study-card.html question="What is copy-up in overlayfs?" answer="When a lower-layer file is changed, overlayfs copies it into the writable upper layer and modifies that copy." %}
  {% include study-card.html question="What does a Linux bridge do for containers?" answer="It acts like a software switch connecting host-side veth peers for containers on the same bridge network." %}
  {% include study-card.html question="What usually implements Docker published ports on Linux?" answer="Netfilter DNAT rules translate host ports to container addresses, with conntrack tracking the flow." %}
  {% include study-card.html question="What is KVM?" answer="Linux kernel virtualization support that lets Linux act as a hypervisor for hardware-assisted virtual machines." %}
</div>

## References

- [Open Container Initiative](https://opencontainers.org/)
- [OCI Runtime Specification](https://github.com/opencontainers/runtime-spec)
- [OCI Image Specification](https://github.com/opencontainers/image-spec)
- [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec)
- [Linux namespaces manual](https://man7.org/linux/man-pages/man7/namespaces.7.html)
- [Linux cgroups manual](https://man7.org/linux/man-pages/man7/cgroups.7.html)
- [Linux cgroup v2 documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)
- [Linux overlayfs documentation](https://docs.kernel.org/filesystems/overlayfs.html)
- [Linux bridge documentation](https://docs.kernel.org/networking/bridge.html)
- [ip-netns(8)](https://man7.org/linux/man-pages/man8/ip-netns.8.html)
- [Docker bridge network driver](https://docs.docker.com/engine/network/drivers/bridge/)
- [Linux KVM documentation](https://www.kernel.org/doc/html/latest/virt/kvm/index.html)
- [Docker Desktop networking](https://docs.docker.com/desktop/features/networking/)
- [Docker Desktop on Mac virtual machine manager](https://docs.docker.com/desktop/features/vmm/)
- [Docker Desktop WSL 2 backend](https://docs.docker.com/docker-for-windows/wsl/)
- [Windows container isolation modes](https://learn.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/hyperv-container)
