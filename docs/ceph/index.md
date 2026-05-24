---
title: Ceph
layout: page
permalink: /docs/ceph/
summary: "Ceph distributed storage architecture, RADOS, OSDs, monitors, managers, pools, placement groups, CRUSH, CephFS, RBD, RGW, and operations."
tags:
  - ceph
  - storage
  - distributed-systems
  - troubleshooting
---

# Ceph Storage and Management

Ceph is a distributed storage system that provides object, block, and file interfaces on top of RADOS, the Reliable Autonomic Distributed Object Store. The core idea is that clients and daemons cooperate through cluster maps instead of relying on one central storage controller for every IO.

## Architecture

| Component | Role |
| --- | --- |
| MON | Maintains cluster maps, quorum, and authoritative cluster state. |
| MGR | Provides manager modules, metrics, dashboard, orchestration, and operational interfaces. |
| OSD | Stores data, replicates or erasure-codes objects, recovers data, scrubs, and reports health. |
| MDS | Manages CephFS metadata when CephFS is used. |
| RGW | Provides S3-compatible and Swift-compatible object gateways. |
| RBD | Provides block devices backed by RADOS objects. |
| CephFS | Provides a POSIX-like shared filesystem backed by RADOS and MDS. |

## RADOS, Pools, and Placement Groups

Objects are stored in pools. Pools define placement-group count, replication or erasure coding, and CRUSH rules. Placement groups (PGs) shard a pool so Ceph can track object placement and recovery at a practical granularity.

CRUSH maps PGs to OSDs based on a topology-aware rule. This lets Ceph place data across hosts, racks, zones, device classes, or other failure domains without a single lookup service for every object.

## Client IO Path

Ceph clients do not send every read and write through a central controller. A client gets cluster maps from monitors, uses CRUSH to calculate where data should live, and talks to the relevant OSDs.

Simplified RADOS write path:

1. Client identifies the pool and object.
2. CRUSH maps the object to a placement group.
3. The placement group maps to an acting OSD set.
4. The client sends the operation to the primary OSD for that PG.
5. The primary coordinates replica or erasure-coded writes with peer OSDs.
6. Acknowledgement depends on pool durability settings and OSD state.

This is why MON quorum can be required for cluster map changes while normal client IO is primarily OSD-facing once maps are known.

## Replication and Erasure Coding

Pools choose a durability strategy:

| Strategy | How It Works | Tradeoff |
| --- | --- | --- |
| Replicated pool | Stores full copies on multiple OSDs. | Simple recovery and good small-write behavior at higher raw-capacity cost. |
| Erasure-coded pool | Splits data into data and parity chunks. | Better raw-capacity efficiency, but more CPU/network work and more complex small writes. |

Failure-domain choice matters as much as copy count. Three replicas on three OSDs in one host do not protect against host loss. CRUSH rules should match the real risk boundary: host, rack, zone, device class, or another topology level.

## Health and State

```bash
ceph -s
ceph health detail
ceph osd tree
ceph osd df tree
ceph pg stat
ceph pg dump_stuck
ceph df
```

`HEALTH_OK` means Ceph currently sees no health warnings. `HEALTH_WARN` and `HEALTH_ERR` require reading `ceph health detail`, because the right response differs for degraded PGs, full OSDs, monitor quorum loss, slow ops, failed daemons, clock skew, or scrub errors.

## Capacity and Full Ratios

Ceph needs free space to recover, backfill, and rebalance. A cluster that is technically below raw capacity can still fail writes if one OSD, pool, or CRUSH subtree becomes full.

Watch:

- OSD utilization skew,
- nearfull/backfillfull/full ratios,
- pool quotas,
- device class capacity,
- misplaced and degraded objects,
- recovery and backfill throttling.

## Scrubbing and Repair

OSDs scrub objects to detect inconsistencies. Deep scrubs compare object data and checksums. Do not run repair blindly; identify the affected PG, OSDs, and object risk first.

```bash
ceph health detail
ceph pg <pgid> query
ceph pg deep-scrub <pgid>
ceph osd perf
```

## Operations Runbook

1. Start with `ceph -s` and `ceph health detail`.
2. Check quorum and manager availability.
3. Check OSD tree, OSD fullness, and down/out state.
4. Check PG states: `active+clean`, `degraded`, `undersized`, `peering`, `backfilling`, `stale`, or `inconsistent`.
5. Check client-facing interfaces: RBD, CephFS, or RGW.
6. Before maintenance, set only the flags you need and remember to unset them.
7. During recovery, watch whether health is improving or stuck.

```bash
ceph versions
ceph mon stat
ceph mgr stat
ceph osd stat
ceph osd blocked-by
ceph tell osd.* version
ceph orch ps
```

## Rook-Ceph

Rook runs Ceph inside Kubernetes with an operator. See [Rook-Ceph](rook-ceph/) for the Kubernetes-native model, CRDs, CSI integration, upgrades, and troubleshooting.

## Practice Deck

{% include study-card-deck.html deck="ceph" %}

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why do Ceph clients need cluster maps?" answer="Clients use maps plus CRUSH to calculate where objects live and then talk to the relevant OSDs." %}
  {% include study-card.html question="Why is MON quorum different from normal client IO?" answer="Monitors maintain authoritative cluster state, while normal mapped IO is primarily between clients and OSDs." %}
  {% include study-card.html question="Why does the CRUSH failure domain matter?" answer="Replicas or erasure-coded chunks must land across real failure boundaries such as hosts, racks, or zones." %}
  {% include study-card.html question="Why can a Ceph cluster need free space during recovery?" answer="Backfill and rebalance need room to move data; a nearly full cluster can get stuck or reject writes." %}
</div>

## References

- [Ceph architecture documentation](https://docs.ceph.com/en/latest/architecture/)
- [Ceph data placement overview](https://docs.ceph.com/en/latest/rados/operations/data-placement/)
- [Ceph health checks](https://docs.ceph.com/en/latest/rados/operations/health-checks/)
- [Ceph placement groups](https://docs.ceph.com/en/latest/rados/operations/placement-groups/)
- [Ceph CRUSH maps](https://docs.ceph.com/en/latest/rados/operations/crush-map/)
