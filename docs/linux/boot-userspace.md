---
title: Linux Boot and Userspace
layout: page
permalink: /docs/linux/boot-userspace/
summary: "Firmware, bootloader, kernel command line, initramfs, root filesystem handoff, PID 1, services, and boot troubleshooting."
tags:
  - linux
  - boot
  - systemd
---

# Linux Boot and Userspace

Boot is the chain that turns powered-off hardware into running services. Understanding it connects firmware, storage, kernel drivers, filesystems, initramfs, PID 1, and service supervision.

For booting machines from the network and installing them automatically, see [Network Boot and Automated Provisioning](../network-boot-automated-provisioning/).

## Boot Checks

```bash
cat /proc/cmdline
journalctl -b
systemd-analyze time
systemd-analyze critical-chain
lsinitrd 2>/dev/null || lsinitramfs /boot/initrd.img-$(uname -r)
findmnt /
```

## Boot Chain

1. Firmware initializes hardware and chooses a boot device.
2. Bootloader loads the kernel and passes the kernel command line.
3. Kernel initializes CPU, memory, drivers, interrupts, and core subsystems.
4. initramfs supplies early userspace, storage drivers, unlock logic, and root discovery.
5. Kernel hands off to the real root filesystem.
6. PID 1 starts userspace services and targets.

## Bootloaders and Firmware

Boot starts before Linux is running. On modern x86 servers, UEFI firmware usually reads boot entries from NVRAM and loads an EFI executable from the EFI System Partition. Legacy BIOS systems instead load boot code from disk boot sectors. The Linux troubleshooting question is: did firmware find the bootloader, did the bootloader find the kernel and initramfs, and did the kernel receive the command line you expected?

Common bootloader shapes:

| Bootloader | Operational Notes |
| --- | --- |
| GRUB | Common on Debian and Ubuntu systems; can read many filesystems, build menus, and pass kernel/initrd options. |
| systemd-boot | UEFI boot manager that uses Boot Loader Specification entries on the ESP or XBOOTLDR partition. |
| Unified Kernel Image | EFI executable bundling kernel, initramfs, command line, and metadata for a specific boot entry. |

Files to recognize:

- EFI System Partition mounted at `/boot/efi` on many distributions.
- GRUB configuration generated under `/boot/grub/`.
- Boot Loader Specification entries under `loader/entries/`.
- Kernel images such as `/boot/vmlinuz-*`.
- initramfs images such as `/boot/initrd.img-*`.

Secure Boot adds another boundary. Firmware may refuse unsigned bootloaders or kernel images, and the kernel may refuse unsigned modules depending on platform policy.

## Kernel Command Line

The command line controls early boot behavior: root device, console, log level, crash kernel, cgroup mode, module behavior, and distribution-specific options. A wrong root UUID or missing storage driver often shows up as a root mount failure.

Important examples:

| Parameter | Use |
| --- | --- |
| `root=` | Identifies the real root filesystem or initramfs handoff target. |
| `rootwait` / `rootdelay=` | Wait for slow storage discovery before root mount. |
| `ro` / `rw` | Initial root mount mode. |
| `console=` | Selects kernel console output, critical for serial/BMC troubleshooting. |
| `init=` | Overrides the first userspace program after root handoff. |
| `module.parameter=value` | Supplies a parameter to a built-in or loadable kernel module. |

## initramfs

initramfs is early userspace bundled for boot. It may include storage, filesystem, LVM, RAID, encryption, network boot, and recovery logic. If the kernel cannot find the real root device, initramfs contents and command-line root settings are first suspects.

If a system boots only after manually loading a driver in an emergency shell, the fix is often to rebuild initramfs with the needed module, firmware, udev rule, encryption helper, or storage assembly tool.

## PID 1

After root handoff, PID 1 owns service orchestration. On systemd systems, targets express boot milestones and unit dependencies define what starts before or after what.

## Failure Modes

- bootloader cannot find kernel,
- kernel panic before initramfs,
- missing storage driver in initramfs,
- wrong `root=` kernel parameter,
- encrypted disk prompt unavailable,
- filesystem check or mount failure,
- PID 1 emergency mode,
- service dependency waits delaying boot.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does the bootloader pass to the Linux kernel?" answer="The kernel image, usually an initramfs, and the kernel command line." %}
  {% include study-card.html question="What is the EFI System Partition?" answer="A FAT-formatted partition where UEFI firmware and boot managers load EFI executables and boot entries." %}
  {% include study-card.html question="What does initramfs provide?" answer="Early userspace needed to find, unlock, assemble, and mount the real root filesystem." %}
  {% include study-card.html question="Why inspect /proc/cmdline?" answer="It shows the actual kernel parameters used for this boot." %}
  {% include study-card.html question="What is PID 1 responsible for after boot handoff?" answer="It starts and supervises userspace services, targets, and dependencies." %}
</div>

## References

- [Linux kernel initramfs documentation](https://docs.kernel.org/filesystems/ramfs-rootfs-initramfs.html)
- [Linux kernel initrd documentation](https://www.kernel.org/doc/html/latest/admin-guide/initrd.html)
- [Linux kernel command-line parameters](https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html)
- [systemd Boot Loader Specification](https://uapi-group.org/specifications/specs/boot_loader_specification/)
- [systemd.special](https://www.freedesktop.org/software/systemd/man/latest/systemd.special.html)
