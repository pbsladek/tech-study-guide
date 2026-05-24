---
title: Foundational Study Review
layout: page
permalink: /docs/foundational-study-review/
summary: "A cross-topic checklist for reviewing whether the guide covers the core mental models behind Linux, networking, DNS, Kubernetes, identity, databases, Ceph, Istio, and troubleshooting."
tags:
  - study
  - fundamentals
  - troubleshooting
  - operations
---

# Foundational Study Review

This page is the gap-review map for the study guide. It does not replace the topic pages; it checks whether the guide teaches the mental models a person needs before they debug production systems.

For concrete manifests, configs, SQL, scripts, and command patterns across the same topic areas, use [Practical Examples](/docs/practical-examples/).

## Review Criteria

A topic is not solid just because it lists commands. Each topic should answer:

| Criterion | What Good Coverage Includes |
| --- | --- |
| Mental model | The objects, actors, boundaries, and state transitions. |
| Data path | How real work moves through the system. |
| Control path | Which controller, daemon, protocol, or operator changes state. |
| Failure modes | Common ways the system fails and how symptoms appear. |
| Observability | Commands, logs, metrics, events, and status fields that prove state. |
| Safety | What not to do during incidents, especially with data, identity, and distributed state. |
| Cross-links | Neighboring concepts that explain why a local symptom may have a remote cause. |

## Topic Coverage Matrix

| Area | Must-Know Concepts | Primary Pages |
| --- | --- | --- |
| Linux | Processes, syscalls, files, mounts, memory, cgroups, namespaces, systemd, storage, boot, users, scheduled jobs, backups. | [Linux](/docs/linux/), [Processes and Threads](/docs/linux/processes-threads/), [Containerization, OCI, and VMs](/docs/linux/containerization-oci-vms/), [Backup and File Transfer](/docs/linux/backup-transfer-rsync-scp-snapshots/) |
| Networking | Encapsulation, L2/L3/L4/L7 boundaries, route lookup, neighbor lookup, NAT, conntrack, MTU, TLS, proxies, load balancers. | [Networking](/docs/networking/), [Packet Path](/docs/networking/packet-path/), [NAT Gateways and NAT](/docs/networking/nat-gateways/), [Certificates and HTTPS](/docs/networking/certificates-https/) |
| DNS | Stub resolvers, recursive resolvers, authoritative servers, delegation, glue, TTLs, negative caching, DNSSEC, split-horizon views. | [DNS](/docs/dns/), [Resolution and Caching](/docs/dns/resolution-caching/), [Authoritative Zones](/docs/dns/authoritative-zones/), [DNSSEC and Privacy](/docs/dns/dnssec-privacy/) |
| Kubernetes | API machinery, reconciliation, controllers, scheduling, kubelet, CRI/CNI/CSI, probes, Services, DNS, storage, upgrades, operators. | [Kubernetes](/docs/kubernetes/), [Core Concepts](/docs/kubernetes/core-concepts/), [Networking](/docs/kubernetes/networking/), [Storage and Upgrades](/docs/kubernetes/storage-upgrades/) |
| Identity | Authentication vs authorization, IdPs, sessions, cookies, OAuth, OIDC, SAML, JWT validation, JWKS rotation, token lifetime. | [Identity and Access](/docs/identity/), [IdP, SAML, JWT, OAuth, and OIDC](/docs/identity/auth-protocols/) |
| Databases | Data modeling, indexes, transactions, isolation, locking, WAL, backups, replication, pooling, sharding, snapshots, restore drills. | [Databases](/docs/databases/), [PostgreSQL](/docs/databases/postgres/), [PostgreSQL Operations and HA](/docs/databases/postgres/operations-ha/), [OpenSearch](/docs/databases/opensearch/) |
| Ceph | RADOS, OSDs, MON quorum, MGR, pools, PGs, CRUSH, replication, erasure coding, scrub, recovery, fullness, Rook integration. | [Ceph](/docs/ceph/), [Rook-Ceph](/docs/ceph/rook-ceph/) |
| Istio | Control plane, data plane, Envoy, xDS, sidecar mode, ambient mode, mTLS, identity, routing, policy, telemetry. | [Istio](/docs/istio/), [Istio Service Mesh](/docs/istio/service-mesh/) |
| Troubleshooting | Incident framing, evidence preservation, layers, dependency isolation, retries, timeouts, rollback, recovery, post-incident learning. | [Troubleshooting and Error Handling](/docs/troubleshooting/) |

## Big 101 Gaps To Keep Closed

These are the gaps that most often prevent a solid understanding:

- Confusing data plane and control plane. A controller may be healthy while packets fail, or packets may keep flowing while the API is down.
- Treating DNS as one lookup. Real DNS includes local host files, NSS, stub resolvers, recursive caches, authoritative delegation, negative caching, and sometimes split-horizon policy.
- Treating Kubernetes as a command runner. Kubernetes writes desired state, then independent controllers reconcile it over time.
- Treating TLS certificates as only files. Trust depends on chain building, hostname validation, EKU/key usage, SNI, time, revocation policy, and client CA stores.
- Treating JWT decoding as validation. Claims are untrusted until issuer, audience, signature, algorithm, expiry, and policy are checked.
- Treating RAID, replication, snapshots, and backups as interchangeable. Each protects against different failures and has different restore behavior.
- Treating retries as harmless. Retries need timeouts, backoff, jitter, idempotency, and a total budget.
- Treating distributed storage as a local disk. Ceph, PostgreSQL HA, OpenSearch, and Kubernetes storage all have quorum, placement, and recovery mechanics.

## Review Pass By Area

Use this as a periodic checklist when adding new pages:

1. **Linux:** Can the reader explain what the kernel sees: tasks, FDs, pages, mounts, namespaces, cgroups, sockets, and devices?
2. **Networking:** Can the reader trace one request through name resolution, route lookup, neighbor lookup, NAT, TCP or UDP, TLS, proxying, and response path?
3. **DNS:** Can the reader distinguish authoritative truth from recursive cache and local resolver behavior?
4. **Kubernetes:** Can the reader name the controller responsible for the next state transition and where that controller reports failure?
5. **Identity:** Can the reader separate browser session, ID token, access token, refresh token, and local authorization decision?
6. **Databases:** Can the reader connect query latency and correctness to transactions, locks, indexes, WAL, storage, replication, and backups?
7. **Ceph:** Can the reader explain how CRUSH maps objects to OSDs and why fullness or degraded PGs change client behavior?
8. **Istio:** Can the reader separate Kubernetes Service selection from mesh routing, mTLS, authorization policy, and Envoy/xDS config?
9. **Troubleshooting:** Can the reader preserve evidence, narrow scope, test one layer at a time, and choose a safe rollback or recovery action?

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What makes a study topic complete enough for operations?" answer="It explains the mental model, data path, control path, failure modes, observability, safety boundaries, and neighboring concepts." %}
  {% include study-card.html question="Why separate data plane from control plane?" answer="The system that forwards traffic or IO can fail independently from the system that configures it." %}
  {% include study-card.html question="What is the danger of relying only on commands?" answer="Commands show evidence, but without a model of ownership and state transitions it is easy to misread symptoms." %}
  {% include study-card.html question="Why are backups, snapshots, RAID, and replication different?" answer="They protect against different failures and only backups plus tested restores prove recoverability from deletion or corruption." %}
</div>
