---
title: systemd
layout: page
permalink: /docs/linux/systemd/
summary: "systemd units, services, targets, dependencies, timers, journals, cgroups, resource controls, and troubleshooting."
tags:
  - linux
  - systemd
  - troubleshooting
---

# systemd

systemd is the service manager and init system on many Linux distributions. It starts the system, tracks services, models dependencies between units, collects logs through the journal, and uses cgroups to account for processes.

## Units

A unit is an ini-style file that describes something systemd manages.

| Unit Type | Purpose |
| --- | --- |
| `.service` | Long-running or one-shot process supervision. |
| `.socket` | Socket activation and listener ownership. |
| `.target` | A synchronization point that groups units. |
| `.timer` | Calendar or monotonic scheduling for another unit. |
| `.mount` / `.automount` | Filesystem mounts and on-demand mounts. |
| `.path` | File or directory change activation. |
| `.slice` / `.scope` | Cgroup organization and externally-created process groups. |

Unit files commonly live under `/usr/lib/systemd/system` for package-owned units and `/etc/systemd/system` for administrator overrides. Drop-ins under `name.service.d/*.conf` are the normal way to override vendor units without editing package files.

## Service Lifecycle

```bash
systemctl status nginx.service
systemctl start nginx.service
systemctl restart nginx.service
systemctl reload nginx.service
systemctl enable nginx.service
systemctl disable nginx.service
systemctl daemon-reload
```

`start` changes current state. `enable` changes boot-time dependency symlinks. Editing a unit or drop-in requires `systemctl daemon-reload` before systemd sees the new unit definition.

## Dependencies and Ordering

Dependencies and ordering are separate:

- `Requires=` and `Wants=` express requirement strength.
- `After=` and `Before=` express order.
- `PartOf=` propagates stop/restart behavior.
- `BindsTo=` is stronger coupling, often tied to device or mount lifetime.

Do not assume `After=network.target` means the network is fully usable. For network-dependent services, understand the distribution's network stack and whether `network-online.target` is appropriate.

## Drop-ins

```bash
systemctl edit nginx.service
systemctl cat nginx.service
systemd-analyze cat-config systemd/system nginx.service
```

Example override:

```ini
[Service]
Environment=APP_ENV=prod
Restart=on-failure
RestartSec=5s
```

Drop-ins are merged after the base unit. If you need to reset list-style directives, use the systemd syntax for clearing the directive first, then set the new values.

## Journals

```bash
journalctl -u nginx.service -b
journalctl -u nginx.service --since "1 hour ago"
journalctl -p warning..alert -b
journalctl -f -u nginx.service
journalctl -k -b
```

The journal can filter by unit, boot, priority, executable, PID, kernel messages, and time range. For incidents, preserve `systemctl status`, relevant `journalctl` windows, and unit definitions before restarting.

## Timers

Timers replace many cron use cases when you want dependency tracking, logs, missed-run handling, and service isolation.

```bash
systemctl list-timers --all
systemctl status backup.timer
systemctl status backup.service
```

A timer usually activates a service with the same base name, such as `backup.timer` activating `backup.service`.

## Resource Controls

systemd uses cgroups, so service resource limits can be set at the unit layer.

```ini
[Service]
CPUQuota=200%
MemoryMax=4G
TasksMax=512
IOWeight=200
```

Inspect service cgroups and pressure:

```bash
systemctl status app.service
systemd-cgls
systemd-cgtop
cat /sys/fs/cgroup/system.slice/app.service/memory.events
```

## Troubleshooting Runbook

1. Check unit state with `systemctl status`.
2. Read the merged unit with `systemctl cat`.
3. Reload after unit changes with `systemctl daemon-reload`.
4. Inspect recent logs with `journalctl -u <unit> -b`.
5. Validate ordering with `systemd-analyze critical-chain <unit>`.
6. Check cgroup resource limits and OOM events.
7. Use `systemd-analyze verify <unit-file>` before deploying hand-written units.

```bash
systemctl status <unit>
systemctl cat <unit>
journalctl -u <unit> -b --no-pager
systemd-analyze critical-chain <unit>
systemd-analyze verify /etc/systemd/system/<unit>
systemctl show <unit> -p ActiveState -p SubState -p Result -p ExecMainStatus
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is a systemd unit?" answer="An ini-style configuration object describing a service, socket, target, timer, mount, slice, scope, or other managed resource." %}
  {% include study-card.html question="What is the difference between start and enable?" answer="start changes current runtime state; enable changes whether dependency symlinks activate the unit at boot or target start." %}
  {% include study-card.html question="Why use a drop-in?" answer="A drop-in overrides or extends a vendor unit without editing package-owned files." %}
  {% include study-card.html question="What does journalctl -u filter by?" answer="It filters journal entries associated with a systemd unit." %}
  {% include study-card.html question="Why are systemd resource controls useful?" answer="They apply cgroup CPU, memory, IO, and task limits at the service boundary." %}
</div>

## References

- [systemd.unit documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
- [systemd.service documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [systemctl documentation](https://www.freedesktop.org/software/systemd/man/latest/systemctl.html)
- [journalctl documentation](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)
- [systemd.resource-control documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)
