---
title: Database and Search Examples
layout: page
permalink: /docs/databases/practical-examples/
summary: "Practical PostgreSQL, PgBouncer, and OpenSearch examples for queries, pooling, and cluster inspection."
tags:
  - examples
  - databases
  - postgres
  - pgbouncer
  - opensearch
---

# Database and Search Examples

These examples complement [Databases](/docs/databases/), [PostgreSQL](/docs/databases/postgres/), [PgBouncer](/docs/databases/postgres/pgbouncer/), and [OpenSearch](/docs/databases/opensearch/).

## PostgreSQL Examples

Index and query-plan workflow:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, status
FROM orders
WHERE customer_id = 42
  AND created_at >= now() - interval '30 days'
ORDER BY created_at DESC
LIMIT 50;

CREATE INDEX CONCURRENTLY idx_orders_customer_created_at
ON orders (customer_id, created_at DESC);

ANALYZE orders;
```

Transaction retry shape for serialization failures:

```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

UPDATE account
SET balance_cents = balance_cents - 5000
WHERE account_id = 1001;

UPDATE account
SET balance_cents = balance_cents + 5000
WHERE account_id = 2002;

COMMIT;
```

Operational checks:

```sql
SELECT pid, state, wait_event_type, wait_event, now() - query_start AS age, query
FROM pg_stat_activity
ORDER BY query_start NULLS LAST
LIMIT 20;

SELECT slot_name, active, restart_lsn, wal_status
FROM pg_replication_slots;

SELECT relname, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

## PgBouncer Example

Transaction pooling skeleton:

```ini
[databases]
app = host=postgres-primary.example.com port=5432 dbname=app

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 2000
default_pool_size = 50
reserve_pool_size = 10
server_reset_query = DISCARD ALL
ignore_startup_parameters = extra_float_digits
```

## OpenSearch Examples

Shard and allocation checks:

```bash
curl -sS https://opensearch.example.com:9200/_cluster/health?pretty
curl -sS https://opensearch.example.com:9200/_cat/nodes?v
curl -sS https://opensearch.example.com:9200/_cat/shards?v
curl -sS https://opensearch.example.com:9200/_cluster/allocation/explain?pretty \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Index template snippet:

```json
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1,
      "index.refresh_interval": "30s"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "service": { "type": "keyword" },
        "message": { "type": "text" }
      }
    }
  }
}
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why pair EXPLAIN ANALYZE with CREATE INDEX CONCURRENTLY?" answer="The plan shows the access problem, while the concurrent index reduces write blocking during production index creation." %}
  {% include study-card.html question="Why does PgBouncer transaction pooling require care?" answer="Session state such as temp tables, cursors, and some prepared statement assumptions can break across transactions." %}
  {% include study-card.html question="What do OpenSearch allocation checks show?" answer="Cluster health, node membership, shard placement, and why shards are unassigned or delayed." %}
</div>

## References

- [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/current/sql-explain.html)
- [PostgreSQL CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html)
- [PgBouncer documentation](https://www.pgbouncer.org/)
- [OpenSearch cluster health](https://docs.opensearch.org/latest/api-reference/cluster-api/cluster-health/)
