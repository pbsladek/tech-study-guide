---
title: Scheduled Automation
layout: page
permalink: /docs/linux/scheduled-automation/
summary: "Cronjobs, anacron, systemd timers, user timers, environment pitfalls, idempotent jobs, logs, locking, and automation troubleshooting."
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

## Cronjobs

Cron runs commands on schedules defined by crontab files. Cronjobs are simple and portable, but they fail quietly when environment, paths, permissions, mail, locking, or host uptime are misunderstood.

Cron jobs do not have the same environment as an interactive shell. Always use absolute paths, explicit environment variables, clear output handling, and predictable working directories.

Common locations:

| Location | Owner | Format |
| --- | --- | --- |
| User crontab from `crontab -e` | One user. | Five schedule fields plus command. No username field. |
| `/etc/crontab` | System. | Schedule fields, username, command. |
| `/etc/cron.d/*` | System packages or local admins. | Schedule fields, username, command. |
| `/etc/cron.hourly/`, `/etc/cron.daily/`, `/etc/cron.weekly/`, `/etc/cron.monthly/` | `run-parts` or anacron depending on distro. | Executable scripts, not crontab lines. |
| `/var/spool/cron/crontabs` | Cron daemon storage for user crontabs. | Do not edit directly. |

Crontab field shape:

```text
# minute hour day-of-month month day-of-week command
15 2 * * * /usr/local/sbin/backup-app >>/var/log/backup-app.log 2>&1
```

Useful schedule examples:

| Schedule | Meaning |
| --- | --- |
| `* * * * *` | Every minute. Usually too frequent for heavy work. |
| `*/5 * * * *` | Every five minutes. |
| `15 2 * * *` | 02:15 every day. |
| `0 3 * * 0` | 03:00 every Sunday. |
| `0 1 1 * *` | 01:00 on the first day of every month. |
| `@reboot` | Once when cron starts for that user. Not a dependency-aware service manager. |

Cron environment:

- `SHELL` defaults to `/bin/sh` on many systems, not your login shell.
- `PATH` is usually minimal.
- `HOME` and `LOGNAME` are set from the crontab owner.
- `MAILTO` controls where command output is mailed if local mail is configured.
- `CRON_TZ` can set the timezone for schedules in implementations that support it.
- Some implementations support `RANDOM_DELAY` to spread starts and avoid thundering herds.

Good cronjob pattern:

```cron
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=ops@example.com

15 2 * * * flock -n /run/backup-app.lock /usr/local/sbin/backup-app >>/var/log/backup-app.log 2>&1
```

Cronjob design rules:

- Put complex logic in a script under version control; keep the crontab line short.
- Use absolute paths for commands, config files, logs, and working directories.
- Use `flock` or a service-level lock so slow runs do not overlap.
- Make the job idempotent so manual reruns are safe.
- Send output somewhere monitored. Silence is only safe if a separate monitor checks last success time.
- Check exit codes and fail hard when a required command fails.
- Use a dedicated user instead of root when possible.
- Treat secrets carefully: prefer root-readable config files, environment files with tight permissions, or workload identity. Do not paste long-lived credentials into crontabs.
- Think about timezone and DST. Jobs scheduled during skipped or repeated local times can behave surprisingly.

Cron versus anacron:

| Tool | Fit |
| --- | --- |
| cron | Hosts that are expected to be running at the scheduled time. |
| anacron | Machines that may be powered off, such as laptops or small edge systems. It runs missed daily/weekly/monthly jobs after boot. |
| systemd timer | System jobs needing logs, dependencies, resource controls, missed-run handling, and service isolation. |

Cron does not know whether a service dependency is ready. If a job needs networking, a mounted volume, or a database, the script must check that dependency or the job should usually be a systemd timer/service pair.

## systemd Timers

systemd timers pair a `.timer` unit with a `.service` unit. They are often better for system-level automation because they integrate with dependencies, logs, missed-run handling, resource controls, and service isolation.

```bash
systemctl cat apt-daily.timer
systemctl status apt-daily.timer
journalctl -u apt-daily.service -b
```

Minimal timer pair:

```ini
# /etc/systemd/system/backup-app.service
[Unit]
Description=Backup app data

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/backup-app
User=backup
Group=backup
```

```ini
# /etc/systemd/system/backup-app.timer
[Unit]
Description=Run app backup daily

[Timer]
OnCalendar=*-*-* 02:15:00
Persistent=true
RandomizedDelaySec=15m

[Install]
WantedBy=timers.target
```

`Persistent=true` lets a timer catch up after the machine was off at the scheduled time. `RandomizedDelaySec=` spreads jobs so many hosts do not all start at once.

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

For backups and transfer jobs, see [Linux Backup and File Transfer](../backup-transfer-rsync-scp-snapshots/) for `rsync`, `scp`, snapshot consistency, and restore checks.

## Troubleshooting Flow

1. Confirm the schedule is loaded.
2. Confirm the job ran at the expected time.
3. Check logs for the service or cron daemon.
4. Reproduce with the same user and environment.
5. Check working directory, PATH, permissions, and shell.
6. Check locks and stale pid files.
7. Confirm the job is safe to rerun manually.

Cron-specific checks:

```bash
crontab -l
sudo crontab -l -u <user>
sudo grep -R '^[^#]' /etc/crontab /etc/cron.d 2>/dev/null
sudo run-parts --test /etc/cron.daily
journalctl -u cron -b
grep CRON /var/log/syslog
```

If a cronjob works manually but not in cron, reproduce the cron environment:

```bash
sudo -u <user> env -i SHELL=/bin/sh HOME=/home/<user> PATH=/usr/bin:/bin /usr/local/sbin/job
```

Common cron failures:

| Symptom | Likely Cause |
| --- | --- |
| Job never runs | Wrong crontab location, cron daemon stopped, bad file permissions, missing newline at end, invalid schedule. |
| Runs manually but fails in cron | Minimal `PATH`, wrong shell, missing environment variables, relative paths. |
| Runs twice or overlaps | Job takes longer than interval, no lock, duplicate crontab entries. |
| No logs | Output discarded, local mail not configured, script redirects incorrectly. |
| Runs at unexpected local time | Timezone, DST, `CRON_TZ`, host clock, container timezone. |
| `/etc/cron.daily` script ignored | Not executable, invalid filename for `run-parts`, wrong shebang. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why do cron jobs fail while the command works interactively?" answer="Cron runs with a smaller environment, different PATH, and often a different working directory." %}
  {% include study-card.html question="What is the difference between user crontabs and /etc/cron.d files?" answer="User crontabs omit the username field; /etc/crontab and /etc/cron.d entries include a username before the command." %}
  {% include study-card.html question="Why use flock in cronjobs?" answer="To prevent overlapping runs when one execution lasts longer than the schedule interval." %}
  {% include study-card.html question="When is anacron useful?" answer="For daily, weekly, or monthly jobs on machines that may be powered off at the scheduled time." %}
  {% include study-card.html question="Why use systemd timers for system jobs?" answer="They integrate with logs, dependencies, resource controls, missed-run handling, and service isolation." %}
  {% include study-card.html question="What does idempotent automation mean?" answer="Rerunning the job does not corrupt state or create unintended duplicate effects." %}
</div>

## References

- [crontab(5)](https://man7.org/linux/man-pages/man5/crontab.5.html)
- [anacrontab(5)](https://man7.org/linux/man-pages/man5/anacrontab.5.html)
- [systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
- [systemd.service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [Debian Reference: scheduled tasks](https://www.debian.org/doc/manuals/debian-reference/ch09.en.html)
