---
title: Linux Operations Examples
layout: page
permalink: /docs/linux/practical-examples/
summary: "Practical Linux examples for systemd services, timers, rsync snapshot backups, and nftables host firewalls."
tags:
  - examples
  - linux
  - systemd
  - backups
  - firewalls
---

# Linux Operations Examples

These examples complement [Linux](/docs/linux/), [systemd](/docs/linux/systemd/), [scheduled automation](/docs/linux/scheduled-automation/), [backup and file transfer](/docs/linux/backup-transfer-rsync-scp-snapshots/), and [firewall](/docs/networking/firewalls-iptables-netfilter/) notes.

## Linux Service Example

A small systemd service with explicit user, restart behavior, logging, and resource controls:

```ini
[Unit]
Description=Example API service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=app
Group=app
WorkingDirectory=/opt/example-api
EnvironmentFile=-/etc/example-api/env
ExecStart=/opt/example-api/bin/server --config /etc/example-api/config.yaml
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/lib/example-api /var/log/example-api
MemoryMax=1G
CPUQuota=150%
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

Companion timer for a safe maintenance job:

```ini
[Unit]
Description=Nightly example-api cleanup

[Timer]
OnCalendar=*-*-* 03:15:00
RandomizedDelaySec=20m
Persistent=true
Unit=example-api-cleanup.service

[Install]
WantedBy=timers.target
```

```ini
[Unit]
Description=Run example-api cleanup

[Service]
Type=oneshot
User=app
ExecStart=/usr/bin/flock -n /run/example-api-cleanup.lock /opt/example-api/bin/cleanup
```

## Linux Backup Script Example

An rsync snapshot pattern using `--link-dest` and a dry run before destructive synchronization:

```bash
#!/usr/bin/env bash
set -euo pipefail

source_dir="/srv/app/"
backup_root="/backups/app"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
latest="${backup_root}/latest"
target="${backup_root}/${stamp}"

mkdir -p "$target"

rsync -aHAXn --delete \
  --exclude cache/ \
  --exclude tmp/ \
  --link-dest "$latest" \
  "$source_dir" "$target/"

rsync -aHAX --delete \
  --exclude cache/ \
  --exclude tmp/ \
  --link-dest "$latest" \
  "$source_dir" "$target/"

ln -sfn "$target" "$latest"
```

## nftables Firewall Example

A small host firewall that defaults to deny inbound traffic while allowing established flows, SSH, HTTP, and HTTPS:

```nft
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    iif lo accept
    ct state established,related accept
    ct state invalid drop

    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept

    tcp dport { 22, 80, 443 } accept

    counter log prefix "nft-drop-input: " flags all drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why set an explicit User in a systemd service?" answer="It prevents the service from running as root unless root privileges are actually required." %}
  {% include study-card.html question="Why run rsync with --dry-run before --delete?" answer="It previews deletions so a wrong source path or exclude rule does not erase the destination." %}
  {% include study-card.html question="What should a default-deny host firewall still allow?" answer="Loopback, established flows, required management and service ports, and the ICMP/ICMPv6 behavior needed for operations." %}
</div>

## References

- [systemd service units](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [systemd timers](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
- [rsync documentation](https://download.samba.org/pub/rsync/rsync.1)
- [nftables wiki](https://wiki.nftables.org/)
