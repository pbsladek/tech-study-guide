---
title: Ceph Performance and Capacity
layout: page
permalink: /docs/ceph/performance-capacity/
summary: "Ceph performance model, capacity planning, BlueStore, OSD latency, network design, client behavior, benchmarks, and saturation troubleshooting."
tags:
  - ceph
  - performance
  - capacity
  - storage
---

# Ceph Performance and Capacity

Ceph performance is a distributed-system result, not a single disk benchmark. Client IO, primary OSD work, replica or erasure-coded writes, BlueStore, RocksDB, WAL, network, recovery, and scrub can all be in the hot path.

## Capacity Model

Raw capacity is not usable capacity. Replication, erasure coding, reserved free space, uneven placement, and failure domains all reduce safe usable space.

| Design | Capacity Shape | Operational Tradeoff |
| --- | --- | --- |
| 3x replicated | About one third raw before reserve. | Strong small-write behavior and simple recovery. |
| 2x replicated | About one half raw before reserve. | Lower safety margin; one failure away from no redundancy. |
| Erasure coding | Depends on data plus coding chunks. | Efficient for large objects, costlier small writes and recovery. |
| Device-class pools | Capacity limited by that class. | SSD pools can fill even when HDD pools have space. |

Plan capacity per failure domain. A cluster that survives one OSD loss may not survive a whole host or rack if CRUSH rules and free space do not match the expected failure.

## Latency Sources

| Area | What To Check |
| --- | --- |
| Client | IO depth, sync writes, filesystem, database checkpoints, mount options. |
| Network | RTT, packet loss, MTU mismatch, congestion, public versus cluster network. |
| OSD | Commit/apply latency, slow ops, full devices, CPU saturation, BlueStore compaction. |
| Pool | Replication size, erasure coding, PG count, hot objects, CRUSH skew. |
| Background work | Recovery, backfill, scrub, deep scrub, rebalancing. |

```bash
ceph osd perf
ceph osd df tree
ceph osd pool stats
ceph tell osd.* perf dump
ceph daemon osd.<id> perf dump
ceph health detail
```

## BlueStore and RocksDB

BlueStore stores object data directly on block devices and uses RocksDB for metadata. Small writes, omap-heavy workloads, RGW bucket indexes, and CephFS metadata can stress metadata paths even when raw disk throughput looks fine.

Operational checks:

- DB/WAL device placement and capacity,
- slow compactions,
- high commit/apply latency,
- device write cache and firmware behavior,
- discard/TRIM behavior on SSD-backed clusters,
- OSD memory target and cache pressure.

## Network Design

Ceph replication and recovery multiply network traffic. For write-heavy or recovery-heavy clusters, the network between OSDs can become the limiter before disks do.

Design questions:

- Are public client traffic and cluster replication traffic separated or shared?
- Can the network handle host failure recovery at acceptable speed?
- Are MTU and offload settings consistent end to end?
- Is there congestion or packet loss during recovery?
- Is latency acceptable across racks or zones for the chosen failure domain?

```bash
ceph osd perf
ceph -w
ss -tan state established
ip -s link
ethtool -S <interface>
```

## Benchmarking

Use benchmarks to compare changes, not to promise application performance. Run them away from production clients unless the risk is intentional.

```bash
rados bench -p <pool> 60 write --no-cleanup
rados bench -p <pool> 60 seq
rados bench -p <pool> 60 rand
rados cleanup -p <pool>
rbd bench <pool>/<image> --io-type write --io-size 4K --io-threads 16 --io-total 1G
```

For databases, test the real stack: filesystem, database settings, sync behavior, checkpoint pattern, and client concurrency. A fast RADOS benchmark does not guarantee low PostgreSQL `fsync` latency or low Elasticsearch merge latency.

## Saturation Runbook

1. Identify whether the symptom is latency, throughput, queueing, or availability.
2. Check `ceph -s` for recovery, scrub, full ratios, and slow ops.
3. Compare OSD latency and utilization across hosts and device classes.
4. Check whether one pool or client dominates IO.
5. Inspect network counters and packet loss.
6. Reduce background work only if durability risk is understood.
7. Add capacity, rebalance, or change workload placement only after confirming the bottleneck.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is raw Ceph capacity not usable capacity?" answer="Replication or erasure coding, reserve space, failure domains, and uneven placement reduce safe usable space." %}
  {% include study-card.html question="What can high OSD commit latency indicate?" answer="Storage, BlueStore, RocksDB, device, or queueing delays before writes are safely committed." %}
  {% include study-card.html question="Why can recovery hurt client performance?" answer="Recovery and backfill consume disk, CPU, and network resources that clients also need." %}
  {% include study-card.html question="Why benchmark the real database stack?" answer="RADOS or RBD microbenchmarks do not fully model filesystem, fsync, checkpoint, merge, and client behavior." %}
  {% include study-card.html question="Why plan capacity per device class?" answer="A pool restricted to one class can fill even when other classes still have free raw capacity." %}
</div>

## References

- [Ceph performance counters](https://docs.ceph.com/en/latest/dev/perf_counters/)
- [Ceph monitoring OSDs and PGs](https://docs.ceph.com/en/latest/rados/operations/monitoring-osd-pg/)
- [Ceph BlueStore configuration](https://docs.ceph.com/en/latest/rados/configuration/bluestore-config-ref/)
- [Ceph benchmark tools](https://docs.ceph.com/en/latest/rados/operations/benchmark/)
- [Ceph network configuration reference](https://docs.ceph.com/en/latest/rados/configuration/network-config-ref/)
