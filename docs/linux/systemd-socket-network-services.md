---
title: systemd Socket Activation and Network Services
layout: page
permalink: /docs/linux/systemd-socket-network-services/
summary: "systemd socket activation, ListenStream, ListenDatagram, Accept modes, service dependencies, restart behavior, resource controls, and network sandboxing."
tags:
  - linux
  - systemd
  - networking
  - troubleshooting
---

# systemd Socket Activation and Network Services

Socket activation lets systemd own a listening socket and start the service when traffic arrives. This changes debugging: the process may not be running yet, but the port can still be listening because the `.socket` unit is active.

## First Checks

```bash
systemctl list-sockets
systemctl status ssh.socket
systemctl cat ssh.socket
systemctl show <service> -p IPAccounting -p IPAddressDeny -p SocketBindDeny
journalctl -u <service> -b
ss -tulpen
```

Use these checks when a port is open but the expected daemon is not visible, or when systemd owns listener setup instead of the application.

## Socket Units

A `.socket` unit describes sockets or FIFOs that systemd creates and supervises. The matching `.service` usually has the same base name unless `Service=` points elsewhere.

Common directives:

| Directive | Purpose |
| --- | --- |
| `ListenStream=` | TCP stream socket, Unix stream socket, or another stream endpoint. |
| `ListenDatagram=` | UDP datagram socket or Unix datagram socket. |
| `ListenFIFO=` | Named pipe activation. |
| `SocketUser=` / `SocketGroup=` | Ownership for filesystem sockets or FIFOs. |
| `SocketMode=` | Permissions for filesystem sockets or FIFOs. |
| `Backlog=` | Listen backlog for stream sockets. |
| `Accept=` | Whether one service handles all connections or one instance is created per connection. |

Example:

```ini
[Socket]
ListenStream=0.0.0.0:8443
Backlog=4096

[Install]
WantedBy=sockets.target
```

## Accept=yes and Accept=no

`Accept=no` is the normal model for modern daemons: one service receives the listening socket and handles connections. `Accept=yes` starts a new templated service instance for each accepted connection, similar to inetd-style designs.

| Mode | Behavior |
| --- | --- |
| `Accept=no` | One service gets the listening socket and handles all connections. |
| `Accept=yes` | systemd accepts each connection and starts an instance such as `name@.service`. |

For high-throughput services, prefer daemons designed for `Accept=no`. Per-connection service instances add process and unit overhead.

## Service Dependencies

Socket activation often reduces boot coupling. A service activated by a local listener may not need to wait for `network-online.target`; it can start when traffic arrives. Remote client jobs that must connect immediately are different and may need online ordering or retry logic.

Watch for these dependency mistakes:

- adding `After=network-online.target` to every network daemon by habit,
- enabling a `.service` but forgetting the `.socket`,
- disabling a `.service` while the `.socket` still opens the port,
- debugging only the process list when systemd owns the listener.

```bash
systemctl is-enabled app.socket app.service
systemctl status app.socket app.service
systemctl list-dependencies sockets.target
systemd-analyze critical-chain app.socket
```

## Restart and Rate Limits

The socket unit and service unit have separate state. A service can fail repeatedly while the socket remains active, making the port look open but requests fail after activation.

Check:

```bash
systemctl status app.socket app.service
systemctl show app.service -p Restart -p RestartUSec -p StartLimitBurst -p StartLimitIntervalUSec
journalctl -u app.service -b
```

Use `Restart=`, `RestartSec=`, and start-limit settings intentionally. Fast crash loops can exhaust rate limits and leave activation failing until the limit window passes or state is reset.

## Network Resource Controls and Sandboxing

systemd can apply network-related service controls at the unit boundary. These do not replace firewalls or application authorization, but they are useful containment.

| Directive | Use |
| --- | --- |
| `IPAccounting=` | Count IP traffic for the unit. |
| `IPAddressAllow=` / `IPAddressDeny=` | Restrict address ranges the unit may reach or accept. |
| `RestrictAddressFamilies=` | Limit socket families such as `AF_INET`, `AF_INET6`, or `AF_UNIX`. |
| `PrivateNetwork=` | Give the service a private network namespace. |
| `SocketBindAllow=` / `SocketBindDeny=` | Restrict which ports a service may bind. |

Resource controls still interact with kernel limits. A service with socket activation can also be limited by cgroup CPU, memory, file descriptor limits, backlog settings, TCP queues, and conntrack.

## Troubleshooting Flow

1. Run `systemctl list-sockets` to see whether systemd owns the listener.
2. Inspect the socket and service together with `systemctl status` and `systemctl cat`.
3. Confirm `ListenStream`, `ListenDatagram`, bind address, permissions, and backlog.
4. Check whether `Accept=yes` implies templated service instances.
5. Read service logs for activation failures and rate limits.
6. Check resource controls such as `IPAccounting`, `PrivateNetwork`, `RestrictAddressFamilies`, and file descriptor limits.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is systemd socket activation?" answer="systemd owns a socket and starts the associated service when traffic or activity arrives." %}
  {% include study-card.html question="What does ListenStream configure?" answer="A stream listener such as TCP or a Unix stream socket for a .socket unit." %}
  {% include study-card.html question="What does Accept=yes do?" answer="It starts a separate templated service instance for each accepted connection." %}
  {% include study-card.html question="Why can a port be open while the daemon is not running?" answer="The .socket unit may be active and owning the listener before it activates the service." %}
</div>

## References

- [systemd.socket](https://www.freedesktop.org/software/systemd/man/latest/systemd.socket.html)
- [systemd.service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
- [systemd.exec](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)
- [systemd.resource-control](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)
- [systemd.special](https://www.freedesktop.org/software/systemd/man/latest/systemd.special.html)
