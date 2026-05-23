---
title: Linux LVM
layout: page
permalink: /docs/linux/lvm/
summary: "Logical Volume Manager fundamentals, advanced operations, resizing, thin provisioning, snapshots, migration, and troubleshooting."
tags:
  - linux
  - storage
  - lvm
  - troubleshooting
---

# Linux LVM

Logical Volume Manager adds a mapping layer between disks and filesystems. Instead of binding a filesystem directly to a partition, LVM lets you combine block devices into volume groups and carve logical volumes out of that shared space.

## Core Model

| Layer | Meaning | Common Commands |
| --- | --- | --- |
| Physical Volume (PV) | A disk, partition, multipath device, or other block device initialized for LVM. | `pvcreate`, `pvs`, `pvdisplay`, `pvscan` |
| Volume Group (VG) | A storage pool made from one or more PVs. | `vgcreate`, `vgs`, `vgextend`, `vgreduce`, `vgcfgbackup` |
| Logical Volume (LV) | A virtual block device allocated from a VG. Filesystems, swap, databases, and VMs use this layer. | `lvcreate`, `lvs`, `lvextend`, `lvreduce`, `lvremove` |
| Physical Extent (PE) | Allocation unit inside a VG. | visible through `pvs -o+pv_used,pv_free` |
| Logical Extent (LE) | LV-side allocation unit mapped to physical extents. | visible through `lvs -a -o+devices` |

The usual build path is `pvcreate` -> `vgcreate` or `vgextend` -> `lvcreate` -> filesystem creation -> mount.

## Basic Build

```bash
lsblk
pvcreate /dev/sdb
vgcreate vg_data /dev/sdb
lvcreate -n lv_apps -L 100G vg_data
mkfs.xfs /dev/vg_data/lv_apps
mkdir -p /srv/apps
mount /dev/vg_data/lv_apps /srv/apps
```

For persistent mounts, prefer stable device names such as `/dev/mapper/vg_data-lv_apps`, filesystem UUIDs, or labels in `/etc/fstab`.

## Growing Storage

Growing is the safest routine operation because filesystems generally support online expansion.

```bash
vgs
lvs
lvextend -r -L +50G /dev/vg_data/lv_apps
df -h /srv/apps
```

`-r` asks LVM to resize the filesystem as part of the LV resize. Without `-r`, grow the filesystem separately with the filesystem-specific tool, such as `xfs_growfs` for XFS or `resize2fs` for ext4.

## Shrinking Storage

Shrinking is riskier because the filesystem and block device must shrink in the correct order. XFS cannot be shrunk. ext4 can be shrunk offline when checked first.

```bash
umount /srv/apps
e2fsck -f /dev/vg_data/lv_apps
resize2fs /dev/vg_data/lv_apps 80G
lvreduce -L 80G /dev/vg_data/lv_apps
mount /srv/apps
```

Use `lvreduce --resizefs` only when you have a verified backup and understand the filesystem support. A bad shrink can destroy data.

## Moving Data Between Disks

`pvmove` migrates allocated extents away from one PV to another PV in the same VG. This is useful before replacing a disk.

```bash
pvs -o+pv_used,pv_free
vgextend vg_data /dev/sdc
pvmove /dev/sdb /dev/sdc
vgreduce vg_data /dev/sdb
pvremove /dev/sdb
```

For production storage, verify redundancy, backups, and IO health first. `pvmove` creates extra IO and can expose weak disks.

## LVM and RAID

LVM can either consume a RAID device or provide RAID itself.

The common server pattern is LVM on top of md RAID: disks or partitions form `/dev/md*`, the md device becomes an LVM physical volume, and logical volumes are created from that redundant pool. In that layout, md owns RAID health and LVM owns flexible allocation.

LVM can also create native RAID logical volumes with segment types such as `raid0`, `raid1`, `raid5`, `raid6`, and `raid10`. Those LVs use device mapper for the visible block device and Linux md logic for data placement. Use `lvs -a` because native LVM RAID creates hidden `_rimage_` and `_rmeta_` sub-LVs for data and RAID metadata.

```bash
lvs -a -o lv_name,segtype,attr,devices,lv_health_status,sync_percent
lvconvert --type raid10 /dev/vg_data/lv_db
lvchange --syncaction check /dev/vg_data/lv_db
vgcfgbackup vg_data
```

Do not treat RAID as a replacement for LVM metadata backups or data backups. If an LV reports missing PVs, degraded RAID health, or metadata damage, stabilize the lower storage layer before resizing, shrinking, moving extents, or repairing filesystems. For RAID behavior, database examples, and failure recovery details, see [Storage Drives, RAID, and Database Performance](../storage-drives-raid-database-performance/).

## Snapshots

Classic LVM snapshots use copy-on-write. They are useful for short-lived backup consistency points, not long-term version history.

```bash
lvcreate -s -n lv_apps_snap -L 20G /dev/vg_data/lv_apps
mount -o ro /dev/vg_data/lv_apps_snap /mnt/snapshot
umount /mnt/snapshot
lvremove /dev/vg_data/lv_apps_snap
```

If the snapshot fills, it becomes invalid. Monitor snapshot data usage with `lvs`.

## Thin Provisioning

Thin pools allocate blocks on demand. They are useful for VM images, container hosts, and dense development environments, but they create an operational obligation: monitor both data and metadata usage.

```bash
lvcreate --type thin-pool -n thinpool -L 500G vg_data
lvcreate --type thin -V 100G -n vm01 vg_data/thinpool
lvs -a -o+seg_monitor,data_percent,metadata_percent
lvextend -L +100G vg_data/thinpool
lvextend --poolmetadatasize +2G vg_data/thinpool
```

Thin pool exhaustion can pause or fail writes. Alert on `data_percent` and `metadata_percent` before they become urgent.

## Metadata Backups

VG metadata describes the mapping between PVs, VGs, and LVs. LVM normally writes backups under `/etc/lvm/backup` and archives under `/etc/lvm/archive`.

```bash
vgcfgbackup vg_data
ls -l /etc/lvm/backup /etc/lvm/archive
vgcfgrestore --list vg_data
```

Keep metadata backups with system backups. Metadata is not a substitute for data backup, but it can be the difference between recovering mappings and rebuilding from scratch.

## Troubleshooting Runbook

1. Confirm the kernel can see the device: `lsblk`, `dmesg -T`, `udevadm settle`.
2. Confirm LVM sees PVs: `pvs`, `pvscan`, `lvmdevices --list`.
3. Confirm VGs are active: `vgs`, `vgchange -ay`.
4. Confirm LVs and mappings: `lvs -a -o+devices`, `dmsetup ls --tree`.
5. Check filesystems after the block layer is stable.
6. If metadata is damaged, stop writes, collect `pvck`, backup/archive files, and plan `vgcfgrestore`.
7. For missing disks, decide whether data redundancy exists before forcing activation.

```bash
lsblk -f
pvs -o+pv_uuid,dev_size,pv_used,pv_free
vgs -o+vg_uuid,vg_size,vg_free,vg_missing_pv_count
lvs -a -o+devices,segtype,lv_health_status,data_percent,metadata_percent
dmsetup ls --tree
journalctl -k -g 'lvm|device-mapper|dm-|blk|I/O error'
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a physical volume represent in LVM?" answer="A block device or partition initialized with LVM metadata so it can be added to a volume group." %}
  {% include study-card.html question="What is the role of a volume group?" answer="It pools one or more physical volumes and provides extents for logical volumes." %}
  {% include study-card.html question="Why is shrinking an LV riskier than growing one?" answer="The filesystem and block device must shrink in the correct order, and some filesystems such as XFS do not support shrink." %}
  {% include study-card.html question="What does pvmove do?" answer="It migrates allocated extents from one physical volume to another physical volume in the same volume group." %}
  {% include study-card.html question="How can LVM interact with RAID?" answer="LVM can sit on top of md RAID, or it can create native RAID logical volumes with segment types such as raid1, raid5, raid6, and raid10." %}
  {% include study-card.html question="What must be monitored in an LVM thin pool?" answer="Both data usage and metadata usage, because exhausting either can break writes." %}
</div>

## References

- [pvcreate(8) Linux manual page](https://man7.org/linux/man-pages/man8/pvcreate.8.html)
- [vgcreate(8) Linux manual page](https://man7.org/linux/man-pages/man8/vgcreate.8.html)
- [lvmthin(7) Linux manual page](https://man7.org/linux/man-pages/man7/lvmthin.7.html)
- [lvmraid(7) Linux manual page](https://man7.org/linux/man-pages/man7/lvmraid.7.html)
- [vgcfgbackup(8) Linux manual page](https://man7.org/linux/man-pages/man8/vgcfgbackup.8.html)
- [Red Hat LVM volume group administration](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_logical_volumes/managing-lvm-volume-groups_configuring-and-managing-logical-volumes)
