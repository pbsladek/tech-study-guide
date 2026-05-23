---
title: PostgreSQL Operations, HA, Replication, and Recovery
layout: page
permalink: /docs/databases/postgres/operations-ha/
summary: "Operational PostgreSQL guide covering HA managers, failover, streaming and logical replication, backups, restore drills, WAL, high CPU, high RAM, and incident checks."
tags:
  - postgres
  - databases
  - high-availability
  - replication
  - troubleshooting
---

# PostgreSQL Operations, HA, Replication, and Recovery

PostgreSQL availability is built from database mechanics plus an external management layer. PostgreSQL knows how to write WAL, stream WAL, recover from WAL, serve hot standbys, and promote a standby. A production HA system also needs leader election, fencing, connection routing, backup orchestration, monitoring, restore testing, and human-safe failover procedures.

## First Checks

```bash
psql -d <database> -c "SELECT pid, state, wait_event_type, wait_event, now() - query_start AS age, query FROM pg_stat_activity ORDER BY query_start NULLS LAST LIMIT 20;"
psql -d <database> -c "SELECT * FROM pg_stat_replication;"
psql -d <database> -c "SELECT slot_name, active, restart_lsn, wal_status FROM pg_replication_slots;"
psql -d <database> -c "SELECT * FROM pg_stat_archiver;"
psql -d <database> -c "SELECT checkpoints_timed, checkpoints_req, buffers_checkpoint FROM pg_stat_checkpointer;"
psql -d <database> -c "SELECT wal_records, wal_fpi, wal_bytes FROM pg_stat_wal;"
```

These checks separate live sessions, standby state, WAL retention, archive health, checkpoint pressure, and WAL generation. Pair them with host metrics for CPU, memory, IO, filesystem fullness, and cgroup limits.

## Managed HA Model

PostgreSQL does not become highly available just because it has a replica. A managed HA design needs clear ownership for:

| Concern | What Owns It |
| --- | --- |
| WAL generation and replay | PostgreSQL primary and standby processes. |
| Synchronous or asynchronous commit policy | PostgreSQL settings such as `synchronous_commit` and `synchronous_standby_names`. |
| Primary identity | HA manager, Kubernetes operator, cloud control plane, or runbook. |
| Promotion | `pg_ctl promote`, `pg_promote()`, or an HA controller calling the equivalent. |
| Fencing old primary | Infrastructure automation, storage fencing, Kubernetes deletion, or manual procedure. |
| Client routing | DNS, VIP, load balancer, PgBouncer, Kubernetes Service, or cloud endpoint. |
| Backup and restore | Backup tooling plus tested recovery runbooks. |

The dangerous failure is split brain: two writable primaries accepting divergent writes. Promotion must be paired with a plan to stop or fence the old primary before it can accept writes again. After promotion, PostgreSQL creates a new timeline, and remaining standbys must follow the right timeline or be rebuilt.

Think in RPO and RTO:

- **RPO:** how much committed data can be lost.
- **RTO:** how long the service can be unavailable.
- **Asynchronous replication:** better write availability and latency, possible data loss on failover.
- **Synchronous replication:** lower data-loss risk, higher write latency and possible write unavailability when required standbys are missing.

Synchronous replication is not one setting with one meaning. `synchronous_commit` controls how far a commit waits: local WAL flush, standby receipt, standby flush, or standby apply. Waiting for `remote_apply` gives stronger read-after-write behavior from synchronous standbys than waiting only for receipt, but it costs more latency. Quorum synchronous replication can require any selected number of standbys rather than one named standby. Design these settings around business RPO/RTO, not around the word "synchronous" by itself.

## Replication

Physical streaming replication sends WAL from primary to standby. A hot standby can serve read-only queries while replaying WAL, but it is still a copy of the primary's physical cluster, not an independent writable database.

Key pieces:

| Piece | Role |
| --- | --- |
| `wal_level` | Must be high enough for replication or logical decoding. |
| `primary_conninfo` | Standby connection string to the primary. |
| `standby.signal` | Marks a data directory as a standby on startup. |
| WAL sender | Primary-side process streaming WAL. |
| WAL receiver | Standby-side process receiving WAL. |
| Replication slot | Retains WAL until a standby or logical consumer has consumed it. |
| `wal_keep_size` | Keeps recent WAL around without a slot, but does not know what a replica actually consumed. |

Replication lag has multiple meanings:

- send lag: primary has not sent WAL yet,
- write or flush lag: standby received WAL but has not persisted it,
- replay lag: standby has not applied WAL yet,
- visibility lag: read-only queries on standby see older data.

Use `pg_stat_replication` on the primary, `pg_stat_wal_receiver` on the standby, and LSN differences to locate the lag boundary. Large `sent_lsn` gaps often point at primary pressure, network delay, or standby IO/replay limits.

Logical replication is different. It publishes row changes from selected tables and subscriptions apply them elsewhere. It is useful for migrations, selective replication, and version transitions, but it has different DDL, sequence, conflict, and identity constraints than physical replication.

## Backups and Restore

Replicas are not backups. They can faithfully replicate deletion, corruption, bad migrations, and application bugs. A backup strategy should include:

| Type | Use | Restore Shape |
| --- | --- | --- |
| Logical dump | Portability, object-level movement, smaller systems, selective restore. | `pg_restore` or `psql` into a target database. |
| Physical base backup | Whole-cluster recovery and replica bootstrap. | Restore data directory plus required WAL. |
| WAL archive | PITR and recovery beyond the latest base backup. | `restore_command` feeds WAL during recovery. |

For PITR, you need a base backup and every WAL segment from that backup through the recovery target. Missing one required WAL segment breaks the chain. `archive_command` or `archive_library` must be monitored as a production write path, because failed archiving can silently destroy recovery objectives and fill `pg_wal`.

Logical dump boundaries matter. `pg_dump` backs up one database, not the whole cluster. Cluster-global objects such as roles and tablespaces require `pg_dumpall --globals-only` or equivalent infrastructure-as-code. A logical dump is useful, but it is not PITR and it cannot replace physical backups for whole-cluster recovery objectives.

Physical backup verification is also not the same as restore testing. `pg_basebackup` can create a backup manifest, and `pg_verifybackup` can check a plain-format base backup against that manifest. That catches many file-level problems, but the PostgreSQL documentation still warns that only a real restore proves the backup can be used by a running server and application.

Restore drills should prove:

1. You can find the intended base backup.
2. You can retrieve every required WAL segment.
3. You can recover to a named time, LSN, restore point, or latest consistent state.
4. Applications can authenticate and use the restored database.
5. The restored database is not accidentally connected to production integrations.

## WAL and Checkpoints

WAL is the write-ahead log used for crash recovery, replication, and PITR. Data pages can be written later because WAL records describe the changes needed to recover.

Operational WAL checks:

- `pg_wal` filesystem usage,
- failed or slow archiving in `pg_stat_archiver`,
- inactive replication slots retaining old WAL,
- WAL generation spikes in `pg_stat_wal`,
- checkpoint frequency in `pg_stat_checkpointer`,
- replica replay lag and recovery conflicts.

Frequent requested checkpoints can mean `max_wal_size` is too low for the write workload. Very infrequent checkpoints can increase crash recovery time. Full-page writes, bulk changes, index builds, vacuum behavior, and checkpoint timing all affect WAL volume.

## High CPU

High PostgreSQL CPU is usually one of these shapes:

| Symptom | Likely Cause | First Evidence |
| --- | --- | --- |
| Many active sessions | Connection storm, missing pooler, app retry loop. | `pg_stat_activity`, process count, PgBouncer queue. |
| One or few hot queries | Bad plan, missing index, stale stats, expensive function. | `pg_stat_statements`, `EXPLAIN (ANALYZE, BUFFERS)`. |
| CPU with lock waits | Sessions spin less than they wait; bottleneck is concurrency. | `wait_event_type`, blocking PID graph. |
| High system CPU | IO, kernel, context switching, networking, encryption. | `pidstat`, `perf`, `iostat`, TLS settings. |
| Autovacuum CPU | Dead tuple cleanup or analyze on high-churn tables. | autovacuum logs, `pg_stat_progress_vacuum`. |
| Parallel workers | A few queries use many workers. | `leader_pid`, `backend_type`, query plan. |

Start with active sessions and wait events before tuning. If the server is CPU-bound on useful work, reduce work: better indexes, better predicates, fixed row estimates, less chatty queries, cached results, or more efficient schema design. If CPU is from connection churn, PgBouncer usually helps more than raising `max_connections`.

## Locks, Timeouts, and Long Transactions

Lock waits can look like CPU, memory, or application latency incidents. Use `pg_stat_activity`, `pg_locks`, and `pg_blocking_pids()` to separate "doing work" from "waiting for another transaction."

```sql
SELECT blocked.pid AS blocked_pid,
       blocked.query AS blocked_query,
       pg_blocking_pids(blocked.pid) AS blocking_pids,
       blocked.wait_event_type,
       blocked.wait_event
FROM pg_stat_activity AS blocked
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;
```

Important guardrails:

- `statement_timeout` limits runaway statements when set at an appropriate role, database, or application level.
- `lock_timeout` fails fast when a statement waits too long to acquire a lock.
- `idle_in_transaction_session_timeout` terminates sessions that sit idle inside a transaction, which can otherwise hold locks and prevent vacuum cleanup.
- `transaction_timeout` limits total transaction duration, but be careful with middleware and connection poolers.

Do not set every timeout globally without testing. Poolers, migration tools, maintenance jobs, and long analytical queries may need different limits.

## High RAM

PostgreSQL memory is not one pool. Important consumers include:

| Consumer | Notes |
| --- | --- |
| `shared_buffers` | Shared page cache inside PostgreSQL. |
| OS page cache | Still important; PostgreSQL also relies on the kernel cache. |
| Backend process memory | Each connection has process overhead and private memory. |
| `work_mem` | Per sort/hash/materialize operation, not per server. One query can use it many times. |
| `maintenance_work_mem` | Used by maintenance operations such as vacuum and index builds. |
| WAL buffers and shared memory | Smaller than query memory but still part of the instance footprint. |
| Extensions and prepared statements | Can add per-backend or shared memory pressure. |

The common mistake is setting `work_mem` as if it were global. A value that is safe for five sessions can be dangerous for hundreds of sessions running multi-sort queries. High RAM incidents often combine too many backends, high `work_mem`, temp tables, hash joins, prepared statement caches, and container memory limits.

High RAM workflow:

1. Check whether memory is PostgreSQL RSS, OS cache, tmpfs, kernel slab, or cgroup accounting.
2. Count active and idle backends.
3. Look for temp file creation and spilled sorts/hashes.
4. Check `work_mem`, `maintenance_work_mem`, `shared_buffers`, and connection counts together.
5. Inspect long transactions and idle-in-transaction sessions that hold resources and block vacuum.
6. Use PgBouncer or app pool limits to cap backend count before raising memory settings.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why is a PostgreSQL replica not a backup?" answer="A replica can copy deletion, corruption, bad migrations, and application bugs; backups need separate retention and tested restore paths." %}
  {% include study-card.html question="What does a PostgreSQL HA manager add beyond replication?" answer="Leader election, promotion decisions, fencing, routing, monitoring, and controlled failover procedures." %}
  {% include study-card.html question="Why can replication slots be dangerous?" answer="An inactive slot can retain WAL indefinitely and fill the primary's disk." %}
  {% include study-card.html question="What do you need for PostgreSQL PITR?" answer="A physical base backup plus every required archived WAL segment through the recovery target." %}
  {% include study-card.html question="Why is work_mem risky during high RAM incidents?" answer="It is consumed per operation and per session, so total memory can multiply far beyond the setting value." %}
</div>

## References

- [PostgreSQL High Availability, Load Balancing, and Replication](https://www.postgresql.org/docs/current/high-availability.html)
- [PostgreSQL Log-Shipping Standby Servers](https://www.postgresql.org/docs/current/warm-standby.html)
- [PostgreSQL Backup and Restore](https://www.postgresql.org/docs/current/backup.html)
- [PostgreSQL Continuous Archiving and PITR](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [PostgreSQL Resource Consumption](https://www.postgresql.org/docs/current/runtime-config-resource.html)
- [PostgreSQL Write Ahead Log Configuration](https://www.postgresql.org/docs/current/runtime-config-wal.html)
- [PostgreSQL Monitoring Statistics](https://www.postgresql.org/docs/current/monitoring-stats.html)
- [PostgreSQL pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [PostgreSQL Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html)
