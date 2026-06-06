---
title: Linux Backup and File Transfer
layout: page
permalink: /docs/linux/backup-transfer-rsync-scp-snapshots/
summary: "Linux backup and transfer notes covering rsync, scp, snapshot backups, consistency, restore testing, exclusions, permissions, and automation."
tags:
  - linux
  - backup
  - rsync
  - scp
  - storage
---

# Linux Backup and File Transfer

Backups are only useful when they can be restored. File transfer commands such as `rsync` and `scp` move bytes, but backup operations need consistency, retention, verification, access control, logging, and restore drills. Treat every backup path as a production data path.

## Command Examples

```bash
rsync --version
rsync -aHAXn --delete /srv/app/ backup:/backups/app/
scp -v file.txt user@host:/tmp/
ssh user@host 'hostname; df -h; umask'
findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /srv/app
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `rsync --version` | `rsync version, protocol version, capabilities, and checksum support.` | Confirms transfer tool behavior before backup design. |
| `YAML or text capture` | `Concrete IDs, states, counters, versions, rows, or error strings.` | Turns the example from a command list into evidence for the next debugging step. |
| `YAML or text capture` | `Concrete IDs, states, counters, versions, rows, or error strings.` | Turns the example from a command list into evidence for the next debugging step. |

These checks confirm tool versions, dry-run behavior, SSH connectivity, remote filesystem state, and the source mount you are about to copy.

## Backup Mental Model

| Concept | Meaning |
| --- | --- |
| Backup | Independent copy that can survive loss or corruption of the source. |
| Snapshot | Point-in-time view of a filesystem, volume, VM disk, or storage backend. |
| Archive | Backup retained for a time window, often compressed or moved off-host. |
| Replication | Copying changes elsewhere. Useful for availability, but it can copy corruption and deletion. |
| Restore test | Proof that data can be recovered and used by the application. |
| RPO | Maximum acceptable data loss window. |
| RTO | Maximum acceptable recovery time. |

Important rule: a successful copy is not the same as a backup. A backup must be isolated enough to survive operator error, ransomware, host loss, credential compromise, and bad application writes.

## rsync

`rsync` compares source and destination file metadata and transfers only needed file data. It is useful for local copies, SSH-based remote copies, mirror jobs, staged migrations, and backup rotations.

Common options:

| Option | Use |
| --- | --- |
| `-a` | Archive mode: recursive copy preserving common file metadata. |
| `-H` | Preserve hard links. Important for some package trees and snapshot-style backups. |
| `-A` | Preserve POSIX ACLs. |
| `-X` | Preserve extended attributes, including some security labels. |
| `--numeric-ids` | Preserve UID/GID numbers instead of mapping names across hosts. |
| `--delete` | Delete destination files that no longer exist at the source. Dangerous without dry run. |
| `--exclude` / `--exclude-from` | Skip paths such as caches, sockets, build output, and secrets. |
| `--partial` | Keep partially transferred files for retry. |
| `--info=progress2` | Show overall transfer progress. |
| `--link-dest` | Hard-link unchanged files from a previous backup tree. |

Trailing slash matters:

```bash
rsync -a /srv/app backup:/backups/
rsync -a /srv/app/ backup:/backups/app/
```

The first command copies the `app` directory into `/backups/`. The second copies the contents of `app` into `/backups/app/`. This distinction is one of the most common `rsync` mistakes.

Safe mirror workflow:

```bash
rsync -aHAXn --delete --numeric-ids /srv/app/ backup:/backups/app/
rsync -aHAX --delete --numeric-ids --log-file=/var/log/rsync-app.log /srv/app/ backup:/backups/app/
```

Use `-n` or `--dry-run` before `--delete`. Review deleted paths before running the real job. For production, log output and alert on nonzero exit status.

Snapshot-style `rsync` with hard links:

```bash
today=$(date +%F)
latest=/backups/app/latest
dest=/backups/app/$today
rsync -aHAX --numeric-ids --delete --link-dest="$latest" /srv/app/ "$dest/"
ln -sfn "$dest" "$latest"
```

This creates a new dated directory where unchanged files are hard links to the previous backup. It saves space, but it is still file-level backup. A file modified in place becomes a new copy. A file that changes during the run may be inconsistent unless the source is quiesced or snapshotted first.

`rsync` operational cautions:

- Do not run `--delete` against an empty or wrong source path.
- Use `--one-file-system` when you do not want to cross mount boundaries.
- Exclude pseudo-filesystems such as `/proc`, `/sys`, `/dev`, `/run`, and temporary caches.
- Preserve ACLs/xattrs when copying system data, containers, SELinux/AppArmor-labeled trees, or user home directories.
- Use `--numeric-ids` for system backups where UID/GID names may differ between hosts.
- Avoid backing up live databases with plain file-level `rsync` unless the database is stopped or the storage snapshot is application-consistent.

## scp

`scp` is for simple SSH-based file copies. Modern OpenSSH `scp` uses the SFTP protocol by default for transfers while keeping the familiar `scp` command-line interface. It is convenient for one-off copies, but it is not a backup system.

Common usage:

```bash
scp ./file.txt user@host:/tmp/
scp -r ./directory user@host:/srv/upload/
scp -P 2222 ./file.txt user@host:/tmp/
scp -i ~/.ssh/deploy_key ./release.tar.gz deploy@host:/srv/releases/
```

Use `scp` when:

- copying a small number of files,
- moving a release artifact,
- grabbing a log bundle,
- testing SSH reachability,
- transferring something manually during an incident.

Prefer `rsync` or `sftp` when:

- resuming large transfers matters,
- copying large directory trees repeatedly,
- needing include/exclude rules,
- preserving detailed metadata,
- wanting dry runs and deletion previews.

`scp` cautions:

- Quote remote paths that contain spaces or shell-sensitive characters.
- Avoid copying directly into privileged destinations; copy to a staging path and move with a controlled command.
- Verify file checksums for important artifacts.
- Use SSH host key checking; do not normalize `StrictHostKeyChecking=no` in automation.
- For automation, use a restricted key, least-privilege remote account, and server-side forced command if possible.

## Snapshot Backups

Snapshots provide a point-in-time view at a lower layer than normal file copying. They can make backups consistent enough to copy while applications continue running, but snapshot quality depends on the application and storage layer.

Common snapshot sources:

| Layer | Examples | Notes |
| --- | --- | --- |
| LVM | `lvcreate -s`, thin snapshots. | Local block-device view; snapshot space must be monitored. |
| Btrfs | `btrfs subvolume snapshot`. | Filesystem-native snapshots and send/receive workflows. |
| ZFS | `zfs snapshot`, `zfs send`. | Strong snapshot/send model where available. |
| Cloud volumes | EBS, Persistent Disk, managed disks. | Often crash-consistent unless coordinated with the application. |
| VM platform | Hypervisor or backup-agent snapshots. | Can include memory or quiescing depending on tooling. |
| Kubernetes CSI | VolumeSnapshot. | Requires snapshot controller, driver support, and app-level consistency. |

Snapshot consistency levels:

| Level | Meaning |
| --- | --- |
| Crash-consistent | Looks like the machine lost power at the snapshot moment. Usually OK for journaling filesystems, not always enough for applications. |
| Filesystem-consistent | Filesystem buffers are flushed/frozen so metadata is coherent. |
| Application-consistent | Application has flushed or paused writes so its own data format is recoverable. |

Typical LVM snapshot backup shape:

```bash
lvcreate -s -n app_snap -L 20G /dev/vg_data/app
mkdir -p /mnt/app_snap
mount -o ro /dev/vg_data/app_snap /mnt/app_snap
rsync -aHAX --numeric-ids /mnt/app_snap/ backup:/backups/app/
umount /mnt/app_snap
lvremove /dev/vg_data/app_snap
```

Application consistency matters:

- For PostgreSQL, use database-native backups, WAL archiving, or a correctly coordinated filesystem snapshot. Plain snapshots without WAL/backup mode planning can fail restore expectations.
- For SQLite, stop writers or use the SQLite backup API where possible.
- For file services, freeze writes or snapshot the backing filesystem.
- For VMs, know whether the hypervisor snapshot is crash-consistent or guest-quiesced.

Snapshot risks:

- LVM classic snapshots can fill and become invalid.
- Snapshots on the same disk are not off-host backups.
- A snapshot can preserve corrupted or deleted data if taken after the mistake.
- Long-lived snapshots can slow writes and complicate storage management.
- Restoring the wrong snapshot can roll back good data.

## Backup Automation

A simple backup script should be boring, explicit, and noisy on failure.

```bash
#!/bin/sh
set -eu

src=/srv/app/
dst=backup:/backups/app/
log=/var/log/backup-app.log

rsync -aHAX --numeric-ids --delete --one-file-system "$src" "$dst" >>"$log" 2>&1
```

Run backup jobs with:

- a dedicated service account,
- SSH keys scoped to the backup destination,
- restricted destination permissions,
- `flock` or another lock to prevent overlap,
- logs collected by the system logger or monitoring agent,
- alerts on failure and on missing successful runs,
- restore tests on a schedule.

## Restore Runbook

Backups are only proven by restore.

1. Identify the recovery target: file, directory, whole host, application dataset, or point in time.
2. Choose the backup generation or snapshot.
3. Restore to a staging path first when possible.
4. Preserve ownership, ACLs, xattrs, symlinks, and hard links when they matter.
5. Compare checksums or application-level validation.
6. Cut over by rename, mount, service restart, or application restore procedure.
7. Keep the broken source until the restored service is validated.
8. Record the RPO/RTO actually achieved.

Useful restore checks:

```bash
rsync -aHAXn backup:/backups/app/ /restore/app/
find /restore/app -xdev -type f -print0 | xargs -0 sha256sum > /tmp/restored.sha256
diff -ruN /expected/sample /restore/app/sample
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why use rsync --dry-run before --delete?" answer="It previews deletions so a wrong source path or exclude rule does not erase the destination." %}
  {% include study-card.html question="What does the trailing slash change in rsync?" answer="It changes whether rsync copies the directory itself or the directory contents." %}
  {% include study-card.html question="Why are snapshots not automatically backups?" answer="Snapshots may live in the same failure domain and can preserve corruption or deletion if taken after the mistake." %}
  {% include study-card.html question="When is scp a good fit?" answer="For simple one-off SSH file copies, small artifacts, or quick incident transfers." %}
  {% include study-card.html question="What proves a backup works?" answer="A restore test that validates the data or application can actually be used." %}
</div>

## References

- [rsync(1)](https://man7.org/linux/man-pages/man1/rsync.1.html)
- [scp(1)](https://man.openbsd.org/scp)
- [OpenSSH 9.0 release notes](https://www.openssh.com/releasenotes.html#9.0)
- [lvcreate(8)](https://man7.org/linux/man-pages/man8/lvcreate.8.html)
- [fsfreeze(8)](https://man7.org/linux/man-pages/man8/fsfreeze.8.html)
