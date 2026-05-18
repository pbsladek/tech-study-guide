---
title: Kubernetes Storage and Upgrades
layout: page
permalink: /docs/kubernetes/storage-upgrades/
summary: Persistent storage, CSI, StatefulSets, volume lifecycle, and safe Kubernetes upgrade practices.
tags:
  - kubernetes
  - storage
  - csi
  - upgrades
---

# Kubernetes Storage and Upgrades

Storage and upgrades are where Kubernetes stops being purely declarative and starts touching durable state. Treat both as operational workflows with backups, sequencing, and rollback plans.

## Storage Building Blocks

| Object | Meaning |
| --- | --- |
| Volume | A mounted storage source in a Pod spec. Some are ephemeral, some are persistent. |
| PersistentVolume | A cluster-scoped storage resource. It has capacity, access modes, reclaim policy, and implementation details. |
| PersistentVolumeClaim | A namespaced request for storage. Pods mount PVCs, not arbitrary PVs. |
| StorageClass | Defines dynamic provisioning behavior and storage parameters. |
| VolumeSnapshot | Snapshot API object when a snapshot controller and CSI support exist. |

PVs and PVCs decouple application YAML from infrastructure implementation. A developer asks for "20Gi fast storage"; the platform decides which backend provides it.

## CSI

CSI is the Container Storage Interface. Kubernetes uses it to integrate storage systems without baking vendor-specific volume plugins into core Kubernetes.

Typical CSI components:

- **Controller plugin:** provisions, deletes, attaches, detaches, expands, and snapshots volumes.
- **Node plugin:** stages and publishes volumes on nodes so Pods can mount them.
- **External sidecars:** provisioner, attacher, resizer, snapshotter, health monitor depending on driver features.

Operational lesson: CSI driver compatibility matters. Kubernetes may support an API, but the driver and sidecars must support the exact feature and version combination.

## Access Modes

| Mode | Meaning |
| --- | --- |
| `ReadWriteOnce` | Read-write by a single node. Multiple Pods can use it if co-located on that node. |
| `ReadOnlyMany` | Read-only by many nodes. |
| `ReadWriteMany` | Read-write by many nodes if the backend supports it. |
| `ReadWriteOncePod` | Read-write by a single Pod; stable in Kubernetes v1.29 for CSI volumes. |

Do not assume `ReadWriteMany` is available. Many block storage systems only support single-node attachment.

## StatefulSets

StatefulSets provide stable identity:

- predictable Pod names,
- ordered rollout behavior,
- stable PVCs through `volumeClaimTemplates`,
- stable DNS when paired with a headless Service.

They do not make the application safe. PostgreSQL, Kafka, etcd, and similar systems still need application-level replication, quorum, backup, and recovery logic.

## Reclaim Policies

Reclaim policy controls what happens to the PV after its PVC is deleted:

- `Delete`: delete the backing volume through the provisioner.
- `Retain`: keep the backing volume for manual recovery or cleanup.

For databases, understand reclaim policy before running cleanup automation. Accidentally deleting PVCs with a `Delete` policy can delete the underlying disk.

## Kubernetes Upgrades

The safe high-level upgrade sequence is:

1. Read release notes, deprecations, API removals, and add-on compatibility.
2. Back up `etcd` and application data.
3. Check version skew policy for API server, kubelet, kubeadm, kubectl, controller manager, scheduler, and add-ons.
4. Upgrade one primary control plane node.
5. Upgrade additional control plane nodes.
6. Upgrade worker nodes in controlled batches.
7. Upgrade CNI, CSI, CoreDNS, ingress/gateway controllers, and cloud controllers as required by their compatibility matrices.
8. Verify workloads, DNS, Service routing, admission webhooks, storage attach/mount, and node readiness.

For kubeadm clusters, skipping minor versions is unsupported. Move one minor at a time and stay on supported release lines.

## Upgrade Risks

| Risk | Why It Matters | Mitigation |
| --- | --- | --- |
| API removal | Old manifests or controllers fail. | Run deprecation scans before upgrade. |
| Webhook failure | Admission can block creates/updates. | Ensure webhook availability and timeouts. |
| CNI incompatibility | Pods cannot get IPs or route traffic. | Validate CNI support for target Kubernetes. |
| CSI incompatibility | Volumes fail to attach or mount. | Validate sidecars and driver versions. |
| CoreDNS drift | Service discovery breaks. | Test internal DNS before and after. |
| PDB constraints | Drains hang. | Review PodDisruptionBudgets and capacity. |

## Commands

```bash
kubectl get pv,pvc,storageclass,volumesnapshotclass
kubectl describe pvc <claim>
kubectl get volumeattachment
kubeadm upgrade plan
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What object does a Pod normally mount for persistent storage?" answer="A PersistentVolumeClaim. The PVC binds to a PersistentVolume that represents actual storage." %}
  {% include study-card.html question="Why is CSI important?" answer="It lets Kubernetes integrate storage systems through a standard interface instead of embedding vendor-specific plugins in core Kubernetes." %}
  {% include study-card.html question="Why are minor-version skips unsafe for kubeadm upgrades?" answer="kubeadm enforces version skew policy and expects sequential minor upgrades so component configuration and manifests can migrate safely." %}
  {% include study-card.html question="What must be checked after a storage-related upgrade?" answer="CSI sidecars, volume attachments, PVC binding, mount behavior, snapshots, and application-level data safety." %}
</div>

## References

- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Kubernetes Storage](https://kubernetes.io/docs/concepts/storage/)
- [Upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
