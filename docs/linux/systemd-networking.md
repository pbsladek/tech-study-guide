---
title: systemd Networking
layout: page
permalink: /docs/linux/systemd-networking/
summary: "systemd-networkd, systemd-resolved, .network, .netdev, .link files, network targets, wait-online behavior, and operational troubleshooting."
tags:
  - linux
  - systemd
  - networking
  - troubleshooting
---

# systemd Networking

systemd can manage more than services. On many systems it also participates in network device configuration, DNS resolution, boot ordering, and logs. On Ubuntu Server, Netplan commonly renders configuration to either systemd-networkd or NetworkManager, so always confirm which manager owns the interface before editing files.

## First Checks

```bash
networkctl status
networkctl list
resolvectl status
systemctl status systemd-networkd systemd-resolved
journalctl -u systemd-networkd -b
systemd-analyze critical-chain network-online.target
```

These commands show link state, address assignment, DNS state, unit health, networkd logs, and whether boot is waiting on network-online behavior.

## systemd-networkd Model

`systemd-networkd` manages links that match configuration files. It can assign addresses, DHCP, routes, VLANs, bridges, bonds, tunnels, and other virtual devices.

| File Type | Purpose |
| --- | --- |
| `.network` | Matches interfaces and applies addresses, DHCP, routes, DNS, and link behavior. |
| `.netdev` | Creates virtual network devices such as bridges, bonds, VLANs, VXLANs, and tunnels. |
| `.link` | Sets lower-level link attributes such as names, aliases, MTU, and MAC policy through `systemd-udevd` link setup. |

Network files are read from system, runtime, and admin directories such as `/usr/lib/systemd/network`, `/run/systemd/network`, and `/etc/systemd/network`. Numbered filenames such as `10-lan.network` make ordering explicit. Link files are applied earlier by udev's network-device setup, so link naming and MTU policy can affect what later `.network` matches see.

## Static and DHCP Examples

Simple DHCP:

```ini
[Match]
Name=enp1s0

[Network]
DHCP=yes
```

Static address and route:

```ini
[Match]
Name=enp1s0

[Network]
Address=192.0.2.10/24
Gateway=192.0.2.1
DNS=192.0.2.53
Domains=example.internal
```

After changes:

```bash
systemctl restart systemd-networkd
networkctl status enp1s0
journalctl -u systemd-networkd -b
```

On Ubuntu, prefer editing Netplan when Netplan owns the source configuration. Direct networkd files under `/etc/systemd/network` can conflict with or override generated runtime files, so confirm the active renderer and generated state before mixing layers.

## network.target vs network-online.target

`network.target` and `network-online.target` are not the same thing.

| Target | Meaning |
| --- | --- |
| `network.target` | The network management stack has been started or stopped as an ordering point. It does not prove addresses or routes are usable. |
| `network-online.target` | A wait service has decided the network is online according to that manager's rules. |

Services often do not need `network-online.target`. A daemon that binds `0.0.0.0` can usually start before an address exists. A one-shot job that must immediately reach a remote API may need `Wants=network-online.target` and `After=network-online.target`, plus the correct wait-online service enabled.

## wait-online Pitfalls

`systemd-networkd-wait-online` waits for managed interfaces to reach configured states. It can delay boot when an unplugged, optional, or misconfigured interface is considered required.

Common fixes:

- mark optional links appropriately in the `.network` or Netplan source,
- wait for only one required interface when that matches the host role,
- avoid using network-online for services that can retry,
- inspect the critical chain instead of guessing.

```bash
systemctl status systemd-networkd-wait-online
journalctl -u systemd-networkd-wait-online -b
networkctl status
systemd-analyze critical-chain network-online.target
```

## systemd-resolved

`systemd-resolved` provides local DNS resolution, split DNS, DNS-over-TLS support on configured systems, and a local stub resolver such as `127.0.0.53`. Reading `/etc/resolv.conf` alone may not show the real upstream DNS servers.

Useful checks:

```bash
readlink -f /etc/resolv.conf
resolvectl status
resolvectl query example.com
journalctl -u systemd-resolved -b
```

Per-link DNS state matters on VPNs, multi-homed servers, and systems using search domains.

## Troubleshooting Flow

1. Confirm the owner: Netplan, NetworkManager, systemd-networkd, cloud-init, or container runtime.
2. Check link state with `networkctl` and `ip addr`.
3. Check routes and source address selection with `ip route` and `ip route get`.
4. Check DNS state with `resolvectl status`.
5. Read networkd and resolved logs for the current boot.
6. Check `network-online.target` only when boot ordering is part of the failure.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a .network file do?" answer="It matches interfaces and applies network configuration such as DHCP, addresses, routes, DNS, and link behavior." %}
  {% include study-card.html question="What does a .netdev file do?" answer="It creates virtual network devices such as bridges, bonds, VLANs, VXLANs, and tunnels." %}
  {% include study-card.html question="Why is network.target not proof the network is usable?" answer="It is mainly an ordering point for the network management stack, not a guarantee that addresses, DNS, or routes are ready." %}
  {% include study-card.html question="Why can wait-online slow boot?" answer="It may wait for all required managed links to configure or fail, including optional or unplugged interfaces." %}
</div>

## References

- [systemd-networkd.service](https://www.freedesktop.org/software/systemd/man/latest/systemd-networkd.service.html)
- [systemd.network](https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html)
- [systemd.netdev](https://www.freedesktop.org/software/systemd/man/latest/systemd.netdev.html)
- [systemd.link](https://www.freedesktop.org/software/systemd/man/latest/systemd.link.html)
- [systemd-networkd-wait-online.service](https://www.freedesktop.org/software/systemd/man/latest/systemd-networkd-wait-online.service.html)
- [systemd.special](https://www.freedesktop.org/software/systemd/man/latest/systemd.special.html)
- [systemd-resolved.service](https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html)
