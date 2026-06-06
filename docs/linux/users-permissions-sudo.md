---
title: Users, Permissions, and sudo
layout: page
permalink: /docs/linux/users-permissions-sudo/
summary: "Linux identities, groups, file modes, ownership, sudo, service users, locked accounts, ACLs, and permission troubleshooting on Ubuntu."
tags:
  - linux
  - ubuntu
  - security
  - administration
---

# Users, Permissions, and sudo

Linux administration starts with identities and permissions. Processes run as users and groups. Files have owners, groups, and mode bits. `sudo` controls privilege escalation. Service accounts, locked passwords, SSH keys, ACLs, and filesystem ownership explain many production access failures.

## Command Examples

```bash
id
getent passwd
getent group sudo
sudo -l
ls -l /etc/passwd /etc/shadow /etc/sudoers
sudo visudo -c
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `id` | `uid=1000(app) gid=1000(app) groups=1000(app),27(sudo).` | Shows effective user and group identity. |
| `getent passwd` | `app:x:1000:1000:App User:/srv/app:/usr/sbin/nologin.` | Confirms account UID, home, and shell from NSS. |
| `getent group sudo` | `sudo:x:27:alice,ops.` | Shows group membership from NSS. |

## Identity Model

| Concept | Meaning |
| --- | --- |
| UID | Numeric user identity used by the kernel. |
| GID | Numeric primary group identity. |
| Supplementary groups | Extra groups attached to a login session or process. |
| `/etc/passwd` | Local user database with names, UIDs, GIDs, home directories, and shells. |
| `/etc/shadow` | Password hashes and password aging data, readable only by privileged users. |
| `/etc/group` | Local group database. |

Names are human-friendly. UIDs and GIDs are what matter to filesystems and processes.

## File Permissions

The classic mode bits are user, group, and other permissions for read, write, and execute. Directories need execute permission to traverse and read permission to list names.

```bash
namei -l /var/www/example/index.html
stat /var/www/example/index.html
getfacl /var/www/example/index.html 2>/dev/null
```

Common permission failures:

- wrong owner after copying files as root,
- service user lacks directory execute permission on a parent path,
- group membership changed but session was not restarted,
- ACLs override simple mode-bit expectations,
- systemd service uses `User=`, `Group=`, `DynamicUser=`, or sandboxing directives.

## sudo

On Ubuntu, the first administrative user is typically in the `sudo` group. Prefer `visudo` or drop-in files under `/etc/sudoers.d/` so syntax is validated before saving.

Operational rules:

- grant least privilege where practical,
- avoid broad passwordless sudo unless tightly scoped,
- log and audit administrative actions,
- do not edit `/etc/sudoers` with a normal editor,
- remember sudo policy is separate from file permissions.

## Service Users

Many daemons run as non-login service users. A locked password does not necessarily mean the account cannot run processes; it usually means it cannot authenticate with a password. SSH key access and service manager execution are separate concerns.

## Troubleshooting Flow

1. Confirm the process UID, GID, and supplementary groups.
2. Walk the full path with `namei -l`.
3. Check owner, group, mode bits, ACLs, and mount options.
4. Check whether the service runs under a different user than the interactive shell.
5. Validate sudo policy with `sudo -l` and `visudo -c`.
6. Log out and back in after group changes.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does the kernel use for user identity?" answer="Numeric UIDs and GIDs, not the textual names shown in files such as /etc/passwd." %}
  {% include study-card.html question="Why can a file be readable but still inaccessible?" answer="A parent directory may lack execute permission, preventing path traversal." %}
  {% include study-card.html question="Why use visudo?" answer="It validates sudoers syntax before saving, reducing the risk of locking out sudo access." %}
</div>

## References

- [Ubuntu user management](https://documentation.ubuntu.com/server/how-to/security/user-management/)
- [passwd(5)](https://man7.org/linux/man-pages/man5/passwd.5.html)
- [shadow(5)](https://man7.org/linux/man-pages/man5/shadow.5.html)
- [sudoers manual](https://www.sudo.ws/docs/man/sudoers.man/)
- [Debian Reference: Unix file basics](https://www.debian.org/doc/manuals/debian-reference/ch01.en.html)
