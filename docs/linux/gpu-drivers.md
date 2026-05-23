---
title: Linux GPU Drivers
layout: page
permalink: /docs/linux/gpu-drivers/
summary: Linux GPU driver stacks for AMD and NVIDIA, including kernel modules, firmware, Mesa, ROCm, CUDA, nvidia-smi, Secure Boot, containers, and troubleshooting.
tags:
  - linux
  - gpu
  - amd
  - nvidia
  - troubleshooting
---

# Linux GPU Drivers

Linux GPU incidents cross several layers at once: PCIe enumeration, kernel modules, firmware, display management, compute runtimes, device-node permissions, userspace libraries, containers, and application frameworks. Do not treat "the driver" as one file. A working GPU stack is a matched set of kernel and userspace pieces.

## First Checks

```bash
lspci -nnk | grep -A4 -E 'VGA|3D|Display'
lsmod | grep -E 'amdgpu|radeon|nvidia|nouveau'
ls -l /dev/dri /dev/nvidia* 2>/dev/null
dmesg -T | grep -Ei 'drm|amdgpu|nvidia|nouveau|xid|firmware'
cat /proc/driver/nvidia/version 2>/dev/null
nvidia-smi 2>/dev/null
```

These commands answer the first operational questions: is the PCI device visible, which kernel module bound to it, which device nodes exist, whether firmware or reset errors appeared in kernel logs, and whether NVIDIA userspace can talk to the loaded NVIDIA kernel driver.

## Stack Model

| Layer | AMD Examples | NVIDIA Examples | What Breaks |
| --- | --- | --- | --- |
| PCIe and platform | PCI bus, BARs, IOMMU, power, firmware | PCI bus, BARs, IOMMU, power, firmware | Device not enumerated, AER errors, reset failures, wrong NUMA path. |
| Kernel module | `amdgpu`, older `radeon` for some legacy GPUs | `nvidia`, `nvidia_uvm`, `nvidia_modeset`, `nvidia_drm`; `nouveau` as open driver | Module not loaded, wrong module bound, Secure Boot rejection, DKMS build failure. |
| Firmware and microcode | `linux-firmware`, PSP/SMU/display firmware | GSP firmware on supported devices, driver-bundled components | Missing firmware, failed initialization, feature unavailable. |
| Kernel graphics API | DRM, KMS, GEM/TTM, render nodes | NVIDIA kernel/user APIs plus optional DRM KMS integration | No `/dev/dri`, display fails, compositor cannot modeset. |
| Userspace graphics | Mesa RadeonSI for OpenGL, RADV for Vulkan | NVIDIA OpenGL/Vulkan userspace libraries | Wrong library path, mixed vendor libraries, app uses software renderer. |
| Compute runtime | ROCm/HIP, OpenCL stacks | CUDA, NVML, NCCL, container runtime | Runtime cannot see GPU, unsupported GPU, version mismatch. |
| Containers | `/dev/dri/renderD*`, ROCm userspace, group permissions | NVIDIA Container Toolkit, driver-mounted libraries, CUDA images | Devices or libraries missing inside container. |

The kernel module and userspace libraries must match the workload. A desktop can render through the display stack while compute fails because ROCm/CUDA support, permissions, or container hooks are wrong. A compute node can run CUDA while a graphical session is irrelevant or absent.

## Device Nodes and Permissions

Common device paths:

| Path | Meaning |
| --- | --- |
| `/dev/dri/card*` | DRM primary nodes, often used by display servers and privileged graphics management. |
| `/dev/dri/renderD*` | DRM render nodes for unprivileged rendering or compute userspace. |
| `/dev/kfd` | AMD kernel fusion driver node used by ROCm/HSA workloads. |
| `/dev/nvidia*` | NVIDIA driver devices for control, memory, UVM, and GPU access. |

Permissions matter. On many systems users need membership in groups such as `render` or `video`, depending on distro rules. For containers, passing only the GPU device node may not be enough; the matching userspace libraries and runtime hooks must also be present.

## AMD GPU Stack

The upstream Linux kernel `amdgpu` DRM driver supports AMD Radeon GPUs based on GCN, RDNA, and CDNA architectures. It covers kernel responsibilities such as device initialization, memory management, scheduling rings, interrupts, display, power management, firmware interfaces, reset handling, and sysfs/debugfs exposure.

AMD graphics userspace is commonly Mesa:

| Component | Role |
| --- | --- |
| `amdgpu` | Kernel driver for supported AMD GPUs. |
| `linux-firmware` | Firmware blobs needed by many GPUs for display, power, security, and compute microcontrollers. |
| RadeonSI | Mesa OpenGL driver for AMD GPUs. |
| RADV | Mesa Vulkan driver for AMD GCN/RDNA GPUs. |
| ROCm/HIP | AMD compute platform and programming stack for supported GPUs and operating systems. |
| `rocm-smi` / `rocminfo` | ROCm-oriented status and discovery tools. |

Important nuance: some older GCN generations may still bind to the older `radeon` kernel driver by default on some distributions. Mesa's RADV documentation notes that older GFX6-7 GPUs may require explicitly enabling `amdgpu` and disabling `radeon` through kernel parameters before RADV works. Do not cargo-cult those parameters onto modern systems; first confirm the PCI ID, generation, current bound driver, and distro defaults.

AMD checks:

```bash
lspci -nnk | grep -A4 -E 'VGA|3D|Display'
modinfo amdgpu | head
cat /sys/module/amdgpu/parameters/* 2>/dev/null
ls -l /dev/dri /dev/kfd 2>/dev/null
find /sys/class/drm -maxdepth 3 -type f -name '*busy*' -o -name '*mem*'
dmesg -T | grep -i -E 'amdgpu|firmware|gpu reset|ring|psp|smu'
```

ROCm checks:

```bash
rocminfo
rocm-smi
groups
ls -l /dev/kfd /dev/dri/renderD* 2>/dev/null
```

For ROCm, always check AMD's current support matrix for the exact GPU, OS, kernel, and ROCm version. A GPU can work well for Mesa graphics while still being unsupported or partially supported for ROCm compute. AMD's current ROCm Linux installation docs also emphasize package-manager based installation paths, so avoid stale installer instructions unless the current vendor doc for your product explicitly says otherwise.

## NVIDIA GPU Stack

NVIDIA's production Linux stack commonly includes NVIDIA kernel modules plus NVIDIA userspace libraries. On Ubuntu, driver packaging distinguishes generic desktop/UDA drivers from Enterprise Ready Driver packages, whose names commonly include `-server` and are recommended for server and compute tasks. Ubuntu also packages open kernel module variants with `-open` in the package name for supported hardware.

Core NVIDIA pieces:

| Component | Role |
| --- | --- |
| `nvidia` | Main NVIDIA kernel module. |
| `nvidia_uvm` | Unified Virtual Memory support used by CUDA workloads. |
| `nvidia_modeset` / `nvidia_drm` | Display and DRM integration pieces when used. |
| `nvidia-smi` | CLI for monitoring and management through NVML. |
| NVML | C library API behind many stable monitoring integrations. |
| CUDA libraries | Userspace compute runtime and libraries. |
| Fabric Manager | Required for some NVSwitch/NVLink fabric environments. |
| NVIDIA Container Toolkit | Makes host NVIDIA GPUs and driver libraries available to containers. |

NVIDIA notes:

- `nvidia-smi` text output is useful for humans, but NVIDIA documents NVML as the better target for tools that must survive driver-release changes.
- Use GPU UUID or PCI bus ID in automation; `nvidia-smi` warns that natural GPU enumeration order is not guaranteed across reboots.
- Persistence mode reduces driver lifecycle churn when no clients are attached. On Linux, `nvidia-persistenced` is the daemon-based approach.
- Some `nvidia-smi` changes require root and may not persist across reboot, while others such as ECC mode can be persistent or take effect after reboot depending on the setting.
- GPU reset is not guaranteed to work in every case. NVIDIA explicitly recommends verifying GPU health afterward and power cycling the node if the device is not healthy.

NVIDIA checks:

```bash
nvidia-smi
nvidia-smi -L
nvidia-smi --query-gpu=uuid,pci.bus_id,driver_version,persistence_mode,memory.used,memory.total,temperature.gpu,power.draw --format=csv
nvidia-smi topo -m
cat /proc/driver/nvidia/version
lsmod | grep -E 'nvidia|nouveau'
dmesg -T | grep -i -E 'nvidia|xid|nouveau|NVRM'
```

## Ubuntu NVIDIA Packaging and Secure Boot

On Ubuntu, prefer `ubuntu-drivers` or Ubuntu/NVIDIA apt packages over runfile installers for routine server operations. Ubuntu's documentation warns that drivers installed from sources outside the guide can overwrite packaged drivers and may break Secure Boot.

Useful commands:

```bash
sudo ubuntu-drivers list --gpgpu
sudo ubuntu-drivers install --gpgpu
apt-cache policy 'nvidia-driver-*'
apt-cache policy linux-modules-nvidia-$(uname -r)
apt-cache policy linux-headers-$(uname -r)
mokutil --sb-state
```

Secure Boot is a common failure boundary:

- Prebuilt Ubuntu `linux-modules-nvidia-*` packages are signed for supported kernels.
- DKMS-built modules need headers and signing/enrollment when Secure Boot is enabled.
- A driver install can appear successful while the kernel refuses to load an unsigned module.
- Kernel upgrades can strand a host if matching NVIDIA modules are not available for the running kernel ABI.

## Containers and Kubernetes

GPU containers are not just normal containers with a device file added.

For NVIDIA, the NVIDIA Container Toolkit wires host driver libraries and devices into containers. Kubernetes clusters usually layer a device plugin or GPU Operator on top, but the host still needs a working kernel driver and runtime integration.

For AMD, containers often need `/dev/kfd`, `/dev/dri/renderD*`, group permissions, and ROCm userspace compatible with the host kernel/driver stack. Kubernetes deployments need node labels, device plugin behavior, and images built for the expected ROCm version.

Container debugging split:

1. Does the host see the GPU?
2. Does the host runtime tool work (`nvidia-smi`, `rocminfo`, `rocm-smi`)?
3. Does the container have the device nodes?
4. Does the container have compatible userspace libraries?
5. Does the orchestrator expose the GPU resource and schedule onto the right node?

## Failure Modes

| Symptom | Likely Boundary | Checks |
| --- | --- | --- |
| GPU absent from `lspci` | Hardware, firmware, BIOS, PCIe, power, passthrough | BIOS/firmware, BMC inventory, PCIe slot, IOMMU, host logs. |
| PCI device visible but no driver | Kernel module, Secure Boot, unsupported ID | `lspci -nnk`, `modprobe`, `dmesg`, `mokutil --sb-state`. |
| Driver loaded but tool fails | Userspace/kernel mismatch or permissions | `cat /proc/driver/nvidia/version`, package versions, `/dev` permissions. |
| AMD graphics works but ROCm fails | ROCm support matrix, `/dev/kfd`, groups, userspace | `rocminfo`, `rocm-smi`, supported GPU/OS/kernel matrix. |
| NVIDIA CUDA fails but display works | `nvidia_uvm`, CUDA library mismatch, container runtime | `lsmod`, `nvidia-smi`, CUDA sample, container runtime config. |
| Xid or GPU reset messages | NVIDIA device, driver, power, thermal, PCIe, app workload | `dmesg`, `nvidia-smi -q`, power/thermal history, workload logs. |
| `amdgpu` ring timeout or reset | AMD kernel/display/firmware/runtime boundary | `dmesg`, firmware package, kernel version, workload trigger. |
| GPU numbering changes | Enumeration order changed | Use UUID or PCI bus ID, not index. |
| Host works but container fails | Device/runtime/library exposure | Container device list, runtime hooks, library paths, group IDs. |

## Troubleshooting Flow

1. Identify the exact GPU and PCI address with `lspci -nnk`.
2. Confirm the intended kernel module is loaded and bound.
3. Check Secure Boot, DKMS status, kernel headers, and package versions.
4. Read kernel logs for firmware, reset, Xid, ring, or BAR/IOMMU messages.
5. Confirm device nodes and user permissions.
6. Confirm userspace libraries match the driver branch and workload runtime.
7. For compute, validate vendor tools before testing frameworks.
8. For containers, compare host success with container device and library visibility.
9. Use vendor support matrices before upgrading kernels, ROCm, CUDA, or driver branches.
10. Preserve logs before rebooting because GPU reset failures often lose the most useful evidence.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is a Linux GPU driver not just one component?" answer="A working GPU stack includes PCIe/platform state, kernel modules, firmware, device nodes, userspace graphics or compute libraries, and sometimes container runtime hooks." %}
  {% include study-card.html question="What is the difference between /dev/dri/card* and /dev/dri/renderD*?" answer="Primary DRM nodes are often used by display and management paths, while render nodes allow unprivileged graphics or compute userspace to submit work." %}
  {% include study-card.html question="What does amdgpu provide?" answer="It is the upstream Linux DRM kernel driver for AMD GCN, RDNA, and CDNA GPUs." %}
  {% include study-card.html question="Why can AMD graphics work while ROCm fails?" answer="Mesa graphics support and ROCm compute support have different userspace stacks and support matrices." %}
  {% include study-card.html question="Why should NVIDIA automation use UUID or PCI bus ID?" answer="Natural GPU index ordering is not guaranteed to stay consistent across reboots." %}
  {% include study-card.html question="Why is nvidia-smi text output a weak automation API?" answer="NVIDIA documents NVML as the more stable API for tools that must work across driver releases." %}
</div>

## References

- [Linux kernel AMDGPU driver documentation](https://docs.kernel.org/gpu/amdgpu/index.html)
- [Linux kernel DRM client usage stats](https://docs.kernel.org/gpu/drm-usage-stats.html)
- [Mesa RADV driver documentation](https://docs.mesa3d.org/drivers/radv.html)
- [Mesa platform and driver documentation](https://docs.mesa3d.org/systems.html)
- [ROCm Linux installation documentation](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/index.html)
- [ROCm Linux system requirements](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/reference/system-requirements.html)
- [NVIDIA System Management Interface](https://docs.nvidia.com/deploy/nvidia-smi/index.html)
- [NVIDIA Xid errors](https://docs.nvidia.com/deploy/xid-errors/index.html)
- [NVIDIA driver persistence](https://docs.nvidia.com/deploy/driver-persistence/index.html)
- [NVIDIA Ubuntu driver installation guide](https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/ubuntu.html)
- [Ubuntu NVIDIA drivers installation](https://ubuntu.com/server/docs/how-to/graphics/install-nvidia-drivers/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html)
