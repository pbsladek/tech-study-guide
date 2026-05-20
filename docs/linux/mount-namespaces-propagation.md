---
title: Linux Mount Namespaces and Propagation
layout: page
permalink: /docs/linux/mount-namespaces-propagation/
summary: "Mount namespaces, bind mounts, shared subtree propagation, chroot, pivot_root, overlay mounts, tmpfs, container mount debugging, and /proc mount views."
tags:
  - linux
  - mounts
  - namespaces
  - containers
---

# Linux Mount Namespaces and Propagation

Mounts are per-namespace state. Two processes on the same host can see different mount trees, different bind mounts, different root filesystems, and different propagation behavior. This is fundamental for containers, systemd services, chroots, initramfs, and incident debugging.

## First Checks

```bash
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS,PROPAGATION
readlink /proc/<pid>/ns/mnt
cat /proc/<pid>/mountinfo
lsns -t mnt
nsenter --target <pid> --mount -- findmnt
```

## Mount Namespaces

A mount namespace isolates the list of mount points seen by a process. Creating, removing, or moving mounts in one namespace does not necessarily affect another namespace.

Operational places this appears:

- containers and container runtimes,
- systemd units with mount namespace sandboxing,
- rescue shells and initramfs,
- chroot and build environments,
- services using `PrivateTmp=`, `ProtectSystem=`, or bind mounts,
- backup agents that run outside an application's namespace.

`/proc/<pid>/mountinfo` is the most precise view of what a specific process sees.

## Bind Mounts

A bind mount exposes an existing path at another path. Bind mounts are not copies. They are another view onto the same underlying object.

Bind mount pitfalls:

- the source path was wrong at container start,
- the target path hides existing files underneath it,
- recursive bind behavior differs from a non-recursive bind,
- readonly bind mounts may still depend on lower-layer writeability,
- propagation settings determine whether nested mount events cross boundaries.

## Propagation

Mount propagation controls whether mount and unmount events flow between related mount trees.

| Mode | Meaning |
| --- | --- |
| `shared` | Mount events propagate to peer groups. |
| `slave` | Receives events from a master but does not propagate back. |
| `private` | Does not propagate mount events. |
| `unbindable` | Cannot be bind-mounted. |

Container storage bugs often reduce to propagation: the host mounts a volume after a container starts, but the container never sees it, or a mount made inside one namespace unexpectedly appears elsewhere.

## Root Changes

`chroot` changes pathname resolution root for a process, but it is not a complete container boundary. `pivot_root` and mount namespaces are part of stronger root filesystem isolation used by container runtimes.

## Overlay and tmpfs

Overlay filesystems and tmpfs are common runtime mounts. Overlay can make a path look writable while changes land in an upper layer. tmpfs consumes memory-backed storage and can contribute to memory pressure or cgroup limits.

## Troubleshooting Flow

1. Identify the affected process PID.
2. Compare host `findmnt` with `nsenter --mount` into that process.
3. Read `/proc/<pid>/mountinfo`.
4. Check bind mount source, target, readonly state, and recursive behavior.
5. Check propagation mode with `findmnt`.
6. Check systemd unit sandboxing and container runtime mount specs.
7. Remember that changing the host mount tree may not update existing namespaces.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why inspect /proc/PID/mountinfo?" answer="It shows the mount tree visible to that specific process, including namespace-specific mounts." %}
  {% include study-card.html question="What does private mount propagation mean?" answer="Mount and unmount events do not propagate to or from peer mount trees." %}
  {% include study-card.html question="Why can a bind mount hide files?" answer="The mounted source is placed over the target path, hiding existing target contents until it is unmounted." %}
</div>

## References

- [mount_namespaces(7)](https://man7.org/linux/man-pages/man7/mount_namespaces.7.html)
- [namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)
- [proc_pid_mountinfo(5)](https://man7.org/linux/man-pages/man5/proc_pid_mountinfo.5.html)
- [nsenter(1)](https://man7.org/linux/man-pages/man1/nsenter.1.html)
- [shared subtree kernel documentation](https://www.kernel.org/doc/Documentation/filesystems/sharedsubtree.txt)
