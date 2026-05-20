---
title: Scheduled Automation
layout: page
permalink: /docs/linux/scheduled-automation/
summary: "Cron, anacron, systemd timers, user timers, environment pitfalls, idempotent jobs, logs, locking, and automation troubleshooting."
tags:
  - linux
  - automation
  - cron
  - systemd
---

# Scheduled Automation

Scheduled work is how maintenance actually happens: backups, certificate renewals, cleanup, reports, sync jobs, and recurring checks. The hard part is not writing a command; it is making the job safe, observable, idempotent, and predictable.

## First Checks

```bash
systemctl list-timers --all
crontab -l
sudo ls -l /etc/cron.d /etc/cron.daily /var/spool/cron/crontabs
systemctl status cron
journalctl -u cron -b
```

## cron

Cron runs commands on schedules defined by crontab files. Cron jobs do not have the same environment as an interactive shell. Always use absolute paths, explicit environment variables, clear output handling, and predictable working directories.

Common locations:

- user crontabs,
- `/etc/crontab`,
- `/etc/cron.d/`,
- `/etc/cron.hourly/`, `/etc/cron.daily/`, `/etc/cron.weekly/`, `/etc/cron.monthly/`.

## systemd Timers

systemd timers pair a `.timer` unit with a `.service` unit. They are often better for system-level automation because they integrate with dependencies, logs, missed-run handling, resource controls, and service isolation.

```bash
systemctl cat apt-daily.timer
systemctl status apt-daily.timer
journalctl -u apt-daily.service -b
```

## Job Safety

Operational automation should handle:

- idempotency,
- locking to prevent overlapping runs,
- timeout behavior,
- clear logs,
- failure alerts,
- safe retries,
- least-privilege execution,
- secrets handling,
- rollback or cleanup on partial failure.

## Troubleshooting Flow

1. Confirm the schedule is loaded.
2. Confirm the job ran at the expected time.
3. Check logs for the service or cron daemon.
4. Reproduce with the same user and environment.
5. Check working directory, PATH, permissions, and shell.
6. Check locks and stale pid files.
7. Confirm the job is safe to rerun manually.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why do cron jobs fail while the command works interactively?" answer="Cron runs with a smaller environment, different PATH, and often a different working directory." %}
  {% include study-card.html question="Why use systemd timers for system jobs?" answer="They integrate with logs, dependencies, resource controls, missed-run handling, and service isolation." %}
  {% include study-card.html question="What does idempotent automation mean?" answer="Rerunning the job does not corrupt state or create unintended duplicate effects." %}
</div>

## References

- [crontab(5)](https://man7.org/linux/man-pages/man5/crontab.5.html)
- [systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
- [systemd.service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [Debian Reference: scheduled tasks](https://www.debian.org/doc/manuals/debian-reference/ch09.en.html)
