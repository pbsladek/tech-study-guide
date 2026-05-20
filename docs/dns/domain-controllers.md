---
title: Domain Controllers and Directory DNS
layout: page
permalink: /docs/dns/domain-controllers/
summary: How Active Directory domain controllers depend on DNS SRV records, Kerberos, LDAP, Global Catalog, replication, and time.
tags:
  - dns
  - identity
  - networking
---

# Domain Controllers and Directory DNS

A domain controller, sometimes abbreviated as Domain Controller or DC in runbooks, is an identity authority for a directory domain. In Microsoft Active Directory Domain Services (AD DS), domain controllers authenticate users and computers, issue Kerberos tickets through the Key Distribution Center (KDC), serve LDAP directory data, replicate directory partitions, and apply domain policy.

The operational surprise is how much of AD DS depends on DNS. Clients do not usually know a domain controller by a hard-coded IP. They ask DNS for SRV records that advertise LDAP, Kerberos, Global Catalog, and site-specific domain controller locations.

## What Domain Controllers Provide

| Function | Why It Matters |
| --- | --- |
| Authentication | Users and computers prove identity, commonly through Kerberos. |
| LDAP directory | Applications and machines query users, groups, computers, and policies. |
| Group Policy | Domain-joined Windows machines receive centrally managed policy. |
| Replication | Domain controllers converge directory state across sites. |
| DNS registration | DCs publish service locator records that clients use to find them. |
| Global Catalog | Selected DCs hold a partial forest-wide index for searches and logons. |

Domain controllers are not just "Windows DNS servers." DNS may run on the same hosts, and AD-integrated zones are common, but the DC role is about identity, authentication, directory state, and replication.

## DNS-Based Discovery

Windows DC locator uses DNS-based discovery for modern AD domains. A client asks for SRV records, receives candidate domain controllers, then contacts candidates using LDAP-style discovery and normal authentication protocols. Microsoft recommends DNS-based discovery over legacy NetBIOS-based discovery; Windows Server 2025 blocks NetBIOS-style DC location by default unless policy explicitly allows it.

Records operators should recognize:

| Record | Purpose |
| --- | --- |
| `_ldap._tcp.<domain>` | LDAP service for the domain. |
| `_ldap._tcp.dc._msdcs.<domain>` | Domain controllers for the domain. |
| `_kerberos._tcp.<domain>` | Kerberos KDCs for the domain. |
| `_kerberos._udp.<domain>` | UDP Kerberos service, where still allowed. |
| `_ldap._tcp.gc._msdcs.<forest-root>` | Global Catalog servers for the forest. |
| `_ldap._tcp.<site>._sites.dc._msdcs.<domain>` | Domain controllers in a specific Active Directory site. |

The `_msdcs` namespace is special because it carries Microsoft directory service locator records. If `_msdcs` delegation, replication, or dynamic registration is wrong, domain join, logon, Group Policy, and application LDAP discovery can fail even while ordinary A records resolve.

## Ports and Protocols

Firewalls around domain controllers need more than TCP 443. Common flows include:

| Protocol | Default Ports | Use |
| --- | --- | --- |
| DNS | UDP/TCP 53 | Service discovery and dynamic DNS updates. |
| Kerberos | TCP/UDP 88 | Authentication and ticket-granting. |
| LDAP | TCP/UDP 389 | Directory queries and DC locator LDAP pings. |
| LDAPS | TCP 636 | LDAP over TLS. |
| Global Catalog | TCP 3268 / 3269 | Forest-wide catalog queries, with 3269 for TLS. |
| SMB | TCP 445 | SYSVOL, NETLOGON, policy, and file access. |
| RPC endpoint mapper | TCP 135 | RPC service discovery. |
| Dynamic RPC | TCP 49152-65535 by default on modern Windows | Replication and management flows unless constrained. |

This is why "DNS works but domain join fails" is common. The SRV records can resolve, but Kerberos, LDAP, SMB, or RPC may still be blocked.

## Time and Kerberos

Kerberos is time-sensitive. If a client, domain controller, or virtualization host drifts too far, authentication can fail with misleading credential or trust errors. In AD DS, the PDC Emulator FSMO role in the forest root is usually the top internal time authority, and other domain members follow the domain time hierarchy.

Treat time sync as identity infrastructure:

- monitor NTP or Windows Time status,
- avoid conflicting hypervisor and guest time settings,
- check clock skew before resetting passwords or rejoining machines,
- remember that TLS, Kerberos, certificates, and logs all depend on sane time.

## Replication, Sites, and Roles

Multiple domain controllers improve availability only when replication and client location are healthy.

| Concept | Why It Matters |
| --- | --- |
| AD sites | Map subnets to physical or network locations so clients prefer nearby DCs. |
| Replication topology | Controls how directory changes flow between DCs and sites. |
| FSMO roles | Special operations roles, including PDC Emulator, RID Master, Infrastructure Master, Schema Master, and Domain Naming Master. |
| Read-only domain controller | A DC designed for less trusted sites, with limited writable secrets. |
| Global Catalog | A DC role that answers forest-wide searches and helps with universal group membership. |

DNS discovery and sites are linked. If subnet-to-site mapping is missing, clients may authenticate against distant DCs or Global Catalog servers, causing slow logons and fragile application behavior.

## Dynamic DNS and DHCP

Domain-joined machines and domain controllers commonly use secure dynamic updates to keep A, PTR, and SRV records current. DHCP can also register records for clients, depending on policy.

Watch for these failure patterns:

- stale A/PTR records after rebuilds or IP reuse,
- duplicate names from cloned machines,
- DHCP registering records with the wrong credentials,
- non-Microsoft DNS zones that allow SRV records but not secure dynamic update behavior,
- scavenging settings that remove live records or retain dead ones too long.

## Failure Modes

| Symptom | Likely Cause | Check |
| --- | --- | --- |
| Domain join cannot find a DC | Client uses the wrong DNS resolver or SRV records are missing. | `ipconfig /all`, `_ldap._tcp.dc._msdcs`, and DNS server scope. |
| Logons are slow across sites | Missing AD subnet mapping or site-specific SRV records. | AD Sites and Services, site SRV records, and client site name. |
| Kerberos errors with valid passwords | Kerberos clock skew, SPN mismatch, or trust issue. | `w32tm /query /status`, event logs, SPNs. |
| Group Policy fails | SYSVOL/NETLOGON, SMB, DFSR, or replication issue. | `dcdiag`, `repadmin`, and SYSVOL state. |
| Some DCs give old data | Replication failure or lingering stale records. | `repadmin /replsummary` and SOA/zone replication. |
| Linux clients cannot discover the realm | DNS search path, SRV lookup, Kerberos realm, or SSSD config mismatch. | `realm discover`, `dig SRV`, `kinit`, and `/etc/resolv.conf`. |
| Applications fail LDAP over TLS | Certificate name, CA trust, LDAPS port, or channel binding requirements. | TLS chain, SAN, port 636, and application logs. |

## Commands

```bash
dig _ldap._tcp.dc._msdcs.example.com SRV
dig _kerberos._tcp.example.com SRV
dig example.com SOA
nslookup -type=SRV _ldap._tcp.dc._msdcs.example.com
nltest /dsgetdc:example.com
dcdiag /test:dns
```

More checks for Windows and mixed environments:

```bash
dcdiag /test:dns /v
repadmin /replsummary
repadmin /showrepl
nltest /dsgetsite
w32tm /query /status
realm discover example.com
kinit user@example.com
ldapsearch -H ldap://dc01.example.com -b dc=example,dc=com
```

## Troubleshooting Flow

1. Confirm the client is using domain DNS resolvers, not a public resolver.
2. Query `_ldap._tcp.dc._msdcs.<domain>` and `_kerberos._tcp.<domain>` from the affected client network.
3. Confirm returned DC names have A/AAAA records and are reachable on DNS, Kerberos, LDAP, SMB, and RPC paths.
4. Check client site mapping so the client prefers a local DC or Global Catalog.
5. Check clock skew before treating errors as bad passwords.
6. Check DC health and replication with `dcdiag` and `repadmin`.
7. Check stale DNS records, duplicate machine names, and secure dynamic update failures.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is a domain controller?" answer="An identity authority for a directory domain that handles authentication, directory access, policy, and replication." %}
  {% include study-card.html question="Why do AD clients depend on DNS SRV records?" answer="They use SRV records to discover domain controllers, Kerberos KDCs, LDAP services, Global Catalog servers, and site-local targets." %}
  {% include study-card.html question="What is _msdcs used for?" answer="It is the Microsoft directory-services DNS namespace that holds important domain controller locator records." %}
  {% include study-card.html question="Why does Kerberos care about time?" answer="Kerberos tickets are time-bound, so excessive clock skew can make valid credentials fail." %}
  {% include study-card.html question="What does the Global Catalog provide?" answer="A partial forest-wide index used for searches and some logon scenarios, especially across domains." %}
</div>

## References

- [Microsoft Learn: Locating Active Directory Domain Controllers](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/dc-locator)
- [Microsoft Learn: Verify SRV DNS records for Active Directory](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/verify-srv-dns-records-have-been-created)
- [Microsoft Learn: Service overview and network port requirements](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/service-overview-and-network-port-requirements)
- [Microsoft Learn: Windows Time service](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/how-the-windows-time-service-works)
- [Microsoft Learn: FSMO roles](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-fsmo-roles)
- [Microsoft Learn: Active Directory Domain Services overview](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview)
