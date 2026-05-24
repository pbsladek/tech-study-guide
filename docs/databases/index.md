---
title: Databases
layout: page
permalink: /docs/databases/
summary: Database fundamentals, modeling, indexes, transactions, replication, and operations.
tags:
  - databases
  - storage
  - operations
---

# Databases

Database fundamentals and implementation-specific notes.

## Core Mental Model

A database is both a data model and a durability engine. It accepts logical operations such as queries and transactions, then turns them into page reads, page writes, logs, locks, cache behavior, replication streams, and recovery decisions.

The major questions:

| Question | Concept |
| --- | --- |
| What shape should the data have? | Modeling, normalization, constraints, document shape, index strategy. |
| What does one change mean? | Transaction boundaries, ACID, isolation level, conflict handling. |
| How does the system find rows or documents? | Indexes, statistics, query planner, shard routing. |
| What survives a crash? | WAL, fsync, checkpoints, snapshots, replicas, restore process. |
| What happens under concurrency? | Locks, MVCC, version conflicts, deadlocks, backpressure. |
| What happens when a node dies? | Replication, leader election, quorum, failover, recovery, client routing. |

## Learning Path

Study databases in layers. Each layer explains a different class of production failure:

1. Data model: tables, documents, constraints, identifiers, cardinality, and ownership.
2. Query path: indexes, statistics, planner choices, scans, sorts, joins, shard routing, and caches.
3. Concurrency: transaction boundaries, isolation, locks, MVCC, retries, and idempotency.
4. Durability: WAL or transaction log, fsync, checkpoints, snapshots, backups, and restore tests.
5. Distribution: replication, leader election, quorum, shard placement, failover, and client routing.
6. Operations: observability, capacity, vacuum or compaction, schema changes, connection pools, and incident runbooks.

The useful student habit is to translate a symptom into the layer that can produce it. Slow reads are often query path or storage; duplicate writes are often transaction and retry design; data loss questions are durability and restore design; partial outage questions are distribution and client routing.

## Outline

- Data modeling and normalization.
- Indexes and query planning.
- Transactions, isolation levels, locking, and MVCC.
- Storage layout, drive behavior, RAID tradeoffs, write durability, and recovery.
- Replication, backups, restores, and high availability.
- Search clusters, shard allocation, replica placement, and failover.
- Observability and performance troubleshooting.

## Storage and Performance

Databases translate storage choices into user-visible latency. PostgreSQL is sensitive to WAL sync latency, checkpoint writeback, temporary files, and planner cost assumptions. OpenSearch and Elasticsearch are sensitive to local disk latency, filesystem cache, Lucene segment merges, shard recovery, and snapshot strategy.

For drive types, RAID 0/1/5/6/10, striping, mirroring, disk-failure recovery, rebuild risk, PostgreSQL settings, and Elasticsearch node layout, see [Storage Drives, RAID, and Database Performance](../linux/storage-drives-raid-database-performance/).

## Transactions, Indexes, and Durability

Relational systems such as PostgreSQL use transactions to group changes into atomic units. ACID is the shorthand:

| Property | Practical Meaning |
| --- | --- |
| Atomicity | The transaction commits as a unit or rolls back as a unit. |
| Consistency | Constraints and invariants are preserved when transactions commit. |
| Isolation | Concurrent transactions see controlled views of each other. |
| Durability | Committed changes survive crash according to the configured durability model. |

Indexes speed reads by maintaining extra data structures, commonly B-trees. They also add write cost because inserts, updates, and deletes may need to update every affected index. A missing index can cause scans and high latency; too many indexes can slow writes, bloat storage, and increase maintenance work.

Backups are not complete until restore is tested. Replication helps availability and read scaling, but it can replicate bad writes, corruption, or deletes. Snapshots help point-in-time capture only when consistency and restore ordering are understood.

## Choosing the Right Tool Shape

| Need | Common Fit | Watch Out For |
| --- | --- | --- |
| Strong relational invariants and transactions | PostgreSQL or another relational database. | Bad schema and missing indexes can still make it slow. |
| Text search, log search, faceting, relevance scoring | OpenSearch or Elasticsearch-style search cluster. | It is not a relational source of truth; shard and snapshot design matter. |
| Short-lived cache or coordination primitive | Redis-style cache or key-value store. | Cache invalidation, persistence mode, and memory pressure are product decisions. |
| File or object storage | Filesystem, object store, or distributed storage such as Ceph. | Metadata, consistency, access control, and restore behavior differ from databases. |

Do not pick a system only because it can store the shape of data. Pick it based on the invariants, query path, write path, failure model, operational skill, and restore target.

## Implementations

- [PostgreSQL](postgres/)
- [PostgreSQL Operations, HA, Replication, and Recovery](postgres/operations-ha/)
- [PgBouncer](postgres/pgbouncer/)
- [CloudNativePG](postgres/cloudnativepg/)
- [OpenSearch Operations, Replication, Sharding, and HA](opensearch/)

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is a database both a data model and a durability engine?" answer="It defines logical structure while also deciding how writes, logs, caches, replication, and recovery protect that structure." %}
  {% include study-card.html question="Why are indexes not free?" answer="They speed selected reads but add write cost, storage, maintenance, and planner complexity." %}
  {% include study-card.html question="Why is replication not the same as backup?" answer="Replication can copy deletes, bad writes, and corruption; backups need independent retention and tested restore." %}
  {% include study-card.html question="What is a good first question for database troubleshooting?" answer="Which layer is failing: model, query path, concurrency, durability, distribution, or operations?" %}
</div>

## References

- [PostgreSQL tutorial](https://www.postgresql.org/docs/current/tutorial.html)
- [PostgreSQL backup and restore](https://www.postgresql.org/docs/current/backup.html)
- [OpenSearch shard allocation](https://docs.opensearch.org/latest/tuning-your-cluster/availability-and-recovery/shard-allocation/)
- [OpenSearch snapshots](https://docs.opensearch.org/latest/tuning-your-cluster/availability-and-recovery/snapshots/index/)
