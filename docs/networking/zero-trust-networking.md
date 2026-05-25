---
title: Zero-Trust Networking
layout: page
permalink: /docs/networking/zero-trust-networking/
summary: "Network security patterns that combine host firewall policy, nftables, mTLS, certificate rotation, SNI, ALPN, service identity, SSH hardening, auditd, SELinux, AppArmor, and real traffic debugging."
tags:
  - networking
  - security
  - tls
  - linux
---

# Zero-Trust Networking

Zero-trust networking assumes network location is not enough proof of identity. A private subnet can still contain compromised workloads, stale credentials, open egress, or misrouted traffic. Strong designs combine service identity, encrypted transport, host policy, workload policy, audit evidence, and least privilege.

## First Checks

```bash
nft list ruleset
ss -ltnp
openssl s_client -connect api.example.com:443 -servername api.example.com -alpn h2,http/1.1
curl -vk --cert client.crt --key client.key --cacert ca.crt https://api.example.com/
journalctl -k -g 'DENIED|audit|apparmor|SELinux|DROP|REJECT'
```

## Host Firewall Baseline

A host firewall should make the allowed path explicit. This nftables example allows loopback, established flows, SSH from a management subnet, HTTPS from anywhere, ICMP for diagnostics, and rejects the rest.

```nft
table inet host_filter {
  chain input {
    type filter hook input priority 0; policy drop;

    iif lo accept
    ct state established,related accept
    ct state invalid drop

    ip saddr 192.0.2.0/24 tcp dport 22 accept
    tcp dport { 80, 443 } accept
    ip protocol icmp accept
    ip6 nexthdr ipv6-icmp accept

    limit rate 5/second log prefix "nft-drop-input: "
    reject
  }
}
```

Persist the rules with the distribution's supported mechanism and test out-of-band access before applying remote firewall changes.

## mTLS and Service Identity

mTLS authenticates both peers at the transport layer. It answers "which certificate-backed workload identity connected?" It does not replace authorization logic.

Identity checks can use:

- SPIFFE ID in URI SAN,
- DNS SAN for service names,
- certificate issuer or trust domain,
- Kubernetes service account identity through a mesh or workload identity system,
- client certificate subject only when the naming policy is controlled.

Common failure modes:

| Failure | Symptom |
| --- | --- |
| Client omits certificate | TLS alert or HTTP 401/403 depending on proxy behavior. |
| Wrong client CA | Handshake fails even though the server certificate is valid. |
| SNI mismatch | Proxy routes to the wrong certificate or backend. |
| ALPN mismatch | HTTP/2, gRPC, or h2c path fails while basic TCP works. |
| Proxy terminates TLS | Backend never sees the original client certificate unless identity is forwarded and trusted deliberately. |

## Zero-Trust Walkthrough

1. Host firewall allows only expected management and service ports.
2. Client validates server certificate chain, SAN, SNI, and ALPN.
3. Server validates client certificate against the client CA bundle.
4. Application or proxy maps SPIFFE-like identity, SAN, issuer, or service account to authorization policy.
5. auditd, proxy logs, and application logs record the identity and decision.
6. SELinux or AppArmor profiles restrict key files, sockets, and helper binaries.

```bash
nft list ruleset
openssl s_client -connect api.example.com:443 -servername api.example.com -alpn h2 -showcerts
curl -vk --cert client.crt --key client.key --cacert server-ca.pem https://api.example.com/
ausearch -m avc,user_avc,apparmor -ts recent
```

## Certificate Rotation

Rotation must overlap trust. A safe rotation normally has phases:

1. Add new trust root or intermediate to all validators.
2. Issue and deploy new leaf certificates.
3. Reload proxies and applications.
4. Verify served chains and client acceptance.
5. Remove old trust only after old leaves are gone and caches have aged out.

```bash
openssl x509 -in new-client.crt -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage
openssl verify -CAfile client-ca-bundle.pem -purpose sslclient new-client.crt
printf '' | openssl s_client -connect api.example.com:443 -servername api.example.com -alpn h2 -showcerts
```

## SSH and Administrative Access

Zero-trust for admin paths means SSH is not just "port 22 is open."

Baseline controls:

- disable password login where feasible,
- require per-user keys or short-lived certificates,
- use `AllowUsers`, `AllowGroups`, or Match blocks,
- keep host keys stable and monitored,
- log sudo and SSH events,
- restrict management source ranges with host firewall policy,
- use bastions or identity-aware access for high-risk networks.

## Linux Security Controls in Traffic Debugging

SELinux, AppArmor, seccomp, capabilities, and auditd can deny operations that look like network failures.

Examples:

```bash
aa-status
getenforce 2>/dev/null || true
ausearch -m avc,user_avc,apparmor -ts recent
getpcaps <pid>
grep Seccomp /proc/<pid>/status
```

If a service listens as root during startup and then drops privileges, capability or LSM policy can affect bind, raw sockets, transparent proxying, packet capture, or certificate file access.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does mTLS prove?" answer="That both peers presented certificates chaining to configured trust roots; authorization still needs policy." %}
  {% include study-card.html question="Why does certificate rotation need overlap?" answer="Validators must trust the new chain before peers start serving or presenting new certificates." %}
  {% include study-card.html question="Why can SELinux or AppArmor look like a network issue?" answer="Policy can deny binds, reads of key files, raw sockets, or proxy operations even when routes and ports are correct." %}
</div>

## References

- [Certificates and HTTPS](/docs/networking/certificates-https/)
- [Firewalls, iptables, and Netfilter](/docs/networking/firewalls-iptables-netfilter/)
- [Linux Security Controls](/docs/linux/security-controls/)
- [SSH Access](/docs/linux/ssh-access/)
