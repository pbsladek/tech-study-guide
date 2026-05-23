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

## Implementations

- [PostgreSQL](postgres/)
- [PostgreSQL Operations, HA, Replication, and Recovery](postgres/operations-ha/)
- [PgBouncer](postgres/pgbouncer/)
- [CloudNativePG](postgres/cloudnativepg/)
- [OpenSearch Operations, Replication, Sharding, and HA](opensearch/)
