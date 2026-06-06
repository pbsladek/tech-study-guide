---
title: Debian and Ubuntu Operations
layout: page
permalink: /docs/linux/debian-ubuntu/
summary: "Ubuntu-first Linux operations: apt, dpkg, systemd, journald, netplan, ufw, CA certificates, logs, services, and package troubleshooting."
tags:
  - linux
  - ubuntu
  - debian
  - operations
---

# Debian and Ubuntu Operations

The study guide is Linux-first, but the default operational assumption is now Debian-family systems, especially Ubuntu Server. That matters because package tools, network configuration, service defaults, certificate stores, log locations, and firewall tooling differ by distribution. Canonical's Ubuntu Server documentation tracks the latest LTS, so always check the target release notes or manpages before relying on release-specific behavior.

## Command Examples

```bash
cat /etc/os-release
uname -a
apt-cache policy
systemctl --failed
journalctl -p warning..alert -b
ls -l /etc/netplan
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `cat /etc/os-release` | `PRETTY_NAME="Ubuntu 24.04.2 LTS".` | Identifies the distro baseline before applying package or service commands. |
| `uname -a` | `Linux host 6.8.0-xx-generic x86_64.` | Shows kernel version and architecture for driver, eBPF, and tuning checks. |
| `apt-cache policy` | `Package versions, installed candidate, and repository priority.` | Shows what version apt can install or upgrade to. |

## Package Management

`apt` is the day-to-day package interface. `dpkg` is the lower-level package database and installer. Use `apt-cache policy` to see candidate versions and repositories before changing packages.

```bash
sudo apt update
apt-cache policy nginx
sudo apt install nginx
dpkg -l | grep nginx
dpkg -L nginx
```

## Services and Logs

Ubuntu uses systemd by default. For most service incidents, start with:

```bash
systemctl status <service>
journalctl -u <service> -b
systemctl cat <service>
systemctl list-dependencies <service>
```

Package-owned unit files usually live under `/usr/lib/systemd/system` or `/lib/systemd/system`, with admin overrides under `/etc/systemd/system`.

## Networking Defaults

Ubuntu Server commonly uses Netplan to describe network configuration, which then renders configuration for systemd-networkd or NetworkManager. Cloud images may also be influenced by cloud-init.

```bash
ip addr
ip route
resolvectl status
sudo netplan status
sudo netplan try
```

## Firewall and Certificates

Ubuntu often uses `ufw` as a human-facing firewall tool over lower-level packet filtering.

```bash
sudo ufw status verbose
sudo nft list ruleset
sudo update-ca-certificates
ls -l /usr/local/share/ca-certificates /etc/ssl/certs
```

## Troubleshooting Habits

- Check `/etc/os-release` before assuming commands or paths.
- Prefer `journalctl` for systemd services, but know app logs may still live in `/var/log`.
- Use `apt-cache policy` before upgrades to understand repository sources.
- Use `sudo netplan try` when changing remote network config.
- Treat `/usr/local/share/ca-certificates` plus `update-ca-certificates` as the standard Ubuntu path for local root CAs.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the default distro focus for this guide?" answer="Debian-family Linux, especially Ubuntu Server, where distro-specific commands matter." %}
  {% include study-card.html question="What does apt-cache policy show?" answer="Installed and candidate package versions plus the repositories that provide them." %}
  {% include study-card.html question="Why use netplan try remotely?" answer="It applies network changes with rollback behavior if connectivity is lost or the change is not confirmed." %}
</div>

## References

- [Ubuntu Server documentation](https://ubuntu.com/server/docs)
- [Debian apt user manual](https://www.debian.org/doc/manuals/debian-handbook/sect.apt-get.en.html)
- [Ubuntu Netplan documentation](https://netplan.readthedocs.io/)
- [Ubuntu update-ca-certificates(8)](https://manpages.ubuntu.com/manpages/resolute/man8/update-ca-certificates.8.html)
