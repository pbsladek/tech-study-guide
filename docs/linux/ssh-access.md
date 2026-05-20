---
title: SSH Access
layout: page
permalink: /docs/linux/ssh-access/
summary: "OpenSSH server administration on Ubuntu: sshd config, keys, authentication, host keys, logs, access control, and troubleshooting."
tags:
  - linux
  - ubuntu
  - ssh
  - security
---

# SSH Access

SSH is the main remote administration path for Linux servers. Operators need to understand both sides: the client connection attempt and the server policy in `sshd_config`, drop-in snippets, PAM, keys, account state, firewalls, and logs.

## First Checks

```bash
sudo systemctl status ssh
sudo sshd -T
grep -R '^[^#]' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null
journalctl -u ssh -b
ssh -vvv user@example.com
```

On Ubuntu, the systemd service is commonly named `ssh`, even though the daemon binary is `sshd`.

## Server Configuration

OpenSSH reads `/etc/ssh/sshd_config` and, on modern Ubuntu systems, may also read snippets under `/etc/ssh/sshd_config.d/`. Use `sshd -T` to see the effective server configuration after parsing.

Important controls:

- `PasswordAuthentication`,
- `PubkeyAuthentication`,
- `PermitRootLogin`,
- `AllowUsers` / `AllowGroups`,
- `KbdInteractiveAuthentication`,
- `AuthorizedKeysFile`,
- `Match` blocks.

## Keys and Host Identity

User keys authenticate users. Host keys authenticate the server to clients. Do not confuse them.

If a server is rebuilt and host keys change, clients may warn about a possible man-in-the-middle attack. Verify the rebuild or key rotation before deleting `known_hosts` entries.

## Account and Permission Checks

SSH can fail even when the network is fine:

- account locked or expired,
- shell set to `nologin`,
- home directory or `.ssh` permissions too open,
- wrong ownership of `authorized_keys`,
- user not in an allowed group,
- PAM denies login,
- firewall or security group blocks TCP 22,
- fail2ban or similar tooling blocks the client.

## Debugging Flow

1. From the client, run `ssh -vvv`.
2. On the server, watch `journalctl -u ssh -f`.
3. Confirm effective config with `sshd -T`.
4. Check user existence with `getent passwd <user>`.
5. Check account state, groups, shell, home, and `.ssh` permissions.
6. Confirm firewall and route before changing authentication policy.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does sshd -T show?" answer="The effective OpenSSH server configuration after parsing config files and defaults." %}
  {% include study-card.html question="What is the difference between user keys and host keys?" answer="User keys authenticate users to the server; host keys authenticate the server to clients." %}
  {% include study-card.html question="Why watch journalctl -u ssh during login tests?" answer="Server logs show policy, PAM, key, account, and authentication failures that the client may summarize poorly." %}
</div>

## References

- [Ubuntu OpenSSH server documentation](https://documentation.ubuntu.com/server/how-to/security/openssh-server/)
- [sshd_config(5)](https://man7.org/linux/man-pages/man5/sshd_config.5.html)
- [ssh_config(5)](https://man7.org/linux/man-pages/man5/ssh_config.5.html)
- [authorized_keys file format](https://man7.org/linux/man-pages/man8/sshd.8.html)
