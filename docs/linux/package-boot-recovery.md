---
title: Linux Package and Boot Recovery
layout: page
permalink: /docs/linux/package-boot-recovery/
summary: "Debian and Ubuntu recovery runbooks for broken packages, bad kernels, initramfs failures, GRUB rescue, emergency mode, and rollback."
tags:
  - linux
  - ubuntu
  - recovery
  - boot
  - troubleshooting
---

# Linux Package and Boot Recovery

Package and boot failures are high-pressure because the normal management path may be broken. Recovery work needs conservative sequencing: preserve evidence, identify the last change, boot a known-good path, restore package consistency, and only then clean up.

Examples here assume Debian-family systems with Ubuntu Server as the default operational target.

## First Checks

```bash
cat /etc/os-release
uname -a
systemctl --failed
journalctl -xb
dpkg --audit
apt-mark showhold
```

When the host cannot boot normally, collect the same facts from emergency mode, rescue media, serial console, or a mounted root filesystem.

## Broken Packages

Package transactions can fail because maintainer scripts fail, dependencies conflict, disk fills, dpkg locks remain, or repositories changed.

Recovery sequence:

```bash
sudo dpkg --audit
sudo apt -f install
sudo dpkg --configure -a
sudo apt update
sudo apt install --reinstall <package>
```

Check logs:

```bash
less /var/log/apt/history.log
less /var/log/apt/term.log
less /var/log/dpkg.log
```

Do not remove packages blindly. A forced remove of core packages can turn a package issue into a boot issue.

## Bad Kernel or Initramfs

Kernel updates can fail because the new kernel, module, DKMS build, firmware, storage driver, root UUID, or initramfs is wrong.

Useful commands from a working boot or chroot:

```bash
ls -lh /boot
dpkg -l 'linux-image*' 'linux-modules*'
lsinitramfs /boot/initrd.img-$(uname -r) | head
sudo update-initramfs -u -k all
sudo update-grub
```

If the latest kernel fails, boot the previous kernel from GRUB advanced options, then inspect `/var/log/apt/history.log`, DKMS logs, and kernel logs.

## GRUB Rescue and Emergency Mode

Common entry points:

| State | Meaning |
| --- | --- |
| GRUB menu | Bootloader works; choose older kernel or edit kernel command line. |
| GRUB rescue | Bootloader cannot find modules, config, or root path. |
| initramfs shell | Kernel booted but cannot mount real root or find required device. |
| emergency mode | systemd booted far enough to isolate into repair target. |

Useful emergency commands:

```bash
mount -o remount,rw /
findmnt /
blkid
lsblk -f
journalctl -xb
systemctl default
```

For filesystem or `/etc/fstab` problems, `findmnt --verify` and commenting a bad mount can restore boot while preserving a follow-up fix.

## Chroot Repair

From rescue media:

```bash
sudo mount /dev/<root-volume> /mnt
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt
dpkg --configure -a
update-initramfs -u -k all
update-grub
```

If `/boot` or EFI System Partition is separate, mount it before chrooting.

## Rollback Strategy

- Keep at least one known-good kernel installed.
- Snapshot before risky package, kernel, driver, or bootloader changes.
- Avoid unattended upgrades for kernel-sensitive fleets without staged rollout.
- Keep console access tested.
- Record package holds intentionally.
- Test restore and chroot procedures before incidents.

## Runbook

1. Preserve console output and package logs.
2. Identify last package, kernel, driver, or bootloader change.
3. Boot previous kernel or rescue mode if possible.
4. Repair package state with `dpkg --audit`, `apt -f install`, and `dpkg --configure -a`.
5. Rebuild initramfs and GRUB only after confirming `/boot`, root UUIDs, and drivers.
6. Reboot once into the intended kernel and verify services, mounts, and networking.
7. Add a postmortem note with rollback and prevention changes.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why keep an older kernel installed?" answer="It provides a known-good boot path when a new kernel, module, firmware, or initramfs fails." %}
  {% include study-card.html question="What does dpkg --configure -a do?" answer="It resumes configuration for unpacked packages whose maintainer scripts have not completed." %}
  {% include study-card.html question="Why mount /boot before chroot repair?" answer="Kernel, initramfs, and bootloader updates must write to the actual boot filesystem." %}
  {% include study-card.html question="Why is console access important for boot recovery?" answer="Network and SSH may be unavailable before the system reaches normal multi-user boot." %}
</div>

## References

- [Debian package management reference](https://www.debian.org/doc/manuals/debian-reference/ch02.en.html)
- [Ubuntu recovery mode documentation](https://help.ubuntu.com/community/RecoveryMode)
- [update-initramfs(8)](https://manpages.ubuntu.com/manpages/latest/en/man8/update-initramfs.8.html)
- [GRUB manual](https://www.gnu.org/software/grub/manual/grub/grub.html)
