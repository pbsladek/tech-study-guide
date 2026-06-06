---
title: ext4, XFS, and Filesystem Repair
layout: page
permalink: /docs/linux/ext4-xfs-repair/
summary: "ext4 and XFS operations, mkfs, fsck, xfs_repair, online growth, inode usage, journals, quotas, discard, and safe repair workflows."
tags:
  - linux
  - storage
  - filesystems
  - troubleshooting
---

# ext4, XFS, and Filesystem Repair

ext4 and XFS are common production Linux filesystems. Operators need to know how they grow, how they fail, how repair tools differ, and when to stop writing before turning a recoverable incident into data loss.

## Command Examples

```bash
df -hT
df -i
lsblk -f
sudo xfs_info /mountpoint
sudo tune2fs -l /dev/sdX1 | head
journalctl -k -g 'EXT4|XFS|I/O error|readonly'
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `df -hT` | `Device names, filesystems, mountpoints, latency, errors, or health fields.` | Connects storage symptoms to device and filesystem evidence. |
| `df -i` | `Device names, filesystems, mountpoints, latency, errors, or health fields.` | Connects storage symptoms to device and filesystem evidence. |
| `lsblk -f` | `Device names, filesystems, mountpoints, latency, errors, or health fields.` | Connects storage symptoms to device and filesystem evidence. |

## ext4 and XFS Differences

| Area | ext4 | XFS |
| --- | --- | --- |
| Growth | Online growth supported. | Online growth supported with `xfs_growfs`. |
| Shrink | Offline shrink supported with care. | In-place shrink is not supported. |
| Repair | `e2fsck`, normally offline. | `xfs_repair`, normally offline. |
| Metadata | Journaling filesystem. | Journaling filesystem with allocation groups. |
| Common use | General-purpose root and data filesystems. | Large filesystems, large files, parallel allocation, enterprise defaults. |

Do not assume filesystem tools are interchangeable. The filesystem type determines the correct grow, repair, quota, and metadata tools.

## Inodes, Space, and Quotas

`df -h` shows bytes. `df -i` shows inode availability. A filesystem can have free space but no free inodes. Quotas can also reject writes even when `df` looks healthy.

Common symptoms:

- application cannot create files,
- package installation fails,
- logs cannot rotate,
- temporary directory fills with many tiny files,
- user or project quota blocks writes.

## Journals and Durability

Journaling improves metadata recovery after crashes, but it is not the same as application-level durability. Databases and critical applications still need correct `fsync` behavior. Write caches, barriers, storage controller settings, and virtual disk behavior can change durability guarantees.

## Repair Rules

Repair is a data-risk operation:

- stop writes before repair,
- capture logs and device health first,
- know whether the underlying block device is stable,
- use the filesystem-specific tool,
- have a backup before destructive repair,
- do not run repair against the wrong layer.

Run filesystem repair after the block layer is stable. If the disk is failing, repair may accelerate data loss.

### What Not To Do During Repair

| Anti-Pattern | Why It Is Dangerous | Better Move |
| --- | --- | --- |
| Run `fsck` or `xfs_repair` on a mounted writable filesystem | Repair tools can race live writes and make damage worse. | Stop writers, unmount, or boot rescue media. |
| Repair the filesystem before checking storage health | A failing disk, path, RAID set, or controller can corrupt repaired metadata again. | Capture SMART/NVMe health, kernel logs, RAID/multipath state first. |
| Run repair on `/dev/sdb` without checking holders | The device may be a PV, RAID member, encrypted backing device, or wrong disk. | Use `lsblk`, `findmnt`, `dmsetup`, `mdadm`, and `/dev/disk/by-id`. |
| Use `xfs_repair -L` as a first step | Log zeroing can discard metadata updates and lose recent operations. | Mount normally or replay log if possible; use `-L` only with explicit risk acceptance. |
| Clone a corrupt disk by copying files | File-level copy can skip unreadable metadata and hide damage. | Image the block device with recovery-aware tooling when data recovery matters. |
| Reboot repeatedly to "see if it comes back" | Repeated journal replay attempts and writes can reduce recovery options. | Preserve evidence, stop writes, and decide recovery path once. |
| Repair without a restore plan | Repair success does not prove application consistency. | Verify backups and application-level checks after filesystem recovery. |

## TRIM and Discard

SSDs and thin-provisioned storage may benefit from discard/TRIM. Operators commonly use scheduled `fstrim` instead of continuous `discard` mount options to avoid unexpected latency. Confirm whether the underlying storage supports discard with `lsblk -D`.

## Troubleshooting Flow

1. Identify filesystem type and mount options.
2. Check bytes, inodes, quotas, and read-only state.
3. Check kernel logs for filesystem and block I/O errors.
4. Check underlying device health before repair.
5. For ext4, use `e2fsck` offline when required.
6. For XFS, use `xfs_repair` offline when required and `xfs_growfs` for online growth.
7. Validate backups before high-risk repair.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why can writes fail when df -h shows free space?" answer="The filesystem may be out of inodes, blocked by quota, mounted read-only, or failing underneath." %}
  {% include study-card.html question="Can XFS be shrunk in place?" answer="No. XFS supports online growth but not in-place shrink." %}
  {% include study-card.html question="Why check block health before filesystem repair?" answer="Repair on unstable storage can worsen corruption or destroy remaining recoverable data." %}
</div>

## References

- [ext4 general information](https://www.kernel.org/doc/html/latest/admin-guide/ext4.html)
- [XFS filesystem documentation](https://www.kernel.org/doc/html/latest/admin-guide/xfs.html)
- [e2fsck(8)](https://man7.org/linux/man-pages/man8/e2fsck.8.html)
- [xfs_repair(8)](https://man7.org/linux/man-pages/man8/xfs_repair.8.html)
- [fstrim(8)](https://man7.org/linux/man-pages/man8/fstrim.8.html)
