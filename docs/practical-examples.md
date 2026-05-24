---
title: Practical Examples
layout: page
permalink: /docs/practical-examples/
summary: "Concrete Linux, networking, DNS, Kubernetes, identity, database, Ceph, Istio, and troubleshooting examples that complement the conceptual study pages."
tags:
  - examples
  - study
  - operations
  - troubleshooting
---

# Practical Examples

This page collects practical examples that match the concepts in the guide. Treat them as patterns to adapt, not blind copy-paste. Names, CIDRs, secrets, ports, storage classes, and policies must match the real environment.

## Linux Service Example

A small systemd service with explicit user, restart behavior, logging, and resource controls:

```ini
[Unit]
Description=Example API service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=app
Group=app
WorkingDirectory=/opt/example-api
EnvironmentFile=-/etc/example-api/env
ExecStart=/opt/example-api/bin/server --config /etc/example-api/config.yaml
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/lib/example-api /var/log/example-api
MemoryMax=1G
CPUQuota=150%
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

Companion timer for a safe maintenance job:

```ini
[Unit]
Description=Nightly example-api cleanup

[Timer]
OnCalendar=*-*-* 03:15:00
RandomizedDelaySec=20m
Persistent=true
Unit=example-api-cleanup.service

[Install]
WantedBy=timers.target
```

```ini
[Unit]
Description=Run example-api cleanup

[Service]
Type=oneshot
User=app
ExecStart=/usr/bin/flock -n /run/example-api-cleanup.lock /opt/example-api/bin/cleanup
```

## Linux Backup Script Example

An rsync snapshot pattern using `--link-dest` and a dry run before destructive synchronization:

```bash
#!/usr/bin/env bash
set -euo pipefail

source_dir="/srv/app/"
backup_root="/backups/app"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
latest="${backup_root}/latest"
target="${backup_root}/${stamp}"

mkdir -p "$target"

rsync -aHAXn --delete \
  --exclude cache/ \
  --exclude tmp/ \
  --link-dest "$latest" \
  "$source_dir" "$target/"

rsync -aHAX --delete \
  --exclude cache/ \
  --exclude tmp/ \
  --link-dest "$latest" \
  "$source_dir" "$target/"

ln -sfn "$target" "$latest"
```

## nftables Firewall Example

A small host firewall that defaults to deny inbound traffic while allowing established flows, SSH, HTTP, and HTTPS:

```nft
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    iif lo accept
    ct state established,related accept
    ct state invalid drop

    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept

    tcp dport { 22, 80, 443 } accept

    counter log prefix "nft-drop-input: " flags all drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
```

## DNS Zone Example

A minimal authoritative zone shape showing SOA, NS, glue-adjacent host records, web records, mail records, and a service record:

```zone
$ORIGIN example.com.
$TTL 300
@ IN SOA ns1.example.com. dns-admin.example.com. (
  2026052301 ; serial
  3600       ; refresh
  600        ; retry
  1209600    ; expire
  300        ; negative cache TTL
)

@    IN NS ns1.example.com.
@    IN NS ns2.example.com.
ns1  IN A  203.0.113.10
ns2  IN A  203.0.113.11

@    IN A     203.0.113.20
www  IN CNAME example.com.
api  IN A     203.0.113.30

@    IN MX 10 mail.example.com.
mail IN A     203.0.113.40

_nats._tcp.cluster IN SRV 10 10 6222 nats-0.nats-headless.svc.example.com.
```

Resolver debugging comparison:

```bash
getent hosts api.example.com
dig @127.0.0.53 api.example.com A
dig @1.1.1.1 api.example.com A
dig @ns1.example.com api.example.com A +norecurse
dig +trace api.example.com
```

## TLS and mTLS Examples

Inspect the served certificate with SNI:

```bash
openssl s_client \
  -connect api.example.com:443 \
  -servername api.example.com \
  -showcerts </dev/null
```

Verify a client certificate and key match before using them for mTLS:

```bash
openssl x509 -in client.crt -noout -modulus | openssl sha256
openssl rsa -in client.key -noout -modulus | openssl sha256
openssl verify -CAfile client-ca.crt client.crt
```

Call an mTLS endpoint:

```bash
curl -v \
  --cert client.crt \
  --key client.key \
  --cacert server-ca.crt \
  https://admin-api.example.com/healthz
```

## Kubernetes Deployment Example

A Deployment with requests, limits, probes, rollout safety, and labels that can feed a Service:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-api
  namespace: apps
  labels:
    app.kubernetes.io/name: example-api
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: example-api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: example-api
    spec:
      containers:
        - name: api
          image: registry.example.com/example-api:1.4.2
          ports:
            - name: http
              containerPort: 8080
          envFrom:
            - configMapRef:
                name: example-api-config
            - secretRef:
                name: example-api-secret
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: "1"
              memory: 768Mi
          startupProbe:
            httpGet:
              path: /health/startup
              port: http
            failureThreshold: 30
            periodSeconds: 2
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            periodSeconds: 10
```

Service and PodDisruptionBudget:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-api
  namespace: apps
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: example-api
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: example-api
  namespace: apps
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: example-api
```

## Kubernetes NetworkPolicy Example

A default-deny plus explicit app and DNS egress:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: apps
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-api-allow
  namespace: apps
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: example-api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: databases
      ports:
        - protocol: TCP
          port: 5432
```

## Kubernetes Storage Example

A StatefulSet with stable identity and a per-Pod PVC:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: queue
  namespace: apps
spec:
  serviceName: queue-headless
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: queue
  template:
    metadata:
      labels:
        app.kubernetes.io/name: queue
    spec:
      containers:
        - name: queue
          image: registry.example.com/queue:2.1.0
          volumeMounts:
            - name: data
              mountPath: /var/lib/queue
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 50Gi
```

## Identity OAuth and JWT Examples

OAuth authorization-code token exchange with PKCE:

```bash
curl -sS https://idp.example.com/oauth/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=authorization_code \
  -d client_id=example-web \
  -d code="$AUTHORIZATION_CODE" \
  -d redirect_uri=https://app.example.com/callback \
  -d code_verifier="$PKCE_VERIFIER"
```

JWKS key discovery and safe local inspection:

```bash
curl -sS https://idp.example.com/.well-known/openid-configuration
curl -sS https://idp.example.com/.well-known/jwks.json | jq '.keys[] | {kid, kty, alg, use}'
```

JWT claim checks an API should enforce after signature verification:

```json
{
  "iss": "https://idp.example.com/",
  "aud": "https://api.example.com/",
  "scope": "orders:read orders:write",
  "exp": 1779570000,
  "nbf": 1779566400
}
```

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

## Ceph Examples

Pool creation and health checks:

```bash
ceph -s
ceph osd tree
ceph osd pool create app-replicated 128 128 replicated
ceph osd pool set app-replicated size 3
ceph osd pool set app-replicated min_size 2
ceph df
```

RBD example:

```bash
rbd pool init app-replicated
rbd create app-replicated/db-volume --size 102400
rbd info app-replicated/db-volume
rbd snap create app-replicated/db-volume@before-maintenance
```

## Istio Examples

Traffic split with a VirtualService:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: example-api
  namespace: apps
spec:
  hosts:
    - example-api.apps.svc.cluster.local
  http:
    - route:
        - destination:
            host: example-api.apps.svc.cluster.local
            subset: stable
          weight: 90
        - destination:
            host: example-api.apps.svc.cluster.local
            subset: canary
          weight: 10
```

DestinationRule subsets:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: example-api
  namespace: apps
spec:
  host: example-api.apps.svc.cluster.local
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

AuthorizationPolicy that allows only one namespace:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: example-api-allow-ingress
  namespace: apps
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: example-api
  action: ALLOW
  rules:
    - from:
        - source:
            namespaces:
              - ingress
```

## Troubleshooting Capture Example

A small incident capture script that records time, host identity, failed units, pressure, sockets, routes, and recent kernel logs:

```bash
#!/usr/bin/env bash
set -euo pipefail

out="${1:-incident-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$out"

date -Is | tee "$out/timestamp.txt"
hostnamectl >"$out/hostnamectl.txt" 2>&1 || true
systemctl --failed >"$out/systemd-failed.txt" 2>&1 || true
journalctl -p warning..alert -b --no-pager >"$out/journal-warnings.txt" 2>&1 || true
dmesg -T | tail -200 >"$out/dmesg-tail.txt" 2>&1 || true
cat /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io >"$out/psi.txt" 2>&1 || true
ss -tulpen >"$out/sockets.txt" 2>&1 || true
ip addr >"$out/ip-addr.txt" 2>&1 || true
ip route >"$out/ip-route.txt" 2>&1 || true
df -hT >"$out/df.txt" 2>&1 || true
```

## Example Review Checklist

Before adding an example to the guide, check:

- Does it show the smallest useful complete shape?
- Are placeholders obvious and safe?
- Does it include observability or validation commands?
- Does it avoid embedding real secrets?
- Does it mention the failure or safety boundary the example is meant to teach?

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What should a practical example include?" answer="A complete enough shape, obvious placeholders, validation commands, and the safety boundary it demonstrates." %}
  {% include study-card.html question="Why are examples not copy-paste defaults?" answer="Real environments have different names, CIDRs, secrets, storage classes, policies, and failure domains." %}
  {% include study-card.html question="What makes a Kubernetes example operationally useful?" answer="It shows selectors, resources, probes, rollout behavior, and how traffic or storage attaches to the workload." %}
  {% include study-card.html question="What makes a database example operationally useful?" answer="It connects query shape, index design, transaction behavior, durability, and inspection queries." %}
</div>
