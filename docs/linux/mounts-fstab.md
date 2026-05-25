---
title: Linux Mounts and fstab
layout: page
permalink: /docs/linux/mounts-fstab/
summary: "Linux mounts, findmnt, /etc/fstab, UUIDs, systemd mount units, automounts, bind mounts, mount options, and boot-safe storage configuration."
tags:
  - linux
  - storage
  - filesystems
  - systemd
---

# Linux Mounts and fstab

Mounts connect filesystems to paths. Persistent mount configuration is simple until a boot hangs because a disk is missing, a UUID changed, a network filesystem is unavailable, or a container sees a different mount namespace than the host.

## First Checks

```bash
findmnt
findmnt --verify
cat /etc/fstab
systemctl list-units --type=mount
mount -a -v
```

## Mount Model

A mounted filesystem has:

- a source device or pseudo-filesystem,
- a target path,
- a filesystem type,
- options,
- propagation and namespace behavior,
- a lifetime controlled manually, by `/etc/fstab`, or by systemd.

`findmnt` is usually better than parsing `mount` output because it shows the tree and can verify fstab entries.

## /etc/fstab

`/etc/fstab` describes filesystems to mount at boot or through `mount <path>`. Prefer stable identifiers such as UUID, LABEL, or `/dev/disk/by-id/` where practical.

Operational options to know:

| Option | Why it matters |
| --- | --- |
| `defaults` | Baseline option set, not a full security policy. |
| `noauto` | Do not mount automatically with `mount -a` or normal boot handling. |
| `nofail` | Boot continues if the device is missing. |
| `x-systemd.device-timeout=` | Controls how long systemd waits for the backing device. |
| `x-systemd.automount` | systemd creates an automount unit and mounts on first access. |
| `_netdev` | Marks a filesystem as network-dependent. |
| `ro` / `rw` | Read-only or read-write. |
| `noatime` / `relatime` | Access-time update behavior. |
| `nosuid`, `nodev`, `noexec` | Security-relevant restrictions for some mountpoints. |
| `fs_passno` field | Controls fsck ordering in traditional fstab semantics; root is usually `1`, other checked filesystems `2`, unchecked `0`. |

Always run `findmnt --verify` or `mount -a` after editing fstab while you still have a shell.

## systemd Mount Units

systemd-fstab-generator converts fstab entries into `.mount` units at boot and daemon reload. Mount unit names are derived from paths, such as `srv-data.mount` for `/srv/data`. Automount units can reduce boot coupling for slow or optional storage.

Mount ordering matters. A local required mount can hold boot in emergency mode if the device is missing. A network mount without `_netdev`, automounting, or correct network dependencies can race the network. Optional or slow storage should be designed deliberately with `nofail`, `noauto`, `x-systemd.automount`, device timeouts, and application-level readiness.

Use:

```bash
systemctl status srv-data.mount
systemctl cat srv-data.mount
journalctl -u srv-data.mount -b
```

### systemd Mount Dependency Examples

For a local disk that may appear slowly, bound boot delay explicitly:

```text
UUID=1111-2222 /srv/data xfs defaults,nofail,x-systemd.device-timeout=10s 0 2
```

For network storage, tell systemd it is network-dependent and consider automounting so boot does not block on first contact:

```text
server:/exports/reports /mnt/reports nfs4 rw,_netdev,nofail,x-systemd.automount,x-systemd.idle-timeout=5min 0 0
```

For an application that must start only after a mount is available, express the dependency on the service as well as in fstab:

```text
# /etc/systemd/system/myapp.service.d/mounts.conf
[Unit]
RequiresMountsFor=/srv/data
After=network-online.target
Wants=network-online.target
```

Useful dependency checks:

```text
systemd-analyze critical-chain srv-data.mount
systemctl show srv-data.mount -p After -p Requires -p Wants -p BindsTo
systemctl show myapp.service -p RequiresMountsFor -p After -p Wants
systemctl list-dependencies myapp.service
```

`After=` orders startup but does not require the other unit to exist or succeed. `Requires=` creates a hard requirement but does not order by itself. `RequiresMountsFor=` is the usual application-level way to say "this service needs these paths mounted before it starts."

## Bind Mounts and Namespaces

Bind mounts expose an existing path somewhere else. Containers commonly use bind mounts and separate mount namespaces, so a path can be mounted on the host but not inside a container, or visible in a container but backed by a different host path than expected.

## Troubleshooting Flow

1. Use `findmnt <path>` to identify the active source and options.
2. Verify `/etc/fstab` syntax and stable identifiers.
3. Check `systemctl status <path>.mount` for boot-time failures.
4. Check kernel and systemd logs.
5. Confirm the backing block device exists and is healthy.
6. For containers, inspect the mount namespace and container runtime mount config.
7. For network storage, confirm network ordering and remote availability.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why run findmnt --verify after editing fstab?" answer="It catches syntax and source/target problems before a reboot turns them into boot failures." %}
  {% include study-card.html question="What does systemd-fstab-generator do?" answer="It turns /etc/fstab entries into systemd mount and automount units at boot or daemon reload." %}
  {% include study-card.html question="What does nofail do in fstab?" answer="It lets boot continue when the configured filesystem is unavailable." %}
  {% include study-card.html question="Why can a mount look different inside a container?" answer="Containers often run in separate mount namespaces with bind mounts chosen by the runtime." %}
</div>

## References

- [fstab(5)](https://man7.org/linux/man-pages/man5/fstab.5.html)
- [mount(8)](https://man7.org/linux/man-pages/man8/mount.8.html)
- [findmnt(8)](https://man7.org/linux/man-pages/man8/findmnt.8.html)
- [systemd.mount](https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html)
- [systemd.automount](https://www.freedesktop.org/software/systemd/man/latest/systemd.automount.html)
