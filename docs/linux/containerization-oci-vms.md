---
title: Containerization, OCI, and VMs
layout: page
permalink: /docs/linux/containerization-oci-vms/
summary: "Container fundamentals, OCI image/runtime/distribution standards, Linux namespaces, cgroups, capabilities, seccomp, macOS and Windows container behavior, KVM, hypervisors, and VM/container tradeoffs."
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
lsns -p <pid>
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
- [Linux KVM documentation](https://www.kernel.org/doc/html/latest/virt/kvm/index.html)
- [Docker Desktop networking](https://docs.docker.com/desktop/features/networking/)
- [Docker Desktop on Mac virtual machine manager](https://docs.docker.com/desktop/features/vmm/)
- [Docker Desktop WSL 2 backend](https://docs.docker.com/docker-for-windows/wsl/)
- [Windows container isolation modes](https://learn.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/hyperv-container)
