---
title: Logs and Observability
layout: page
permalink: /docs/linux/logs-observability/
summary: "Linux logs, journald, syslog, dmesg, service status, boot logs, log rotation, metrics, and incident evidence collection."
tags:
  - linux
  - observability
  - troubleshooting
  - logs
---

# Logs and Observability

Linux administration requires knowing where evidence lives. The useful signal may be in the systemd journal, kernel ring buffer, application logs, syslog files, service status, metrics, or audit logs. Good operators collect evidence before restarting the thing that is failing.

## First Checks

```bash
journalctl -b
journalctl -p warning..alert -b
journalctl -u ssh -b
dmesg -T | tail -100
ls -lh /var/log
systemctl status systemd-journald
```

## Journal

`journald` stores structured events with fields such as unit, boot ID, priority, PID, executable, message, and timestamps. It is usually the fastest path for systemd service incidents.

Useful patterns:

```bash
journalctl -u nginx -b
journalctl --since "30 minutes ago"
journalctl -k -b
journalctl -o short-iso-precise
journalctl --list-boots
```

## Kernel Logs

Kernel messages include driver errors, OOM kills, storage faults, network warnings, filesystem remounts, and hardware signals. `dmesg` reads the kernel ring buffer; journald may also collect kernel messages.

## /var/log and Rotation

Ubuntu systems still use files under `/var/log` for many services. `logrotate` rotates many traditional logs. A deleted-but-open log can still consume disk until the process closes the file descriptor.

## Metrics and Pressure

Logs explain events. Metrics show shape over time. For host incidents, combine logs with:

- CPU, memory, IO, and network utilization,
- cgroup metrics,
- Pressure Stall Information,
- service restart counts,
- disk/inode usage,
- time synchronization state.

## Incident Evidence Checklist

1. `systemctl status <service>`.
2. `journalctl -u <service> -b --since ...`.
3. `journalctl -p warning..alert -b`.
4. Kernel logs for OOM, IO, filesystem, network, or driver issues.
5. App logs under `/var/log` or application-specific paths.
6. Resource snapshots: CPU, memory, disk, network, and cgroups.
7. Config state before changing it.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why collect logs before restarting?" answer="Restarting can rotate evidence, clear process state, and hide the original failure mode." %}
  {% include study-card.html question="What does journalctl -u filter by?" answer="A systemd unit, such as a service." %}
  {% include study-card.html question="Why pair logs with metrics?" answer="Logs show events; metrics show resource shape and timing across the incident window." %}
</div>

## References

- [journalctl(1)](https://man7.org/linux/man-pages/man1/journalctl.1.html)
- [systemd-journald.service(8)](https://www.freedesktop.org/software/systemd/man/latest/systemd-journald.service.html)
- [dmesg(1)](https://man7.org/linux/man-pages/man1/dmesg.1.html)
- [logrotate(8)](https://man7.org/linux/man-pages/man8/logrotate.8.html)
