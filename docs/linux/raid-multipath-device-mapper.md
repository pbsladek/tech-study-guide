---
title: RAID, Multipath, and Device Mapper
layout: page
permalink: /docs/linux/raid-multipath-device-mapper/
summary: "Linux md RAID, device mapper, dm-crypt/LUKS, multipath, NVMe multipath, WWIDs, path failover, and layered storage troubleshooting."
tags:
  - linux
  - storage
  - raid
  - device-mapper
---

# RAID, Multipath, and Device Mapper

Production Linux storage is often layered. A filesystem may sit on LVM, which sits on dm-crypt, which sits on multipath, which represents several paths to a storage array. Operators need to understand the layers before changing any one of them.

## Command Examples

```bash
cat /proc/mdstat
mdadm --detail --scan
dmsetup ls --tree
multipath -ll
cryptsetup status <name>
lsblk -o NAME,TYPE,FSTYPE,SIZE,MOUNTPOINTS
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `cat /proc/mdstat` | `md0 : active raid1 ... [UU] or recovery progress.` | Shows RAID health and rebuild state. |
| `mdadm --detail --scan` | `Array level, state, active devices, failed devices, and UUID.` | Shows md RAID identity and degradation. |
| `dmsetup ls --tree` | `Device-mapper tree with crypt, LVM, or multipath layers.` | Shows storage mapping layers between filesystem and disk. |

## md RAID

`mdadm` manages Linux software RAID. Common levels include RAID1 mirrors, RAID10, RAID5, and RAID6. RAID improves availability or aggregate capacity, but it is not a backup.

For RAID level behavior, parity write penalties, PostgreSQL and Elasticsearch examples, degraded-array recovery, and LVM native RAID, see [Storage Drives, RAID, and Database Performance](../storage-drives-raid-database-performance/).

Operational rules:

- monitor degraded arrays,
- know rebuild state before rebooting,
- replace failed members deliberately,
- avoid simultaneous risky maintenance on redundant members,
- keep mdadm configuration and initramfs in sync for boot arrays.

## Device Mapper

Device mapper is the Linux kernel framework for mapping block devices into virtual block devices. LVM, dm-crypt, and dm-multipath all use this pattern.

`dmsetup ls --tree` is useful because it shows the stack from top-level mapped devices down to physical devices. This prevents mistakes such as running filesystem repair on a lower encrypted or multipath component instead of the intended logical device.

## dm-crypt and LUKS

dm-crypt provides block-level encryption. LUKS is the common metadata format managed by `cryptsetup`. A LUKS header is critical metadata. If it is damaged and there is no header backup, encrypted data may be unrecoverable even if the raw disk is intact.

Operational practices:

- back up LUKS headers for important volumes,
- test passphrase or key rotation procedures,
- document `crypttab` and boot unlock behavior,
- be careful with discard/TRIM on encrypted devices,
- protect key material separately from data backups.

## Multipath

Multipath aggregates multiple I/O paths to the same storage volume into one device. This is common with SAN storage and some NVMe fabrics. Multipath protects against path failure, not volume failure.

Key ideas:

- identify volumes by WWID or namespace identity,
- do not mount individual path devices,
- configure LVM to use the multipath device rather than the component paths,
- monitor failed paths and path group state,
- understand storage-array vendor recommendations.

## Troubleshooting Flow

1. Draw the stack from filesystem to physical paths with `lsblk` and `dmsetup`.
2. Check md RAID state in `/proc/mdstat`.
3. Check multipath maps and failed paths.
4. Check cryptsetup status and LUKS header health.
5. Check LVM only after lower mappings are stable.
6. Check kernel logs for path resets, SCSI errors, NVMe errors, or device-mapper messages.
7. Repair the highest appropriate layer after lower layers are healthy.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is RAID not a backup?" answer="RAID can survive some device failures, but it does not protect against deletion, corruption, ransomware, or many operator mistakes." %}
  {% include study-card.html question="Why back up a LUKS header?" answer="If the LUKS header is lost or damaged, encrypted data may be unrecoverable even if disk blocks remain." %}
  {% include study-card.html question="Why avoid mounting individual multipath component paths?" answer="They are separate paths to the same storage; mounting a path bypasses failover and risks corruption." %}
</div>

## References

- [Device Mapper kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/device-mapper/index.html)
- [Ubuntu multipath introduction](https://ubuntu.com/server/docs/explanation/intro-to/multipath/index.html)
- [Linux NVMe multipath](https://www.kernel.org/doc/html/latest/admin-guide/nvme-multipath.html)
- [mdadm(8)](https://man7.org/linux/man-pages/man8/mdadm.8.html)
- [cryptsetup FAQ](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FrequentlyAskedQuestions)
