---
title: Troubleshooting and Error Handling
layout: page
permalink: /docs/troubleshooting/
summary: "Cross-technology troubleshooting and error handling for Linux, networking, DNS, Kubernetes, Istio, Ceph, PostgreSQL, and distributed systems operations."
tags:
  - troubleshooting
  - operations
  - incident-response
  - reliability
---

# Troubleshooting and Error Handling

Troubleshooting is evidence management under time pressure. Error handling is designing systems so failures are bounded, observable, retryable when safe, and recoverable when not. The same discipline applies across Linux hosts, networks, DNS, Kubernetes, Istio, Ceph, PostgreSQL, and application services.

## First Checks

```bash
date -Is
hostnamectl
systemctl --failed
journalctl -p warning..alert -b
kubectl get events --all-namespaces --sort-by=.lastTimestamp
curl -v https://example.com/
dig example.com
```

This first pass answers four questions: what time is it on this system, what host or cluster am I on, what is already reporting failure, and does the symptom reproduce at DNS, TCP, TLS, HTTP, or service level?

## Incident Frame

Start by writing a short failure statement before changing anything:

| Field | Example |
| --- | --- |
| Symptom | Writes to checkout database time out after 30 seconds. |
| Scope | One region, one namespace, or all users. |
| Start time | First alert, first user report, or first bad deploy timestamp. |
| Recent change | Deploy, config, certificate, route, node drain, storage event, firewall rule. |
| Known good path | Direct backend, another zone, previous version, read-only query, small packet. |
| Safety constraint | Do not lose writes, do not widen firewall access, preserve logs, avoid split brain. |

Good troubleshooting reduces possibilities. Bad troubleshooting creates new state faster than evidence can explain it.

## Universal Method

Use the same loop across Linux, networking, DNS, Kubernetes, databases, storage, and identity:

1. State the exact symptom and scope.
2. Preserve evidence before restarting, deleting, failing over, or repairing.
3. Identify the data plane and control plane involved.
4. Find the owner of the next state transition.
5. Test one layer at a time with the same path the application uses.
6. Compare known-good and known-bad paths.
7. Make the smallest reversible change that tests a hypothesis.
8. Verify recovery from user-visible behavior and lower-level evidence.
9. Record what changed, why it worked, and what guardrail prevents recurrence.

Avoid shotgun debugging: multiple simultaneous changes make it hard to know which change helped and can create a second incident.

## Evidence Preservation

Before restarting services or deleting pods, capture the evidence that will disappear. Treat evidence preservation as an operational requirement, not a post-incident luxury:

- logs for the failing time window,
- events and status objects,
- process exit code and signal,
- unit, deployment, and config definitions,
- resource pressure and OOM evidence,
- connection counters, queue sizes, and error counters,
- current leader, primary, quorum, or lock holder,
- recent rollout, migration, or operator reconciliation action.

Useful convention: record the command, timestamp, host or context, and output path in the incident notes. A correlation ID should be carried through logs and traces when the application supports it.

## Error Taxonomy

Classify the failure before choosing the fix:

| Class | Clues | Typical Mistake |
| --- | --- | --- |
| Configuration | New deploy, bad env var, invalid YAML, wrong secret, bad route. | Restarting repeatedly instead of comparing effective config. |
| Capacity | Saturated CPU, memory, disk, IOPS, file descriptors, connections, queue depth. | Raising one limit while moving the bottleneck elsewhere. |
| Dependency | Timeouts, connection refused, DNS failure, upstream 5xx. | Treating the caller as broken without testing the dependency path. |
| Authentication | 401/403, TLS verification failure, expired token, RBAC denial. | Widening permissions instead of proving identity and audience. |
| Network | No route, firewall drop, MTU black hole, asymmetric return path, conntrack pressure. | Testing only ping when the app uses TCP, TLS, or HTTP. |
| Data integrity | Corruption, bad migration, inconsistent replica, failed scrub, WAL gap. | Running repair before backups and blast radius are understood. |
| Time and identity | Clock skew, duplicate machine-id, expired certificate, wrong hostname. | Debugging TLS or auth while NTP or identity is wrong. |

## Data Plane vs Control Plane Failures

Separating planes prevents misleading conclusions:

| System | Control Plane | Data Plane |
| --- | --- | --- |
| Kubernetes | API server, scheduler, controllers, webhooks. | Pods, kubelet-managed containers, CNI datapath, Services. |
| DNS | Zone management, delegation changes, recursive cache policy. | Query and response packets between clients, resolvers, and authorities. |
| Istio | istiod, xDS config generation, cert issuance. | Envoy, ztunnel, waypoint, application traffic. |
| Ceph | MON quorum, maps, managers, orchestration. | OSD reads/writes, recovery, client IO. |
| Databases | Failover manager, operator, replication slot management. | Query execution, WAL writes, locks, storage IO. |

A control plane can be down while current data-plane traffic keeps flowing. A data plane can be broken while APIs show the desired configuration. Check both before deciding the blast radius.

## Linux Host Runbook

Linux failures usually surface as resource pressure, service failure, kernel messages, permission problems, or filesystem errors.

Checks:

```bash
systemctl status <unit>
journalctl -u <unit> -b --no-pager
systemctl show <unit> -p ExecMainStatus -p Result -p OOMPolicy
dmesg -T | tail -100
cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io
df -hT
```

Interpretation:

| Signal | Meaning |
| --- | --- |
| `ExecMainStatus` | Process exit code or signal captured by systemd. |
| `OOMKilled` | Kernel or cgroup memory enforcement killed the process. |
| `No space left on device` | Could be blocks, inodes, quotas, or a read-only remount. |
| `Permission denied` | Check UID/GID, mode bits, ACLs, parent execute bits, SELinux/AppArmor where present. |
| `Too many open files` | Process or system file descriptor limit, often from leaked sockets or files. |

Safe handling: restart only after preserving logs and checking whether the service is crash-looping because of bad config, missing dependencies, or resource limits.

## Networking and DNS Runbook

Separate name resolution, route selection, connection establishment, TLS, and application response.

```bash
dig example.com
getent hosts example.com
ip route get 198.51.100.10
ss -tan state syn-sent
curl -vk --resolve example.com:443:198.51.100.10 https://example.com/
tcpdump -nn -i any host 198.51.100.10
```

Common traps:

- DNS search paths and `ndots` create unexpected queries.
- Firewalls may allow ICMP while dropping TCP or UDP.
- MTU black holes often appear only on large TLS or file-transfer traffic.
- A proxy can change DNS view, source IP, Host, SNI, headers, and timeout behavior.
- A VPN can route one prefix correctly while dependency prefixes bypass the tunnel.

Error handling: clients should use explicit connect, TLS handshake, request, and idle timeouts. Retries need backoff with jitter and should be limited to operations that are idempotent or protected by an idempotency key.

## Kubernetes Runbook

Kubernetes errors are usually split between desired state, scheduler decisions, kubelet execution, network/storage attachment, and application behavior.

```bash
kubectl get pods -A -o wide
kubectl describe pod <pod> -n <namespace>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl logs <pod> -n <namespace> --previous
kubectl get deploy,rs,sts,ds -n <namespace>
kubectl auth can-i --as <service-account> <verb> <resource>
```

High-value states:

| State or Error | Where To Look |
| --- | --- |
| `CrashLoopBackOff` | Previous logs, exit code, probes, command, env, config, dependency startup. |
| `ImagePullBackOff` | Image name, tag, registry auth, pull secret, DNS, egress proxy. |
| `CreateContainerConfigError` | Missing ConfigMap, Secret, env var, projected volume, invalid field. |
| `Pending` | Scheduler events, taints, tolerations, affinity, resource requests, PVC binding. |
| `OOMKilled` | Container memory limit, application heap, tmpfs, page cache, cgroup events. |
| Probe failures | Probe path, timeout, startup ordering, dependency coupling, mesh interception. |

Error handling: readiness should mean "can serve this traffic now." Liveness should detect unrecoverable local deadlock, not slow dependencies. Startup probes protect slow boot from premature liveness kills.

## Istio and Service Mesh Runbook

Service mesh failures often look like application failures, but the failing layer may be proxy config, mTLS, authorization, route matching, endpoint discovery, or xDS sync.

```bash
istioctl proxy-status
istioctl proxy-config routes <pod> -n <namespace>
istioctl proxy-config clusters <pod> -n <namespace>
kubectl get peerauthentication,authorizationpolicy -A
kubectl logs <pod> -c istio-proxy -n <namespace>
```

Check:

- sidecar or ambient enrollment,
- proxy readiness and xDS sync,
- PeerAuthentication mode and DestinationRule TLS mode,
- AuthorizationPolicy deny and allow rules,
- VirtualService host and route matches,
- waypoint proxy or ztunnel logs in ambient mode,
- whether direct pod traffic differs from mesh traffic.

Error handling: timeouts, retries, and circuit breaker settings in the mesh must match application semantics. Retrying non-idempotent writes at a proxy can duplicate effects.

## Ceph and Rook Runbook

Ceph troubleshooting starts with health detail and PG states, not with restarting daemons.

```bash
ceph -s
ceph health detail
ceph osd tree
ceph pg stat
ceph pg dump_stuck
kubectl -n rook-ceph get cephcluster,pods,pvc
```

Important states:

| Signal | Meaning |
| --- | --- |
| `HEALTH_WARN` / `HEALTH_ERR` | Read `ceph health detail`; the warning type determines the action. |
| `degraded` / `undersized` | Data has reduced redundancy or missing replicas. |
| `peering` | PGs are trying to agree on authoritative state. |
| `inconsistent` | Scrub found mismatched object data or metadata. |
| `nearfull` / `backfillfull` / `full` | Writes or recovery may stop because space is unsafe. |

Error handling: avoid repair commands until backups, affected PGs, and device health are understood. In Rook, separate Kubernetes scheduling/PVC failures from Ceph health failures.

## PostgreSQL and CloudNativePG Runbook

Database incidents need caution because a "fix" can destroy evidence or data.

```bash
psql -d <database> -c "select now(), state, wait_event_type, wait_event from pg_stat_activity;"
psql -d <database> -c "select * from pg_stat_replication;"
psql -d <database> -c "select * from pg_stat_database_conflicts;"
kubectl cnpg status <cluster>
kubectl get pods,pvc,svc -l cnpg.io/cluster=<cluster>
```

PostgreSQL clues:

| Clue | Meaning |
| --- | --- |
| SQLSTATE | Stable error code for programmatic handling; better than matching message text. |
| Lock waits | A transaction may block many others while appearing idle. |
| WAL growth | Archiving, replication slots, or long transactions may retain WAL. |
| Replication lag | Standby reads may be stale; failover RPO depends on received WAL. |
| Too many connections | Connection pool, app leak, or insufficient worker budget. |
| Disk full | Stop and preserve data; do not delete random files from the data directory. |

Error handling: wrap external side effects with idempotency keys or an outbox pattern. Use transaction boundaries deliberately. Retry serialization failures and deadlocks where safe; do not blindly retry constraint violations or unknown commit outcomes.

## Application Error Handling Patterns

Reliable systems assume partial failure.

| Pattern | Use |
| --- | --- |
| Timeout budget | Each hop has explicit connect, request, and idle timeouts. |
| Backoff with jitter | Retries spread out instead of synchronizing a thundering herd. |
| Idempotency key | Duplicate client requests can be safely recognized and collapsed. |
| Circuit breaker | Stop hammering a dependency that is already failing. |
| Bulkhead | Limit one dependency or tenant from consuming all workers. |
| Dead-letter queue | Preserve messages that cannot be processed after bounded retries. |
| Outbox pattern | Persist state change and event emission together for reliable delivery. |
| Graceful degradation | Serve reduced functionality instead of failing the entire request. |

Do not retry everything. Retry only when the operation is safe, bounded, observable, and the caller can tolerate the extra latency.

## Recovery Checklist

1. Preserve evidence before destructive action.
2. State the blast radius and current user impact.
3. Stop the bleeding with the smallest reversible change.
4. Verify the fix at the failing layer and one layer above it.
5. Watch for delayed errors: retries, queues, backfills, WAL replay, cache expiry.
6. Document root cause, contributing factors, detection gap, and prevention.
7. Add a regression check, alert, runbook step, or safer default.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why preserve evidence before restarting?" answer="Restarts can erase process state, previous logs, exit codes, events, queues, and timing clues needed for root cause." %}
  {% include study-card.html question="What does CrashLoopBackOff usually require first?" answer="Previous container logs, exit code, events, probe state, command, environment, and config checks." %}
  {% include study-card.html question="Why is SQLSTATE useful?" answer="It is a stable PostgreSQL error code for programmatic handling, unlike free-form message text." %}
  {% include study-card.html question="Why separate data plane from control plane while troubleshooting?" answer="They fail independently; configuration APIs may be healthy while traffic fails, or traffic may continue while new changes cannot be made." %}
  {% include study-card.html question="Why use backoff with jitter?" answer="It prevents many clients from retrying in synchronized waves that amplify an outage." %}
  {% include study-card.html question="What is a dead-letter queue for?" answer="Preserving messages that fail bounded retries so they can be inspected or replayed safely." %}
</div>

## References

- [Linux logs and observability](../linux/logs-observability/)
- [Linux systemd troubleshooting](../linux/systemd/)
- [Networking packet path](../networking/packet-path/)
- [DNS records, responses, and transport](../dns/records-transport-operations/)
- [Kubernetes troubleshooting](../kubernetes/troubleshooting/)
- [Istio service mesh](../istio/service-mesh/)
- [Ceph health checks](https://docs.ceph.com/en/latest/rados/operations/health-checks/)
- [PostgreSQL error codes](https://www.postgresql.org/docs/current/errcodes-appendix.html)
