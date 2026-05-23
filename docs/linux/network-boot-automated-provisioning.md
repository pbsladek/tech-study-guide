---
title: Network Boot and Automated Provisioning
layout: page
permalink: /docs/linux/network-boot-automated-provisioning/
summary: "PXE, UEFI HTTP Boot, iPXE, DHCP, TFTP, automated Linux installs, Ubuntu autoinstall, cloud-init NoCloud, Kickstart, bare-metal provisioning, and troubleshooting."
tags:
  - linux
  - boot
  - networking
  - provisioning
  - automation
---

# Network Boot and Automated Provisioning

Network booting lets a machine start without local install media. Automated provisioning builds on that: firmware gets a boot program from the network, the boot program loads an installer kernel and initrd, and the installer fetches a declarative answer file that partitions disks, installs packages, configures users, and hands off to first-boot automation.

## First Checks

```bash
tcpdump -ni <interface> 'port 67 or port 68 or port 69 or port 80 or port 4011'
journalctl -u isc-dhcp-server -u dnsmasq -u tftpd-hpa --no-pager
curl -fsS http://<boot-server>/boot.ipxe
curl -fsS http://<boot-server>/autoinstall/user-data
ls -l /srv/tftp /var/lib/tftpboot /var/www/html
```

## Boot Flow

| Stage | What Happens | Common Protocol |
| --- | --- | --- |
| Firmware network boot | NIC firmware starts PXE, UEFI PXE, or UEFI HTTP Boot. | DHCP, PXE, HTTP |
| Address and boot metadata | Client asks for IP, next server, and boot filename or URL. | DHCP options, ProxyDHCP |
| Network boot program | Firmware downloads a small bootloader such as PXELINUX, GRUB EFI, or iPXE. | TFTP, HTTP |
| Installer kernel/initrd | Bootloader downloads kernel, initrd, and boot parameters. | HTTP preferred, sometimes TFTP/NFS |
| Answer file | Installer fetches autoinstall, Kickstart, preseed, or cloud-init data. | HTTP/HTTPS |
| OS install | Installer partitions disks, installs packages, writes bootloader, and reboots. | HTTP mirror, package repo |
| First boot | cloud-init, systemd units, config management, or agent enrollment completes the node. | HTTP APIs, SSH, package repos |

TFTP is simple and widely supported by firmware, but it is slow and fragile for large payloads. A common pattern is to use PXE/TFTP only to load iPXE or GRUB, then use HTTP for the kernel, initrd, ISO, and configuration.

## DHCP, PXE, and ProxyDHCP

Classic PXE depends on DHCP-like information:

- client IP address,
- gateway and DNS,
- boot server,
- boot filename,
- sometimes architecture-specific bootloader selection.

Common DHCP options:

| Option | Meaning |
| --- | --- |
| 66 | TFTP server name. |
| 67 | Bootfile name. |
| 93 | Client architecture, useful for BIOS versus UEFI loader selection. |
| 60 | Vendor class identifier, often used to detect PXE or iPXE clients. |
| 43 | Vendor-specific options. |

ProxyDHCP is useful when the network already has a DHCP server that should keep owning IP address assignment. A separate PXE service answers only boot metadata, often on UDP 4011, while the normal DHCP server still assigns addresses.

Avoid hard-coding one bootloader for every machine. BIOS PXE, x86_64 UEFI, ARM UEFI, Secure Boot, and iPXE may need different files.

## iPXE

iPXE is a network boot firmware and bootloader that can be chainloaded from ordinary PXE. Its practical advantage is scriptability and better protocol support, especially HTTP.

Minimal iPXE script:

```ipxe
#!ipxe
dhcp
kernel http://boot.example.com/ubuntu/vmlinuz ip=dhcp autoinstall ds=nocloud-net;s=http://boot.example.com/autoinstall/node-01/
initrd http://boot.example.com/ubuntu/initrd
boot
```

More production-friendly scripts usually:

- detect `${mac}`, `${serial}`, `${asset}`, or `${uuid}`,
- choose a profile from an inventory service,
- retry DHCP or HTTP cleanly,
- present a short timeout menu for rescue tools,
- chain to local disk after provisioning,
- avoid infinite reinstall loops.

Example shape:

```ipxe
#!ipxe
dhcp || goto shell
set base http://boot.example.com
chain ${base}/profiles/${serial}.ipxe || chain ${base}/profiles/default.ipxe || goto shell

:shell
echo Boot profile not found for ${serial}
shell
```

## Ubuntu Autoinstall and cloud-init

Modern Ubuntu Server automated installs use Subiquity autoinstall data, commonly delivered through cloud-init NoCloud or NoCloud-Net.

Typical kernel parameters:

```text
autoinstall ds=nocloud-net;s=http://boot.example.com/autoinstall/node-01/
```

The NoCloud directory commonly contains:

| File | Purpose |
| --- | --- |
| `user-data` | Autoinstall and cloud-init configuration. |
| `meta-data` | Instance identity metadata. |
| `vendor-data` | Optional vendor defaults. |

Autoinstall controls storage layout, packages, identity, SSH keys, late commands, and handoff behavior. Treat the file as infrastructure code. Review disk selectors carefully: automated installs can wipe the wrong disk if serial matching, size matching, or install target logic is loose.

## Kickstart, Preseed, and Other Installers

Red Hat-family systems commonly use Kickstart with Anaconda. Debian historically used preseed; newer workflows often prefer cloud images, curtin, or installer-specific automation. The idea is the same: boot a small installer environment, pass it a URL, and let the installer consume a declarative answer file.

Kickstart-style kernel parameter examples often include a network source and Kickstart URL:

```text
inst.repo=http://boot.example.com/rhel/9/BaseOS inst.ks=http://boot.example.com/kickstart/node-01.ks
```

Keep installer media, repositories, and answer-file syntax aligned with the OS release. A working RHEL 8 Kickstart or Ubuntu 22.04 autoinstall can fail subtly on a newer major release.

## Inventory-Driven Provisioning

Automated network installs become safer when tied to inventory:

| Identifier | Use |
| --- | --- |
| MAC address | Early boot matching; can change with NIC replacement or LOM settings. |
| SMBIOS serial | Useful physical-server identity if vendor data is reliable. |
| Asset tag | Human-friendly physical inventory key. |
| BMC/IPMI address | Out-of-band power and console control. |
| Disk serial | Safer storage selection than `/dev/sda`. |
| TPM or platform identity | Stronger attestation in advanced environments. |

A provisioning system should know whether a node is allowed to install, which OS profile it should use, which disks it may wipe, which network it should join after install, and how it enrolls into config management.

## Preventing Reinstall Loops

Network boot is powerful enough to destroy data repeatedly. Design explicit brakes:

- provision only hosts marked installable in inventory,
- chain to local disk after successful install,
- change the iPXE profile state after first boot,
- use BMC one-time boot instead of permanent network-first boot when possible,
- require a short menu timeout for destructive install paths,
- gate destructive storage profiles by serial or asset tag,
- keep rescue tools separate from install automation.

## Secure Boot, Secrets, and Trust

Security-sensitive points:

- UEFI Secure Boot may reject unsigned EFI binaries or bootloaders.
- Answer files often contain password hashes, SSH keys, tokens, or enrollment secrets.
- Plain HTTP on an untrusted provisioning network can be modified in transit.
- DHCP spoofing or rogue PXE services can redirect hosts.
- Installer logs can preserve secrets unless redacted.

Mitigations include isolated provisioning VLANs, DHCP snooping, signed bootloaders, short-lived enrollment tokens, HTTPS where firmware/tooling supports it, per-node secrets, and wiping installer logs or avoiding secret material in answer files.

## Troubleshooting

| Symptom | Likely Area | Checks |
| --- | --- | --- |
| No PXE prompt | Firmware boot order, NIC PXE support, link/VLAN. | BMC console, switch port, link light, VLAN, UEFI boot settings. |
| Gets IP but no boot file | DHCP options, ProxyDHCP, architecture matching. | Packet capture, DHCP logs, option 66/67/93, dnsmasq tags. |
| Downloads bootloader but kernel fails | TFTP/HTTP path, wrong architecture, Secure Boot. | Web logs, TFTP logs, file names, EFI binary type. |
| Installer starts interactive | Missing or malformed autoinstall/Kickstart URL. | Kernel command line, HTTP 404, cloud-init logs, installer logs. |
| Wrong disk wiped | Loose storage selector or device name assumption. | Match by serial/by-id, review generated storage config. |
| Installed system cannot boot | Bootloader target, UEFI entry, ESP, root disk, RAID/LVM/initramfs. | BMC console, rescue boot, `efibootmgr`, mount layout. |
| First boot never enrolls | DNS, CA trust, time, proxy, token, config-management agent. | cloud-init logs, network config, `/var/log/installer`, journal. |

Debug from the wire first. DHCP/PXE bugs are easiest to see with packet capture because firmware logs are often thin or hidden behind BMC console output.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does PXE need from the network?" answer="An address plus boot metadata such as a boot server and boot filename, usually through DHCP or ProxyDHCP." %}
  {% include study-card.html question="Why chainload iPXE?" answer="Firmware PXE can load iPXE, then iPXE can use scripts and HTTP to fetch larger boot assets and per-node profiles." %}
  {% include study-card.html question="What does Ubuntu autoinstall usually consume?" answer="Subiquity autoinstall data delivered through cloud-init, often via the NoCloud-Net datasource." %}
  {% include study-card.html question="Why is disk selection dangerous in automated installs?" answer="Loose selectors such as /dev/sda can wipe the wrong device; serial or by-id matching is safer." %}
  {% include study-card.html question="How do you prevent network reinstall loops?" answer="Use inventory state, one-time boot, chain to local disk after install, and require explicit install profiles." %}
</div>

## References

- [iPXE documentation](https://ipxe.org/docs)
- [iPXE scripting](https://ipxe.org/scripting)
- [Ubuntu autoinstall documentation](https://canonical-subiquity.readthedocs-hosted.com/en/latest/intro-to-autoinstall.html)
- [cloud-init NoCloud datasource](https://cloudinit.readthedocs.io/en/latest/reference/datasources/nocloud.html)
- [Red Hat Kickstart documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/automatically_installing_rhel/index)
- [UEFI Specification](https://uefi.org/specifications)
