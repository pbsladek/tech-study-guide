---
title: Switching, VLANs, and Hosts
layout: page
permalink: /docs/networking/switching-vlans-hosts/
summary: "Layer 2 switching, MAC tables, VLAN access and trunk ports, Linux bridges, 802.1Q tagging, and /etc/hosts name overrides."
tags:
  - networking
  - switching
  - vlan
  - linux
---

# Switching, VLANs, and Hosts

Layer 2 is where hosts become reachable on a local network. Switches learn MAC addresses, VLANs split one physical switching fabric into multiple broadcast domains, and `/etc/hosts` can override name resolution before DNS is involved. These details explain many "network" failures that never reach TCP, TLS, or Kubernetes.

## First Checks

```bash
ip link
bridge link
bridge vlan show
ip -d link show
cat /etc/hosts
getent hosts example.internal
```

## Switches

A switch forwards Ethernet frames by learning source MAC addresses. It builds a forwarding table that maps MAC addresses to ports. When the destination MAC is known, the switch forwards the frame to the learned port. When the destination is unknown, broadcast, or multicast, it may flood within the VLAN.

Important behaviors:

- A switch learns from source MAC addresses.
- Broadcast traffic stays inside its VLAN.
- Unknown unicast can flood until the switch learns the destination.
- Duplicate MACs or loops can make traffic flap.
- Spanning Tree Protocol exists to prevent Layer 2 loops.

## VLANs

A VLAN is a separate Layer 2 broadcast domain. Two hosts in different VLANs need routing to talk to each other, even if they are plugged into the same physical switch.

Port types:

| Port Type | Behavior |
| --- | --- |
| Access port | Carries one untagged VLAN to an endpoint that does not tag frames. |
| Trunk port | Carries multiple VLANs using 802.1Q tags. |
| Native VLAN | Untagged VLAN on a trunk; useful but easy to misconfigure. |

802.1Q tagging inserts a VLAN identifier into Ethernet frames on trunks. A host or hypervisor can also use VLAN subinterfaces such as `eth0.100` when it needs to tag frames itself.

DHCP depends on the VLAN boundary. A client Discover broadcast only reaches the DHCP server or relay in the same VLAN. If a host lands in the wrong access VLAN, if a trunk does not allow the VLAN, or if the native VLAN is wrong, the client may receive no lease or a lease from the wrong scope.

Switch features such as DHCP snooping, port security, and storm control can also affect DHCP. Snooping is useful because it blocks rogue DHCP servers on untrusted ports, but a missing trusted uplink or relay port can drop legitimate offers.

## Linux Bridges and VLANs

Linux bridges behave like software switches. They are common with virtualization, containers, Kubernetes nodes, and lab networks.

```bash
ip link add link eth0 name eth0.100 type vlan id 100
ip link set eth0.100 up
ip link add br100 type bridge
ip link set eth0.100 master br100
bridge vlan show
```

On Ubuntu Server, persistent VLAN and bridge configuration is commonly handled through Netplan, which then renders systemd-networkd or NetworkManager configuration.

## /etc/hosts

`/etc/hosts` maps IP addresses to names locally. It is usually checked before DNS, depending on `/etc/nsswitch.conf`. Use `getent hosts <name>` instead of only `dig` when you want to test the system name-service path that applications often use.

Example:

```text
192.0.2.10 api.internal api
2001:db8::10 api6.internal
```

Gotchas:

- `dig` queries DNS and ignores `/etc/hosts`.
- `getent hosts` follows NSS configuration and can include `/etc/hosts`.
- A stale hosts entry can override correct DNS.
- Containers may have generated `/etc/hosts` files that differ from the host.
- Changing `/etc/hosts` does not update external DNS or other machines.

## Troubleshooting Flow

1. Confirm link state and MAC addresses.
2. Confirm access port VLAN or trunk allowed VLANs.
3. Confirm whether frames are tagged or untagged where expected.
4. Confirm Linux bridge membership and VLAN filtering.
5. Confirm ARP or IPv6 neighbor discovery works within the VLAN.
6. For DHCP failures, check relay/helper address, DHCP snooping trust, and whether offers return on the same VLAN.
7. Confirm routing exists between VLANs if crossing Layer 3.
8. Use `getent hosts` to check local host-file and NSS behavior before DNS-only tests.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does a switch learn from?" answer="Source MAC addresses in Ethernet frames, mapping them to switch ports." %}
  {% include study-card.html question="What is a VLAN?" answer="A separate Layer 2 broadcast domain, often carried over shared switch infrastructure." %}
  {% include study-card.html question="Why can a VLAN mistake break DHCP?" answer="DHCP Discover starts as local broadcast, so the client must be in the VLAN that has the expected server or relay." %}
  {% include study-card.html question="Why use getent hosts instead of dig for /etc/hosts checks?" answer="getent follows the system name-service path, while dig queries DNS and ignores /etc/hosts." %}
</div>

## References

- [hosts(5) Linux manual page](https://man7.org/linux/man-pages/man5/hosts.5.html)
- [IEEE 802.1Q VLANs](https://www.ieee802.org/1/pages/802.1Q.html)
- [Linux bridge command reference](https://man7.org/linux/man-pages/man8/bridge.8.html)
