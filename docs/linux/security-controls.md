---
title: Linux Security Controls
layout: page
permalink: /docs/linux/security-controls/
summary: "Linux security primitives for capabilities, seccomp, AppArmor, SELinux, PAM, auditd, sudoers, file capabilities, setuid, and container boundaries."
tags:
  - linux
  - security
  - permissions
  - containers
---

# Linux Security Controls

Linux security is layered. Traditional UID/GID permissions are only the start; modern systems also use capabilities, PAM, sudoers, LSMs such as AppArmor or SELinux, seccomp filters, audit rules, file capabilities, mount options, and container boundaries.

The practical skill is identifying which layer denied the operation.

## Command Examples

```bash
id
sudo -l
getcap -r /usr/bin /usr/sbin 2>/dev/null
aa-status 2>/dev/null || true
sestatus 2>/dev/null || true
journalctl -k -g 'apparmor|SELinux|seccomp|audit'
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `id` | `uid=1000(app) gid=1000(app) groups=1000(app),27(sudo).` | Shows effective user and group identity. |
| `sudo -l` | `User app may run /usr/bin/systemctl restart api as root.` | Shows allowed sudo commands and policy restrictions. |
| `getcap -r /usr/bin /usr/sbin 2>/dev/null` | `/usr/bin/ping cap_net_raw=ep.` | Finds file capabilities that bypass normal privilege assumptions. |

Permission failures can look identical at the application layer while coming from different controls.

## Capabilities

Capabilities split root privileges into smaller units. A process may have permission to bind low ports, change network settings, or load modules without having every root privilege.

Useful commands:

```bash
capsh --print
grep Cap /proc/<pid>/status
getcap /path/to/binary
setcap cap_net_bind_service=+ep /usr/local/bin/server
```

Common capabilities:

| Capability | Allows |
| --- | --- |
| `CAP_NET_BIND_SERVICE` | Bind ports below 1024. |
| `CAP_NET_ADMIN` | Configure interfaces, routing, firewall, and many network options. |
| `CAP_SYS_ADMIN` | Broad administrative power; avoid granting casually. |
| `CAP_DAC_OVERRIDE` | Bypass file read/write/execute permission checks. |
| `CAP_CHOWN` | Change file ownership. |

`CAP_SYS_ADMIN` is intentionally broad and often equivalent to too much trust.

## seccomp

seccomp filters restrict which syscalls a process may make. Containers often use seccomp profiles to reduce kernel attack surface.

Symptoms:

- syscall returns `EPERM`,
- process receives `SIGSYS`,
- container works with an unconfined profile but fails with the default profile,
- audit logs mention seccomp.

Checks:

```bash
grep Seccomp /proc/<pid>/status
journalctl -k -g seccomp
```

## AppArmor and SELinux

Linux Security Modules add policy beyond Unix permissions.

| LSM | Common Distros | Useful Checks |
| --- | --- | --- |
| AppArmor | Ubuntu, Debian | `aa-status`, profiles under `/etc/apparmor.d`, kernel denial logs. |
| SELinux | RHEL-family, Fedora | `sestatus`, labels with `ls -Z`, audit logs, booleans. |

If mode bits look correct but access is denied, check LSM policy and labels/profiles.

## PAM, sudoers, and auditd

PAM controls login and authentication flows. sudoers controls delegated privilege. auditd records policy-relevant events.

```bash
sudo visudo -c
sudo -l -U <user>
grep -R '^[^#]' /etc/pam.d
auditctl -s 2>/dev/null || true
ausearch -m AVC,USER_AUTH,USER_ACCT,SYSCALL 2>/dev/null | tail
```

PAM failures often appear as SSH or sudo failures, but the root cause may be account expiration, group membership, MFA policy, or module order.

## setuid, setgid, and File Capabilities

setuid and setgid binaries execute with owner or group privileges. File capabilities are narrower alternatives for specific privileges.

```bash
find / -perm -4000 -type f -xdev 2>/dev/null
find / -perm -2000 -type f -xdev 2>/dev/null
getcap -r / 2>/dev/null
```

Audit these regularly. Unexpected setuid binaries and broad file capabilities are high-value escalation paths.

## Containers and Boundaries

Container security combines namespaces, cgroups, capabilities, seccomp, LSMs, read-only filesystems, user namespaces, and runtime policy.

Important questions:

- Is the container privileged?
- Which capabilities were added or dropped?
- Is host networking, host PID, or hostPath mounted?
- Is seccomp unconfined?
- Are AppArmor or SELinux labels applied?
- Is the root filesystem read-only?

## Runbook

1. Capture the exact operation and error: path, syscall, user, process, namespace.
2. Check Unix permissions, ACLs, owner, group, and mount options.
3. Check capabilities and file capabilities.
4. Check seccomp mode and denial logs.
5. Check AppArmor or SELinux profile/label denials.
6. Check PAM/sudoers/audit logs for auth and privilege failures.
7. Fix the narrowest policy layer instead of granting broad root or privileged container access.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What are Linux capabilities?" answer="Fine-grained privilege bits that split some root powers into narrower permissions." %}
  {% include study-card.html question="What does seccomp restrict?" answer="The syscalls a process is allowed to make." %}
  {% include study-card.html question="Why can AppArmor or SELinux deny access when mode bits allow it?" answer="LSM policy adds mandatory access controls beyond traditional Unix permissions." %}
  {% include study-card.html question="Why avoid privileged containers as a quick fix?" answer="They bypass many isolation controls and can turn a narrow permission problem into host-level risk." %}
</div>

## References

- [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [seccomp(2)](https://man7.org/linux/man-pages/man2/seccomp.2.html)
- [AppArmor documentation](https://apparmor.net/)
- [SELinux project documentation](https://github.com/SELinuxProject/selinux-notebook)
- [sudoers(5)](https://man7.org/linux/man-pages/man5/sudoers.5.html)
