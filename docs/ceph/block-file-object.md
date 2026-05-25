---
title: Ceph Block, File, and Object Interfaces
layout: page
permalink: /docs/ceph/block-file-object/
summary: "RBD, CephFS, and RGW mental models, command checks, snapshots, mirroring, MDS behavior, bucket gateways, and interface selection."
tags:
  - ceph
  - rbd
  - cephfs
  - rgw
---

# Ceph Block, File, and Object Interfaces

Ceph exposes the same RADOS storage substrate through three common user-facing shapes: block devices with RBD, shared filesystems with CephFS, and object storage with RGW.

## Interface Selection

| Interface | Best Fit | Watchouts |
| --- | --- | --- |
| RBD | VM disks, Kubernetes ReadWriteOnce volumes, database volumes, and block-like workloads. | Filesystem and application consistency still matter; snapshots are block-level unless coordinated. |
| CephFS | Shared POSIX-like filesystems, ReadWriteMany Kubernetes volumes, shared build or media paths. | Metadata workload depends on healthy MDS daemons and sane directory layout. |
| RGW | S3-compatible buckets, object APIs, backups, artifacts, and application object storage. | S3 semantics are not POSIX; bucket listing, lifecycle, versioning, and multisite need separate design. |

## RBD

RBD images are striped across RADOS objects. A client maps an image as a block device through the kernel client or `rbd-nbd`, then the host or container puts a filesystem, database, or raw block consumer on top.

```bash
rbd pool init <pool>
rbd create <pool>/<image> --size 100G
rbd info <pool>/<image>
rbd status <pool>/<image>
rbd snap create <pool>/<image>@before-change
rbd snap ls <pool>/<image>
rbd du <pool>/<image>
rbd perf image iostat
```

RBD snapshots are crash-consistent unless the application and filesystem are quiesced. For databases, combine storage snapshots with database-aware checkpoints or backup tooling. RBD mirroring can replicate images between clusters for disaster recovery, but failover and split-brain handling must be rehearsed.

## CephFS

CephFS separates file data from metadata. File data is stored in RADOS pools. Metadata operations such as directory traversal, file creation, rename, and inode updates are served by MDS daemons.

```bash
ceph fs ls
ceph fs status
ceph mds stat
ceph fs dump
ceph fs subvolume ls <fs-name>
ceph fs subvolume snapshot ls <fs-name> <subvolume>
```

CephFS performance issues often show up as metadata latency, hot directories, overloaded active MDS daemons, slow clients, or full data pools. Scaling MDS can help metadata concurrency, but directory layout and workload shape still matter.

## RGW

RGW provides S3-compatible and Swift-compatible APIs backed by RADOS pools. RGW is a gateway tier, so client health depends on both Ceph cluster health and gateway capacity, load balancer behavior, DNS, TLS, and authentication.

```bash
radosgw-admin user list
radosgw-admin user info --uid <uid>
radosgw-admin bucket stats --bucket <bucket>
radosgw-admin bucket list
radosgw-admin sync status
ceph orch ps --daemon_type rgw
```

For multisite, understand realms, zonegroups, zones, periods, and sync state before treating a second site as a recovery target. Object versioning and lifecycle policies help with some user mistakes, but they are not a substitute for tested backups.

## Kubernetes Mapping

Rook-Ceph commonly exposes:

- RBD through a block StorageClass for `ReadWriteOnce` volumes,
- CephFS through a filesystem StorageClass for `ReadWriteMany` volumes,
- RGW through object bucket claims or direct S3 credentials.

When a pod cannot use storage, split the problem into Kubernetes scheduling and attachment, CSI driver behavior, Ceph interface health, and the underlying OSD or pool state.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="When is RBD a good fit?" answer="When a workload expects a block device, such as VM disks, database volumes, or Kubernetes ReadWriteOnce storage." %}
  {% include study-card.html question="What does the CephFS MDS handle?" answer="Filesystem metadata such as directories, inodes, file creation, rename, and namespace operations." %}
  {% include study-card.html question="What does RGW provide?" answer="S3-compatible and Swift-compatible object APIs backed by RADOS pools." %}
  {% include study-card.html question="Why are RBD snapshots not automatically application-consistent?" answer="They capture block state unless the filesystem and application are quiesced or coordinated." %}
  {% include study-card.html question="Why troubleshoot CSI and Ceph separately?" answer="A PVC issue may be Kubernetes attachment, CSI provisioning, interface health, or underlying RADOS health." %}
</div>

## References

- [Ceph Block Device](https://docs.ceph.com/en/latest/rbd/)
- [CephFS](https://docs.ceph.com/en/latest/cephfs/)
- [Ceph Object Gateway](https://docs.ceph.com/en/latest/radosgw/)
- [RBD mirroring](https://docs.ceph.com/en/latest/rbd/rbd-mirroring/)
- [CephFS administration](https://docs.ceph.com/en/latest/cephfs/administration/)
