---
title: Rook-Ceph
layout: page
permalink: /docs/ceph/rook-ceph/
summary: "Rook-Ceph architecture, CephCluster CRD, Kubernetes storage classes, CSI, toolbox usage, upgrades, and troubleshooting."
tags:
  - ceph
  - rook
  - kubernetes
  - storage
---

# Rook-Ceph

Rook-Ceph is an operator-driven way to run Ceph on Kubernetes. Kubernetes owns scheduling and lifecycle primitives, while Rook translates custom resources into Ceph daemons, configuration, storage classes, and operational workflows.

## Control Model

| Layer | Responsibility |
| --- | --- |
| Rook operator | Watches CRDs and reconciles Ceph daemons and config. |
| `CephCluster` | Defines cluster-wide Ceph version, placement, storage selection, monitoring, dashboard, and health policy. |
| `CephBlockPool` | Defines a RADOS pool for RBD-backed block volumes. |
| `CephFilesystem` | Defines CephFS metadata and data pools plus MDS daemons. |
| `CephObjectStore` | Defines RGW object storage. |
| Ceph CSI | Provisions and attaches RBD and CephFS volumes for Kubernetes workloads. |
| Toolbox | Debug pod for running `ceph` and related commands. |

## Storage Selection

Rook can consume raw host devices, host paths for labs, PVC-backed storage, or an external Ceph cluster. Production clusters need explicit decisions about device selection, failure domain, placement, resource requests, and upgrade policy.

```bash
kubectl -n rook-ceph get cephcluster
kubectl -n rook-ceph describe cephcluster rook-ceph
kubectl -n rook-ceph get pods -o wide
kubectl -n rook-ceph get cephblockpool,cephfilesystem,cephobjectstore
kubectl get storageclass
```

## CSI and StorageClasses

Applications normally consume Rook-Ceph through Kubernetes PVCs. The StorageClass points at the Rook provisioner and the backing Ceph pool or filesystem.

Troubleshooting path:

1. PVC pending or attach failing.
2. Check StorageClass parameters.
3. Check CSI provisioner, node plugin, and attacher logs.
4. Verify the backing Ceph pool or filesystem exists.
5. Use the toolbox for `ceph -s`, `ceph osd lspools`, and `ceph fs ls`.

## Toolbox

```bash
kubectl -n rook-ceph get deploy rook-ceph-tools
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph -s
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
```

The toolbox is often the fastest bridge between Kubernetes symptoms and Ceph state.

## Upgrades

Rook upgrades the Ceph daemons in a rolling pattern after the Ceph image is changed in the `CephCluster` spec. Rook checks conditions between daemon updates, including monitor quorum and healthy PGs for OSD work.

Before upgrading:

- read the Rook upgrade notes for the exact Rook release,
- read the Ceph support matrix for the target Rook version,
- ensure `ceph -s` is healthy or consciously accept documented risk,
- confirm backups and restore procedures,
- verify CSI sidecar compatibility and application disruption tolerance.

## Troubleshooting Runbook

```bash
kubectl -n rook-ceph get pods -o wide
kubectl -n rook-ceph logs deploy/rook-ceph-operator
kubectl -n rook-ceph get cephcluster rook-ceph -o yaml
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph -s
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph health detail
kubectl -n rook-ceph get events --sort-by=.lastTimestamp
kubectl get pvc,pv,volumeattachment --all-namespaces
```

Common split:

- Kubernetes problem: Pods unscheduled, devices not mounted, CSI pods failing, permissions, taints, or node drains.
- Rook reconciliation problem: operator cannot create/update daemon deployments or config.
- Ceph problem: quorum, OSD down/full, PG unhealthy, pool missing, MDS unhealthy, RGW down.
- Application problem: PVC mounted but app cannot use filesystem, permissions, or expected path.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does the Rook operator reconcile?" answer="Rook Ceph custom resources into Ceph daemons, configuration, services, and Kubernetes storage integration." %}
  {% include study-card.html question="What does CephCluster define?" answer="Cluster-wide Ceph settings such as version, placement, storage selection, dashboard, monitoring, and upgrade behavior." %}
  {% include study-card.html question="Why is the toolbox useful?" answer="It gives operators a pod with Ceph CLI access for checking cluster health from inside Kubernetes." %}
  {% include study-card.html question="What usually provisions Rook-Ceph PVCs?" answer="Ceph CSI drivers for RBD block volumes or CephFS shared filesystems." %}
  {% include study-card.html question="Why must PG health be considered during upgrades?" answer="OSD upgrades and restarts are safer when placement groups are healthy and data is not already degraded." %}
</div>

## References

- [Rook CephCluster CRD](https://rook.io/docs/rook/latest/CRDs/Cluster/ceph-cluster-crd/)
- [Rook Ceph CSI drivers](https://rook.io/docs/rook/latest-release/Storage-Configuration/Ceph-CSI/ceph-csi-drivers/)
- [Rook toolbox](https://rook.io/docs/rook/latest-release/Troubleshooting/ceph-toolbox/)
- [Rook Ceph common issues](https://rook.io/docs/rook/latest-release/Troubleshooting/ceph-common-issues/)
- [Rook Ceph upgrades](https://rook.io/docs/rook/latest/Upgrade/ceph-upgrade/)
