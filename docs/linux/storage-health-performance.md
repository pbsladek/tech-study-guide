---
title: Linux Storage Health and Performance
layout: page
permalink: /docs/linux/storage-health-performance/
summary: "Linux storage observability, iostat, SMART, NVMe health, kernel I/O errors, discard, queue depth, latency, saturation, and failure response."
tags:
  - linux
  - storage
  - performance
  - troubleshooting
---

# Linux Storage Health and Performance

Storage incidents often start as latency before they become hard failures. Operators need to read device saturation, kernel errors, SMART/NVMe health, queue behavior, filesystem symptoms, and application latency together.

## Command Examples

```bash
iostat -xz 1
lsblk -D
smartctl -a /dev/sda
nvme smart-log /dev/nvme0
dmesg -T | grep -Ei 'I/O error|medium error|nvme|scsi|reset'
journalctl -k -p warning..alert
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `iostat -xz 1` | `Device names, filesystems, mountpoints, latency, errors, or health fields.` | Connects storage symptoms to device and filesystem evidence. |
| `lsblk -D` | `Device names, filesystems, mountpoints, latency, errors, or health fields.` | Connects storage symptoms to device and filesystem evidence. |
| `smartctl -a /dev/sda` | `Device names, filesystems, mountpoints, latency, errors, or health fields.` | Connects storage symptoms to device and filesystem evidence. |

## Latency, Utilization, and Saturation

High storage latency is not the same as high throughput. A device can be slow because it is saturated, retrying errors, waiting on firmware, throttled by the hypervisor, blocked behind a controller queue, or overloaded by sync writes.

Useful signals:

- await and service-time trends,
- read/write IOPS and throughput,
- queue depth,
- `%util` or equivalent saturation indicators,
- filesystem read-only remounts,
- application `fsync` latency,
- PSI I/O pressure,
- cgroup I/O throttling.

## SMART and NVMe Health

SMART and NVMe health data can expose media errors, wear, temperature, unsafe shutdowns, controller resets, and lifetime indicators. The exact fields vary by device and vendor, so treat them as signals, not a universal pass/fail oracle.

Operational rules:

- collect health data before and after incidents,
- alert on growing media errors or critical warnings,
- know how your cloud provider exposes disk health,
- replace suspect devices before redundancy is exhausted,
- correlate kernel errors with physical slot, serial, or by-id path.

### SMART and NVMe Interpretation Gallery

| Evidence | Why It Matters | Action |
| --- | --- | --- |
| SMART `Reallocated_Sector_Ct` or `Current_Pending_Sector` rising | Media is remapping or waiting to remap unreadable sectors. | Replace the disk before RAID or replicas are exhausted. |
| SMART `UDMA_CRC_Error_Count` rising | Often cable, backplane, controller, or signal integrity rather than platter/media failure. | Reseat or replace cable/backplane path and correlate with kernel link resets. |
| SMART `Power_On_Hours` high but no errors | Age alone is not a failure, but it changes risk and maintenance planning. | Watch trend data and replace by fleet policy. |
| SMART overall-health `PASSED` with kernel I/O errors | SMART summary is too coarse; the OS is already seeing failures. | Trust kernel errors and detailed attributes over the summary. |
| NVMe `critical_warning` nonzero | Controller reports a critical health condition such as spare, temperature, reliability, or read-only risk. | Treat as urgent and inspect detailed log. |
| NVMe `percentage_used` over 100 | Device has exceeded vendor endurance estimate; not always immediate failure. | Plan replacement and reduce write amplification. |
| NVMe media/data integrity errors increasing | Controller is reporting unrecovered data integrity issues. | Replace or evacuate; verify application and filesystem consistency. |
| NVMe unsafe shutdowns rising | Power loss or reset path may be unhealthy and can explain journal recovery. | Check power, firmware, host resets, and platform events. |

Useful captures:

```text
smartctl -a /dev/sdX
smartctl -x /dev/sdX
nvme smart-log /dev/nvme0
nvme error-log /dev/nvme0
journalctl -k -g 'I/O error|reset|timeout|nvme|scsi|blk_update_request'
```

## Kernel I/O Errors

Kernel logs are often the first place storage failure appears. Look for I/O errors, resets, timeouts, medium errors, filesystem aborts, ext4 or XFS warnings, NVMe controller resets, SCSI sense data, and read-only remounts.

Do not immediately run filesystem repair when kernel logs show device errors. Stabilize or replace the lower layer first.

## Discard and Thin Provisioning

`lsblk -D` shows discard capabilities. `fstrim` can return unused blocks to SSDs, thin LUNs, and virtual disks. Discard support depends on every layer: filesystem, dm-crypt, LVM, multipath, hypervisor, and storage backend.

## Failure Response

1. Stop unnecessary writes.
2. Capture `lsblk`, `dmesg`, `journalctl -k`, `iostat`, and health logs.
3. Identify the physical or virtual device by serial, by-id path, or cloud disk ID.
4. Check RAID, multipath, LVM, and filesystem state.
5. Decide whether redundancy is intact.
6. Replace or detach the failing layer before repair.
7. Verify backups and restore paths.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is high storage latency different from high throughput?" answer="Latency can come from retries, queueing, firmware stalls, sync writes, throttling, or errors even when throughput is low." %}
  {% include study-card.html question="Why collect serial or by-id paths during failures?" answer="They map kernel errors to the physical or virtual device that must be replaced or inspected." %}
  {% include study-card.html question="Why stabilize the block layer before fsck?" answer="Filesystem repair on failing storage can worsen corruption and destroy recoverable data." %}
</div>

## References

- [iostat(1)](https://man7.org/linux/man-pages/man1/iostat.1.html)
- [smartctl(8)](https://www.smartmontools.org/browser/trunk/smartmontools/smartctl.8.in)
- [nvme smart-log manual](https://manpages.debian.org/testing/nvme-cli/nvme-smart-log.1.en.html)
- [Linux block layer documentation](https://www.kernel.org/doc/html/latest/block/index.html)
- [Pressure Stall Information](https://www.kernel.org/doc/html/latest/accounting/psi.html)
