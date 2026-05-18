---
title: Linux Filesystems and IO
layout: page
permalink: /docs/linux/filesystems-io/
summary: "VFS, inodes, dentries, page cache, block devices, mounts, filesystem checks, IO schedulers, and storage troubleshooting."
tags:
  - linux
  - filesystems
  - storage
  - io
---

# Linux Filesystems and IO

Filesystems are where application abstractions meet storage reality. The full stack includes VFS objects, inodes, dentries, page cache, block devices, device mapper, filesystem journals, IO schedulers, and hardware queues.

## First Checks

```bash
findmnt
df -h
df -i
lsblk -f
iostat -xz 1
journalctl -k -g 'I/O error|EXT4|XFS|blk|nvme|scsi'
```

## VFS Model

The Virtual Filesystem layer gives Linux one interface over many filesystems. Applications call `open`, `read`, `write`, `fsync`, `rename`, and `stat`; VFS routes those operations to the mounted filesystem and underlying block or network storage.

Important objects:

- inode: metadata for a file object,
- dentry: directory-entry name lookup cache,
- superblock: mounted filesystem metadata,
- page cache: cached file data,
- file descriptor: process handle to an opened file.

## Page Cache and Durability

A successful `write()` often means data reached kernel memory, not durable storage. `fsync()` or equivalent database durability paths matter when power loss or kernel crash safety is required.

Dirty pages are eventually written back. Dirty writeback tuning, slow storage, and congested queues can create latency spikes far from the code that caused the writes.

## Mounts and Namespaces

Mounts define where filesystems appear. Containers may have different mount namespaces from the host, so a path can exist in one namespace but not another. Bind mounts and overlay filesystems are common in container runtimes.

## Failure Modes

- inode exhaustion with free bytes still available,
- file descriptor leak,
- deleted-but-open log files consuming disk,
- read-only remount after filesystem error,
- saturated block device queue,
- slow `fsync`,
- page cache hiding disk read cost during tests,
- mount namespace mismatch between host and container.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does VFS provide?" answer="A common kernel interface for file operations across many filesystem implementations." %}
  {% include study-card.html question="Why can df show free space while writes fail?" answer="The filesystem may be out of inodes, quotas, or writable mount state." %}
  {% include study-card.html question="Why does fsync matter?" answer="It asks the system to make file data or metadata durable beyond page cache." %}
</div>

## References

- [Linux kernel filesystem documentation](https://docs.kernel.org/filesystems/index.html)
- [proc(5)](https://man7.org/linux/man-pages/man5/proc.5.html)
- [open(2)](https://man7.org/linux/man-pages/man2/open.2.html)
- [fsync(2)](https://man7.org/linux/man-pages/man2/fsync.2.html)
