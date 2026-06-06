---
title: OpenSearch Operations, Replication, Sharding, and HA
layout: page
permalink: /docs/databases/opensearch/
summary: "OpenSearch operations guide covering shards, replicas, cross-cluster replication, allocation awareness, snapshots, cluster-manager failover, and HA runbooks."
tags:
  - opensearch
  - databases
  - search
  - replication
  - high-availability
---

# OpenSearch Operations, Replication, Sharding, and HA

OpenSearch is a distributed search engine. It stores data in indexes, splits indexes into primary shards, copies those shards to replica shards, and coordinates cluster state through elected cluster-manager nodes. High availability comes from shard allocation, node placement, cluster-manager quorum, snapshots, and tested operational procedures. It does not come from replicas alone.

For concrete cluster health, shard, allocation, and index-template examples, see [Database and Search Examples](/docs/databases/practical-examples/).

## Command Examples

```bash
curl -sS https://<opensearch>:9200/_cluster/health?pretty
curl -sS https://<opensearch>:9200/_cat/nodes?v
curl -sS https://<opensearch>:9200/_cat/shards?v
curl -sS https://<opensearch>:9200/_cluster/allocation/explain?pretty -H 'Content-Type: application/json' -d '{}'
curl -sS https://<opensearch>:9200/_cat/indices?v
curl -sS https://<opensearch>:9200/_plugins/_replication/<follower-index>/_status?pretty
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `curl -sS https://<opensearch>:9200/_cluster/health?pretty` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `curl -sS https://<opensearch>:9200/_cat/nodes?v` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |
| `curl -sS https://<opensearch>:9200/_cat/shards?v` | `HTTP status, headers, timing, JSON payload, or TLS/proxy error.` | Separates reachability, TLS, proxy, and application behavior. |

These checks separate cluster health, node roles, shard placement, allocation blockers, index state, and cross-cluster replication state. Pair them with JVM heap, disk watermarks, CPU, network, thread pools, and ingest error rates.

## Core Model

| Component | Role |
| --- | --- |
| Cluster | Set of OpenSearch nodes sharing one cluster state. |
| Cluster-manager node | Elected coordinator for cluster state, index metadata, and shard allocation decisions. |
| Data node | Stores primary or replica shards and runs indexing/search work. |
| Coordinating node | Receives client requests, fans out search/index operations, and merges responses. |
| Index | Logical namespace for documents, mappings, settings, aliases, and shards. |
| Primary shard | Authoritative copy for writes for one shard ID. |
| Replica shard | Copy of a primary shard used for redundancy and search capacity. |
| Snapshot | Backup of indexes and cluster state stored outside the cluster. |

Cluster health colors are shard-allocation signals:

- **Green:** all primary and replica shards are allocated.
- **Yellow:** all primary shards are allocated, but at least one replica is unassigned.
- **Red:** at least one primary shard is unassigned, so some data is unavailable.

Yellow is not harmless. It means the cluster can serve the data whose primaries are allocated, but it has reduced redundancy and may not survive another node or disk failure for affected indexes.

## Sharding

A shard is a Lucene index. OpenSearch routes each document to one primary shard, usually by hashing the document ID or a custom routing value. The primary shard handles the write, then replication makes the write available on replica shard copies.

Important sharding settings:

| Setting | Meaning |
| --- | --- |
| `index.number_of_shards` | Number of primary shards. This is a static index setting chosen at creation time for normal operations. |
| `index.number_of_replicas` | Number of replica shards per primary. This is dynamic and can be changed as nodes or HA needs change. |
| `index.routing.allocation.*` | Index-level filters that include, exclude, or require node attributes. |
| `cluster.routing.allocation.awareness.attributes` | Cluster-level awareness attributes, such as zone or rack, used to spread shard copies. |
| `wait_for_active_shards` | Write/create guard that waits for a chosen number of active shard copies before proceeding. |

Shard-count design is a capacity decision:

- Too few primary shards can cap indexing and search fan-out on a large index.
- Too many shards increase heap overhead, file handles, cluster-state size, recovery work, and search coordination cost.
- A replica is not a partition. More replicas can improve read capacity and redundancy, but they also increase disk use and replication work.
- Use rollover and index lifecycle patterns for time-series data instead of creating one ever-growing index.
- Prefer aliases for application access so reindexing, rollover, and shard-count changes do not require application changes.

Common sharding patterns:

| Pattern | Fit | Risk |
| --- | --- | --- |
| Time-based indexes | Logs, metrics, traces, events. | Hot latest index, many small old indexes, retention mistakes. |
| Tenant or customer routing | Multi-tenant search where tenant isolation matters. | Hot tenants can overload one shard. |
| Hash by document ID | General balanced distribution. | Cross-document locality may be poor. |
| Index-per-tenant | Stronger operational separation for large tenants. | Cluster-state and shard count can explode with many small tenants. |
| Hot/warm/cold tiers | Different hardware for current and historical data. | Allocation filters and lifecycle policy must match real node capacity. |

Operational sharding rules:

- Choose primary shard count from expected index size, write rate, query patterns, and recovery time, not from a fixed rule copied across systems.
- Keep primary and replica copies on different nodes and preferably different zones/racks.
- Use allocation awareness for failure domains. Without it, replicas may concentrate where they do not protect you.
- Use forced awareness when you would rather leave replicas unassigned than place both copies in the same failure domain.
- Use `_cluster/allocation/explain` before changing allocation settings during an incident.
- Watch shard skew: largest shards, hottest shards, slowest shards, and shards stuck initializing or relocating.

## In-Cluster Replication

OpenSearch replication inside one cluster is shard-copy replication. Each primary shard has zero or more replica shard copies depending on `index.number_of_replicas`.

Write path:

1. A client sends a write to any node.
2. The coordinating node routes the request to the primary shard for that document.
3. The primary validates and applies the write.
4. Replica copies receive and apply the operation.
5. The client response reports how many shard copies succeeded or failed.

`wait_for_active_shards` can require a minimum number of active shard copies before an operation starts. It reduces the chance of writing while the cluster is under-replicated, but it is not the same as a global durability guarantee. Replication can still fail after the operation begins, and the response must be checked.

Replication modes and related features:

| Feature | Meaning |
| --- | --- |
| Document replication | Replica shards apply document operations. This is the classic default mental model. |
| Segment replication | Replica shards copy Lucene segment files from primaries after refresh/checkpoints, improving some write-heavy workloads at the cost of more network use and different freshness tradeoffs. |
| Search replicas | Additional search-only shard copies for read capacity in supported configurations. |
| Peer recovery | Process that brings a new or stale shard copy up to date after allocation, relocation, or node return. |

Replica count guidance:

- `0` replicas is acceptable only for disposable data or development.
- `1` replica is the common minimum for production indexes on multi-node clusters.
- More replicas help read fan-out and failure tolerance, but they increase disk, network, recovery, and indexing overhead.
- Replicas do not protect against deletes, bad mappings, bad ingest pipelines, ransomware, or application bugs. Use snapshots.

## Cross-Cluster Replication

Cross-cluster replication replicates indexes from a leader cluster to one or more follower indexes in another cluster. It is active-passive: writes happen on the leader index, and follower indexes are read-only copies that pull changes from the leader.

Use cases:

- regional disaster recovery,
- local reads near users,
- central reporting from smaller clusters,
- migration staging,
- keeping a warm search cluster ready for controlled failover.

Important properties:

- Both clusters need the replication plugin.
- The follower side needs remote-cluster connectivity to the leader.
- If node roles are explicitly configured, follower nodes that connect remotely need the `remote_cluster_client` role.
- Security plugin posture and replication permissions must be designed on both clusters.
- Replication is per index or index pattern through auto-follow rules, not automatic whole-cluster magic.
- Follower indexes are read-only while following.

Cross-cluster replication operations:

| Operation | Meaning |
| --- | --- |
| Start replication | Create a follower index from a leader index and start pulling changes. |
| Pause replication | Temporarily stop replication progress. Long pauses can require restarting replication depending on retention and plugin limits. |
| Resume replication | Continue a paused replication job when it is still resumable. |
| Stop replication | Unfollow the leader. The follower becomes a normal writable index, but replication cannot simply be restarted from the stopped state. |
| Auto-follow | Automatically create follower indexes when leader indexes match configured patterns. |

Failover with cross-cluster replication is not automatic application magic. A controlled regional failover needs:

1. Confirm follower indexes are current enough for the intended RPO.
2. Stop writes to the old leader or declare it lost.
3. Stop replication or promote the follower-side data according to the runbook.
4. Move application writes and reads to the new cluster endpoint or alias.
5. Prevent the old leader from accepting divergent writes when it returns.
6. Rebuild reverse replication or re-seed the old cluster before failback.

## HA Failover

OpenSearch has several different failover planes. Keep them separate.

| Failure Plane | What Fails Over | What Users See |
| --- | --- | --- |
| Cluster-manager node | Election chooses another cluster-manager node if quorum exists. | Brief cluster-state disruption; data nodes can continue many operations if cluster state is stable. |
| Data node | Replica shards are promoted or allocated; missing replicas recover elsewhere if capacity exists. | Searches may slow; writes can fail for unavailable primaries; health may go yellow/red. |
| Zone/rack | Allocation awareness decides whether copies remain available or unassigned. | Depends on whether primaries and replicas were spread correctly. |
| Whole cluster | Only external routing, snapshots, or cross-cluster replication can move service elsewhere. | Requires runbook-driven DR/failover. |

Cluster-manager HA:

- Use three dedicated cluster-manager-eligible nodes for most production clusters.
- Spread them across failure domains.
- Avoid two cluster-manager nodes as a production quorum design. A two-node voting set cannot safely tolerate one side of a partition without risking split brain.
- Keep data-heavy and ingest-heavy work off dedicated cluster-manager nodes.

Data-node HA:

- Every production index that must survive node loss needs replicas and enough nodes to place them away from primaries.
- Disk watermarks, allocation filters, awareness rules, and node roles can prevent replicas from allocating even when raw disk exists.
- A red index means at least one primary shard is unavailable. A yellow index means primaries exist but redundancy is missing.
- Restoring missing primaries generally means recovering the original node, allocating a stale primary only when you accept data loss, or restoring from snapshot.

HA runbook for a failed data node:

1. Check `_cluster/health`, `_cat/shards`, `_cat/nodes`, and allocation explanation.
2. Determine whether the node is truly gone, slow, partitioned, disk-full, or blocked by JVM pressure.
3. If primaries are active and only replicas are unassigned, keep serving but reduce risk and restore redundancy.
4. If primaries are unassigned, decide whether the missing node can return quickly or whether snapshot restore is required.
5. Check allocation blockers: disk watermarks, awareness, forced awareness, include/exclude filters, index blocks, and node roles.
6. Avoid forcing stale primary allocation unless the data-loss decision is explicit and documented.
7. After recovery, verify shard balance, search results, ingest success, snapshots, and alerts.

## Snapshots and Recovery

Snapshots are backups stored outside the cluster. Replicas are for availability; snapshots are for recovery from corruption, deletion, bad rollout, cluster loss, or accidental writes.

Snapshot rules:

- Store snapshots outside the cluster failure domain.
- Automate snapshot creation and retention.
- Test restore into a separate cluster.
- Include cluster state when needed, but understand what settings/templates you are restoring.
- Do not assume a green cluster means backups work.
- During disaster recovery, restore critical indexes first instead of waiting for every historical index if RTO matters.

Recovery choices:

| Situation | Preferred Recovery |
| --- | --- |
| Lost replica only | Let OpenSearch allocate/recover a new replica. |
| Lost node with primaries but node can return | Bring node back if storage is intact and faster than restore. |
| Lost primary and no good shard copy | Restore from snapshot or accept stale-primary data loss only by explicit decision. |
| Bad delete or bad ingest | Restore affected index to a new name, compare, then alias/cut over. |
| Region loss with CCR | Promote follower-side service and prevent old leader split writes. |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does yellow OpenSearch cluster health mean?" answer="All primary shards are allocated, but one or more replica shards are unassigned, so redundancy is reduced." %}
  {% include study-card.html question="What does red OpenSearch cluster health mean?" answer="At least one primary shard is unassigned, so some data is unavailable." %}
  {% include study-card.html question="What is the difference between a primary shard and a replica shard?" answer="The primary handles writes for its shard ID; replicas copy the primary for redundancy and search capacity." %}
  {% include study-card.html question="Why are snapshots still required if indexes have replicas?" answer="Replicas can copy deletion, corruption, bad mappings, and bad ingest; snapshots provide independent recovery." %}
  {% include study-card.html question="What is OpenSearch cross-cluster replication?" answer="An active-passive setup where follower indexes in another cluster pull changes from leader indexes." %}
  {% include study-card.html question="What does allocation awareness protect against?" answer="It spreads primary and replica shard copies across failure domains such as zones or racks." %}
  {% include study-card.html question="What is the usual production cluster-manager node count?" answer="Three dedicated cluster-manager-eligible nodes spread across failure domains." %}
</div>

## References

- [OpenSearch cluster health API](https://docs.opensearch.org/latest/api-reference/cluster-api/cluster-health/)
- [OpenSearch index settings](https://docs.opensearch.org/latest/install-and-configure/configuring-opensearch/index-settings/)
- [OpenSearch shard allocation filtering](https://docs.opensearch.org/latest/api-reference/index-apis/shard-allocation/)
- [OpenSearch cluster allocation explain API](https://docs.opensearch.org/latest/api-reference/cluster-api/cluster-allocation/)
- [OpenSearch cross-cluster replication](https://docs.opensearch.org/latest/tuning-your-cluster/replication-plugin/index/)
- [OpenSearch cross-cluster replication getting started](https://docs.opensearch.org/latest/tuning-your-cluster/replication-plugin/getting-started/)
- [OpenSearch snapshots](https://docs.opensearch.org/latest/tuning-your-cluster/availability-and-recovery/snapshots/index/)
- [OpenSearch voting and quorum](https://docs.opensearch.org/latest/tuning-your-cluster/discovery-cluster-formation/voting-quorums/)
