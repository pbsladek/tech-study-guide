---
title: DHCP, Routers, and Switches
layout: page
permalink: /docs/networking/dhcp-routers-switches/
summary: "DHCP-focused networking guide covering DORA, leases, options, default gateways, DNS options, relay agents, helper addresses, Option 82, VLANs, switches, routers, DHCP snooping, DHCPv6, and troubleshooting."
tags:
  - networking
  - dhcp
  - routing
  - switching
  - troubleshooting
---

# DHCP, Routers, and Switches

DHCP is where Layer 2, Layer 3, routing, DNS, and security policy meet during host startup. A client with no IP address must discover configuration on the local link. Switches decide which broadcast domain the request lives in, routers decide whether relay is needed, and the DHCP server returns the address, lease, gateway, DNS, and other options the host will use.

## First Checks

```bash
ip addr
ip route
resolvectl status 2>/dev/null || cat /etc/resolv.conf
journalctl -b -u systemd-networkd -u NetworkManager --no-pager
tcpdump -ni <interface> 'udp port 67 or udp port 68'
dhclient -v -r <interface> 2>/dev/null || true
dhclient -v <interface> 2>/dev/null || true
```

Use these from the affected client or a span/mirror point on the same VLAN. DHCP is broadcast-heavy at first, so captures from the wrong VLAN or routed side can miss the actual failure.

## DHCPv4 Flow

The common initial DHCPv4 exchange is DORA:

| Step | Direction | Meaning |
| --- | --- | --- |
| Discover | Client to broadcast | Client asks for DHCP servers because it may not have an address. |
| Offer | Server to client | Server offers an address and options. |
| Request | Client to server or broadcast | Client requests one offered address and identifies the chosen server. |
| ACK | Server to client | Server commits the lease and sends final configuration. |

After a lease is active, renewal usually becomes unicast between client and server. If renewal fails, the client later rebroadcasts during rebinding. This difference matters: a new client may fail because broadcast or relay is broken, while an already-leased client keeps working until renewal or rebinding.

## Options That Shape the Host

DHCP is not just IP assignment. Options tell the host how to behave after it gets the address.

| Option | Common Name | Operational Meaning |
| --- | --- | --- |
| 1 | Subnet mask | Defines the local IPv4 subnet. Wrong masks make hosts ARP for remote addresses or route local traffic incorrectly. |
| 3 | Router | Default gateway. Missing or wrong values cause "has IP but cannot leave subnet." |
| 6 | DNS servers | Recursive resolvers the client should use. |
| 15 | Domain name | Local DNS suffix/domain. |
| 42 | NTP servers | Time source for clients that honor it. |
| 51 | IP address lease time | Lease lifetime. Too short increases churn; too long slows recovery from mistakes. |
| 53 | DHCP message type | Discover, Offer, Request, ACK, NAK, and related message kind. |
| 54 | Server identifier | Identifies the DHCP server selected by the client. |
| 55 | Parameter request list | Options the client asks the server to return. |
| 66 / 67 | TFTP server / bootfile | Common in PXE or network boot workflows. |
| 82 | Relay agent information | Relay-added metadata such as circuit ID and remote ID. |
| 121 | Classless static routes | Specific routes beyond the default gateway. |

Option mistakes create clean-looking but broken clients. A host can have a valid lease and still be unusable because the router option points to the wrong gateway, DNS points to an unreachable resolver, or classless routes steer traffic incorrectly.

## Routers and DHCP Relay

DHCPv4 Discover starts as broadcast. Routers do not forward ordinary broadcasts between subnets, so a DHCP server outside the client VLAN requires a relay agent. On many network devices this is configured as a helper address.

DHCP relay behavior:

- The relay receives a client broadcast on a VLAN interface.
- It forwards the request as unicast to one or more DHCP servers.
- It sets `giaddr` so the server knows which client subnet or scope to use.
- It may add Option 82 with circuit or remote identity.
- It relays the server reply back to the client VLAN.

If DHCP works on the server VLAN but not on another VLAN, suspect helper address, relay reachability, scope selection, firewall policy, or Option 82 handling before blaming the client.

Router-related DHCP failures:

| Symptom | Likely Cause |
| --- | --- |
| No offers on one VLAN | Missing helper/relay, wrong VLAN SVI, ACL blocking UDP 67/68. |
| Offer from wrong pool | Relay `giaddr`, shared-network/scope config, or Option 82 mapping wrong. |
| Client gets IP but wrong gateway | DHCP Option 3 wrong for that subnet. |
| Client gets IP but DNS fails | Option 6 wrong, unreachable resolver, split DNS mismatch. |
| Renewals work but new leases fail | Broadcast or relay path broken, existing clients renewing unicast. |

## Switches and VLAN Boundaries

Switches determine the broadcast domain. DHCP Discover only reaches DHCP servers or relays inside that VLAN. That makes switch configuration part of DHCP correctness.

Switch checks:

- Is the endpoint on the expected access VLAN?
- Is the trunk carrying the VLAN to the router or DHCP server?
- Is the native VLAN mismatch causing untagged frames to land in the wrong network?
- Is a Linux bridge or hypervisor tagging traffic as expected?
- Are port security, storm control, or DHCP snooping dropping DHCP packets?

DHCP snooping is a common enterprise switch feature. It marks ports as trusted or untrusted, blocks server replies from untrusted access ports, and can build a binding table used by features such as dynamic ARP inspection. Misconfigured snooping can make the real DHCP server look silent.

## Lease State and Address Conflicts

Leases are state. The server thinks an address belongs to a client for a time, the client may remember an old lease, and the network may still have ARP/neighbor cache entries.

Common lease issues:

- pool exhausted,
- stale reservation points to the wrong MAC or client identifier,
- duplicate static IP inside the DHCP pool,
- client identifier changes after OS reinstall, NIC change, PXE boot, or virtualization change,
- short leases overload server/relay paths,
- long leases preserve bad options after a configuration mistake.

When debugging conflicts, compare the DHCP server lease record, the client identifier, the MAC address, switch MAC table, ARP table, and any IPAM source of truth.

## DHCPv6, SLAAC, and Router Advertisements

IPv6 configuration is different. Router Advertisements are central: they announce default router information and prefixes. SLAAC can let hosts form addresses from advertised prefixes. DHCPv6 can provide addresses, other configuration, or prefix delegation, but it does not replace Router Advertisements for default gateway discovery in the usual host model.

Important distinctions:

| Mechanism | Provides |
| --- | --- |
| Router Advertisement | Default router, prefixes, lifetimes, flags, and sometimes DNS information depending on environment. |
| SLAAC | Host address formation from advertised prefixes. |
| Stateless DHCPv6 | Extra options such as DNS or NTP without assigning addresses. |
| Stateful DHCPv6 | DHCPv6-assigned addresses and options. |
| Prefix delegation | Delegates a prefix to a downstream router. |

Do not assume DHCPv4 habits map directly onto IPv6. A DHCPv6 server can be healthy while hosts still fail because Router Advertisements are missing, filtered, or advertising the wrong flags/prefixes.

## Troubleshooting Flow

1. Identify the client interface, VLAN, MAC address, and expected subnet.
2. Capture DHCP packets on the client VLAN.
3. Check whether Discover leaves the client and whether Offer returns.
4. If no Offer returns, check switch VLAN, trunk, DHCP snooping, relay/helper address, and firewall policy.
5. If Offer returns but Request/ACK fails, check server identifier, client identifier, relay path, and lease state.
6. If lease succeeds but traffic fails, check options: subnet mask, router, DNS, classless routes, MTU, and domain suffix.
7. Compare server lease records, IPAM, ARP, switch MAC table, and logs.
8. For IPv6, check Router Advertisements before assuming DHCPv6 is the source of truth.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What are the four common DHCPv4 DORA steps?" answer="Discover, Offer, Request, and ACK." %}
  {% include study-card.html question="Why does DHCP need relay across subnets?" answer="Initial DHCPv4 discovery uses local broadcast, and routers do not forward ordinary broadcasts between subnets." %}
  {% include study-card.html question="What does DHCP Option 3 provide?" answer="The default router or gateway for the client subnet." %}
  {% include study-card.html question="What can DHCP snooping block?" answer="DHCP server replies from untrusted switch ports, protecting clients from rogue DHCP servers but breaking DHCP if trust is wrong." %}
  {% include study-card.html question="Why is DHCPv6 not just DHCPv4 with bigger addresses?" answer="IPv6 hosts usually depend on Router Advertisements for default router and prefix behavior, with DHCPv6 providing address or extra options depending on design." %}
</div>

## References

- [RFC 2131: Dynamic Host Configuration Protocol](https://www.rfc-editor.org/rfc/rfc2131)
- [RFC 2132: DHCP Options and BOOTP Vendor Extensions](https://www.rfc-editor.org/rfc/rfc2132)
- [RFC 3046: DHCP Relay Agent Information Option](https://www.rfc-editor.org/rfc/rfc3046)
- [RFC 8415: DHCP for IPv6](https://www.rfc-editor.org/rfc/rfc8415)
- [RFC 4861: Neighbor Discovery for IPv6](https://www.rfc-editor.org/rfc/rfc4861)
- [tcpdump(8)](https://www.tcpdump.org/manpages/tcpdump.1.html)
