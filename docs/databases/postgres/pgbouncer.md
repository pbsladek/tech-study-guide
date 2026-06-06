---
title: PgBouncer
layout: page
permalink: /docs/databases/postgres/pgbouncer/
summary: "How PgBouncer works, pooling modes, sizing, HA placement, failover behavior, prepared statements, session state, observability, and operational runbooks."
tags:
  - postgres
  - databases
  - pgbouncer
  - networking
---

# PgBouncer

PgBouncer is a lightweight PostgreSQL connection pooler. Applications connect to PgBouncer, PgBouncer opens a smaller number of server connections to PostgreSQL, and client work is multiplexed onto those server connections according to the selected pooling mode.

The main reason PgBouncer exists is that PostgreSQL's classic connection model uses one backend process per client connection. Too many database backends consume memory, increase context switching, amplify lock and cache pressure, and make failover harder. PgBouncer lets the system accept many client sockets while limiting the number of active PostgreSQL server connections.

## Command Examples

```bash
psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW POOLS;"
psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW STATS;"
psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW CLIENTS;"
psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW SERVERS;"
psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW DATABASES;"
psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW CONFIG;"
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW POOLS;"` | `Rows with role, lag, sessions, waits, pools, or replication state.` | Shows database state and pooler behavior from SQL evidence. |
| `psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW STATS;"` | `Rows with role, lag, sessions, waits, pools, or replication state.` | Shows database state and pooler behavior from SQL evidence. |
| `psql "postgresql://<user>@<pgbouncer-host>:6432/pgbouncer" -c "SHOW CLIENTS;"` | `Rows with role, lag, sessions, waits, pools, or replication state.` | Shows database state and pooler behavior from SQL evidence. |

These commands use PgBouncer's admin console database named `pgbouncer`. They show whether clients are waiting, how many server connections exist, which databases and users have pools, and whether the running configuration matches the intended one.

## How Pooling Works

PgBouncer has two sides:

| Side | Meaning |
| --- | --- |
| Client connection | App-to-PgBouncer socket. Can be numerous and queued. |
| Server connection | PgBouncer-to-PostgreSQL connection. Should be capped to what PostgreSQL can actually run. |

Pooling mode decides when a server connection can be returned to the pool:

| Mode | Server Connection Released | Use |
| --- | --- | --- |
| `session` | When the client disconnects. | Safest compatibility, weakest pooling. |
| `transaction` | When the transaction ends. | Common for web workloads; strong pooling with session-state restrictions. |
| `statement` | After each statement. | Narrow use; multi-statement transactions are disallowed. |

Transaction pooling is the usual reason to deploy PgBouncer, but it changes the contract. A client cannot assume the next transaction will use the same PostgreSQL backend.

## Transaction Pooling Caveats

In transaction pooling, avoid or redesign features that depend on backend session identity:

- session-level `SET` state not tracked by PgBouncer,
- temporary tables expected across transactions,
- session-level advisory locks,
- server-side cursors spanning transactions,
- `LISTEN`/`NOTIFY` patterns that need a stable backend connection,
- SQL-level `PREPARE`/`EXECUTE` assumptions,
- migrations that change result types while clients reuse prepared statements.

Modern PgBouncer can track protocol-level named prepared statements when `max_prepared_statements` is nonzero. That is not the same as making every session feature safe. It adds CPU and memory work because PgBouncer must inspect, cache, and rewrite prepared statement traffic.

If an application truly needs session state, use `session` pooling for that workload or keep it off PgBouncer. Mixing incompatible applications into one transaction pool creates intermittent failures that look like random database bugs.

`server_reset_query` is an easy place to get misled. PgBouncer's documentation says it is not used in transaction pooling by default because transaction pooling assumes clients do not depend on session state. `server_reset_query = DISCARD ALL` is a session-pooling cleanup pattern, not a magic fix that makes transaction pooling safe. `server_reset_query_always` exists for broken setups, but it adds overhead and should be treated as a workaround while the application is fixed.

## Sizing

Size PgBouncer from PostgreSQL capacity backward:

| Setting | Meaning |
| --- | --- |
| `max_client_conn` | Maximum client connections PgBouncer accepts. |
| `default_pool_size` | Default server connections per database/user pool. |
| `max_db_connections` | Cap server connections for one PgBouncer database. |
| `max_user_connections` | Cap server connections for one user. |
| `reserve_pool_size` | Burst capacity after clients wait longer than `reserve_pool_timeout`. |

Raising `max_client_conn` can require higher OS file descriptor limits. It also does not mean PostgreSQL can handle that many active queries. The purpose of PgBouncer is often to let excess clients wait in PgBouncer instead of becoming PostgreSQL backends.

Watch these admin-console fields:

| Evidence | Meaning |
| --- | --- |
| `cl_active` | Clients currently assigned server connections. |
| `cl_waiting` | Clients queued for a server connection. |
| `sv_active` | Server connections currently executing client work. |
| `sv_idle` | Server connections available for reuse. |
| `avg_query` and `avg_wait` | Query and queue timing from `SHOW STATS`. |

If `cl_waiting` is always high, the pool is too small, PostgreSQL is slow, or the application is sending too much concurrency. Increasing pool size only helps if PostgreSQL has unused CPU, memory, IO, and lock capacity.

## HA and Failover Placement

PgBouncer does not decide which PostgreSQL node is primary. It should point at a primary endpoint managed by something else:

- a cloud managed database endpoint,
- a Kubernetes operator Service such as a CloudNativePG `-rw` Service,
- a VIP or load balancer controlled by an HA manager,
- DNS updated by automation,
- a local PgBouncer per app node pointing at the current primary endpoint.

During failover, client behavior depends on where PgBouncer sits:

| Placement | Tradeoff |
| --- | --- |
| App-side PgBouncer | Less network hop and blast radius, but more instances to configure and reload. |
| Shared PgBouncer tier | Central control and observability, but it can become a bottleneck or failure domain. |
| PgBouncer in Kubernetes | Works well behind a Service, but needs PodDisruptionBudgets, readiness, and safe config reloads. |

Useful commands:

| Command | Use |
| --- | --- |
| `RELOAD` | Reload changed configuration. |
| `PAUSE` | Wait for server connections to be released, useful before database restart. |
| `RESUME` | Resume after `PAUSE`, `SUSPEND`, or `KILL`. |
| `RECONNECT` | Close and reopen server connections when downstream routing changed. |
| `KILL` | Emergency drop of client and server connections for a database. |

For planned switchover, prefer draining or pausing so transactions finish cleanly. For emergency failover, expect some clients to reconnect and retry failed transactions. PgBouncer can reduce connection storm impact after failover, but it cannot make in-flight transactions survive primary loss.

## Configuration Skeleton

```ini
[databases]
app = host=postgres-rw port=5432 dbname=app

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 2000
default_pool_size = 50
reserve_pool_size = 10
admin_users = postgres
stats_users = postgres,monitoring
```

Treat this as a shape, not a copy-paste answer. Real values depend on workload concurrency, number of app instances, PostgreSQL CPU and memory, transaction duration, failover design, TLS/auth requirements, and file descriptor limits.

Authentication is part of the design, not a footnote. PgBouncer can use static credentials from `auth_file` or ask PostgreSQL through `auth_query`, depending on how roles are managed. TLS can terminate at PgBouncer, pass through on the server side, or be used on both sides. Make sure authentication, TLS, and pool mode are documented together so failover or credential rotation does not strand clients.

## Failure Modes

| Symptom | Likely Boundary | Checks |
| --- | --- | --- |
| Clients wait but PostgreSQL is not saturated | Pool too small or pools split by user/database. | `SHOW POOLS`, database/user mapping, `default_pool_size`. |
| PostgreSQL saturated despite PgBouncer | Pool too large or queries too expensive. | `sv_active`, PostgreSQL CPU, `pg_stat_statements`. |
| Random missing temp table or GUC state | Transaction pooling with session features. | App behavior, `pool_mode`, `SET`, temp table use. |
| Prepared statement errors after migration | Cached prepared statement result type changed. | PgBouncer `max_prepared_statements`, app prepared statements, `RECONNECT`. |
| PgBouncer high CPU | Too much connection churn, TLS, prepared statement tracking, single core limit. | PgBouncer CPU, `SHOW STATS`, `so_reuseport` design. |
| Failover points at old primary | Routing endpoint, DNS, or PgBouncer server connections stale. | `SHOW SERVERS`, `RELOAD`, `RECONNECT`, HA manager status. |
| OOM in PgBouncer | Too many clients, large packets, prepared statement cache, container limit. | `max_client_conn`, `pkt_buf`, `max_prepared_statements`, RSS. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What problem does PgBouncer solve?" answer="It lets many client connections reuse a smaller number of PostgreSQL server connections, reducing backend process overhead." %}
  {% include study-card.html question="What is PgBouncer transaction pooling?" answer="A server connection is returned to the pool after each transaction, so the next transaction may use a different PostgreSQL backend." %}
  {% include study-card.html question="Why can transaction pooling break applications?" answer="Session state such as temp tables, session GUCs, advisory locks, cursors, and some prepared statement assumptions may not survive across transactions." %}
  {% include study-card.html question="Does PgBouncer perform PostgreSQL failover?" answer="No. It can reconnect to a changed endpoint, but primary selection and fencing belong to an HA manager or platform." %}
  {% include study-card.html question="What does cl_waiting in SHOW POOLS indicate?" answer="Clients are queued waiting for a PostgreSQL server connection from the pool." %}
</div>

## References

- [PgBouncer Features](https://www.pgbouncer.org/features.html)
- [PgBouncer Configuration](https://www.pgbouncer.org/config.html)
- [PgBouncer Usage and Admin Console](https://www.pgbouncer.org/usage.html)
- [PostgreSQL High Availability, Load Balancing, and Replication](https://www.postgresql.org/docs/current/high-availability.html)
- [PostgreSQL Monitoring Statistics](https://www.postgresql.org/docs/current/monitoring-stats.html)
