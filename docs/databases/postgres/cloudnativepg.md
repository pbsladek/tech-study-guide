---
title: CloudNativePG
layout: page
permalink: /docs/databases/postgres/cloudnativepg/
summary: How CloudNativePG runs PostgreSQL in Kubernetes, including clusters, services, failover, backups, and operational cautions.
tags:
  - postgres
  - cloudnativepg
  - kubernetes
  - databases
---

# CloudNativePG

CloudNativePG is a Kubernetes operator for PostgreSQL. It introduces a `Cluster` custom resource and uses Kubernetes reconciliation to operate PostgreSQL instances, replicas, services, failover, rolling updates, and backup integration.

Do not think of it as "PostgreSQL magically becomes stateless." It is still PostgreSQL with WAL, storage, replication, and restore requirements. The operator automates common lifecycle work around those realities.

## Core Model

A typical CloudNativePG cluster has:

- one primary PostgreSQL instance,
- zero or more hot standby replicas,
- one Pod per instance,
- PVC-backed storage for each instance,
- Services for read-write and read-only access,
- operator-managed failover and reconciliation.

Common service pattern:

| Service | Target |
| --- | --- |
| `cluster-rw` | Current primary for reads and writes. |
| `cluster-ro` | Hot standby replicas for read-only traffic. |
| `cluster-r` | Any instance for read-only-capable traffic, depending on configuration. |

Application connection strings should use the operator-managed Services, not hard-coded Pod names.

## Why Operators Matter

PostgreSQL needs actions that depend on database state:

- bootstrap a primary,
- create replicas from base backups,
- stream WAL,
- promote a replica,
- reconfigure the former primary,
- expose the current primary consistently,
- coordinate rolling updates,
- run backups and restores.

A generic StatefulSet cannot safely encode all of that logic by itself. The operator watches the desired `Cluster` resource and actual database state, then performs PostgreSQL-aware reconciliation.

## Storage Design

CloudNativePG recommends a shared-nothing architecture. Each PostgreSQL instance should have its own storage and ideally run on a different Kubernetes worker node and availability zone.

Operational implications:

- Use anti-affinity or topology spread to avoid placing all instances on one node.
- Understand the StorageClass reclaim policy.
- Prefer storage with predictable latency.
- Do not put primary and replicas on the same failure domain.
- Test node failure and volume attachment behavior.

## Failover and Switchover

Failover is unplanned: the primary is unhealthy, and the operator promotes a suitable replica. Switchover is planned: you intentionally move primary role to another instance, usually for maintenance.

Key tradeoff:

- Lower RTO favors faster promotion.
- Lower RPO favors ensuring the promoted replica has all committed WAL.

Synchronous replication can reduce data-loss risk but adds write latency and can reduce availability if not designed carefully.

## Backups and PITR

CloudNativePG supports physical backup workflows and WAL archiving. Current documentation describes backup methods including plugin-based backup, volume snapshots, and legacy Barman object-store integration. Starting with the 1.26 era, native backup/recovery capabilities have been progressively moving toward CNPG-I plugins, with the Barman Cloud Plugin as the official object-store path.

Backup rules:

- Have scheduled base backups.
- Archive WAL continuously.
- Monitor archive failures.
- Test restore into a new cluster.
- Know the RPO/RTO target.
- Back up from a standby when possible to reduce primary IO impact.

## Rolling Updates

The operator can roll through instances, usually updating replicas first and handling the primary last through restart or switchover strategy. Still check:

- PostgreSQL image compatibility,
- extension compatibility,
- operator version notes,
- backup freshness,
- application connection pooling behavior,
- PodDisruptionBudgets and node capacity.

Major PostgreSQL upgrades are a separate database lifecycle problem. Treat them as migrations with rehearsals, rollback planning, and restore validation.

## Minimal Cluster Shape

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: app-db
spec:
  instances: 3
  storage:
    size: 100Gi
```

This is intentionally minimal. Production clusters need explicit resources, affinity, backup configuration, monitoring, image version policy, and restore runbooks.

## Troubleshooting

```bash
kubectl get clusters.postgresql.cnpg.io
kubectl describe cluster app-db
kubectl get pods,pvc,svc -l cnpg.io/cluster=app-db
kubectl logs deployment/cnpg-controller-manager -n cnpg-system
kubectl cnpg status app-db
```

Check in this order:

1. `Cluster` conditions.
2. Operator logs.
3. Pod readiness and PostgreSQL logs.
4. PVC binding and volume attachment.
5. WAL archiving status.
6. Replication lag.
7. Service endpoints for `-rw` and `-ro`.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What Kubernetes resource represents a CloudNativePG database cluster?" answer="A Cluster custom resource in the postgresql.cnpg.io API group." %}
  {% include study-card.html question="Why should apps use the -rw Service?" answer="It tracks the current primary, so applications do not need to know which Pod currently accepts writes." %}
  {% include study-card.html question="Does CloudNativePG remove the need for backups?" answer="No. It can orchestrate backup integration, but you still need base backups, WAL archiving, monitoring, and tested restores." %}
  {% include study-card.html question="What is the difference between failover and switchover?" answer="Failover is unplanned promotion after primary failure; switchover is a planned role change for maintenance or operations." %}
  {% include study-card.html question="Why prefer separate nodes or zones for PostgreSQL instances?" answer="To avoid one node, disk, or zone failure taking down the primary and its replicas together." %}
</div>

## References

- [CloudNativePG architecture](https://cloudnative-pg.io/documentation/1.27/architecture/)
- [CloudNativePG cloud native overview](https://cloudnative-pg.io/info/cloud-native/)
- [CloudNativePG backup documentation](https://cloudnative-pg.io/docs/1.27/backup)
- [Barman Cloud Plugin concepts](https://cloudnative-pg.io/plugin-barman-cloud/docs/0.11.0/concepts/)
