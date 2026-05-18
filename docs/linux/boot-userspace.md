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

## Kernel Command Line

The command line controls early boot behavior: root device, console, log level, crash kernel, cgroup mode, module behavior, and distribution-specific options. A wrong root UUID or missing storage driver often shows up as a root mount failure.

## initramfs

initramfs is early userspace bundled for boot. It may include storage, filesystem, LVM, RAID, encryption, network boot, and recovery logic. If the kernel cannot find the real root device, initramfs contents and command-line root settings are first suspects.

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
  {% include study-card.html question="What does initramfs provide?" answer="Early userspace needed to find, unlock, assemble, and mount the real root filesystem." %}
  {% include study-card.html question="Why inspect /proc/cmdline?" answer="It shows the actual kernel parameters used for this boot." %}
  {% include study-card.html question="What is PID 1 responsible for after boot handoff?" answer="It starts and supervises userspace services, targets, and dependencies." %}
</div>

## References

- [Linux kernel initramfs documentation](https://docs.kernel.org/filesystems/ramfs-rootfs-initramfs.html)
- [Linux kernel initrd documentation](https://www.kernel.org/doc/html/latest/admin-guide/initrd.html)
- [systemd.special](https://www.freedesktop.org/software/systemd/man/latest/systemd.special.html)
