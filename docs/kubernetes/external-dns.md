---
title: Kubernetes ExternalDNS
layout: page
permalink: /docs/kubernetes/external-dns/
summary: How ExternalDNS watches Kubernetes resources and reconciles public or private DNS records through provider APIs.
tags:
  - kubernetes
  - dns
  - networking
---

# Kubernetes ExternalDNS

ExternalDNS is a Kubernetes controller for DNS provider records. It watches Kubernetes resources, derives desired DNS endpoints, and calls a provider API such as Route 53, Google Cloud DNS, Azure DNS, Cloudflare, RFC2136, or another supported backend. It does not answer Pod DNS queries, replace CoreDNS, create load balancers, or route traffic.

The useful mental model is:

1. An Ingress, Service, Gateway, HTTPRoute, or custom source declares a hostname.
2. A load balancer controller or gateway controller publishes an address in resource status.
3. ExternalDNS reads the hostname and target, filters it, compares it with provider records, and submits changes.
4. Recursive resolvers see the new answer only after provider publication and DNS TTL behavior allow it.

## Where It Fits

| Component | Job |
| --- | --- |
| CoreDNS | Answers cluster-internal names such as `service.namespace.svc.cluster.local` and forwards other Pod queries. |
| Ingress/Gateway/load balancer controller | Programs the actual edge proxy or external load balancer and writes status addresses. |
| ExternalDNS | Reconciles external or private-zone DNS records from Kubernetes source objects. |
| DNS provider | Stores authoritative records in a hosted zone or managed zone. |

If `dig app.example.com` returns nothing, do not start by debugging CoreDNS unless Pods are resolving the name differently than clients. ExternalDNS problems usually sit between Kubernetes object status, DNS-provider permissions, zone filters, TXT ownership records, and authoritative DNS publication.

## Sources and Hostnames

ExternalDNS can read multiple source types. The common ones are:

| Source | Typical Hostname Input | Typical Target |
| --- | --- | --- |
| `service` | `external-dns.alpha.kubernetes.io/hostname` on a `LoadBalancer` Service | Service status load balancer IP or hostname. |
| `ingress` | Ingress `spec.rules[].host`, TLS hosts, or hostname annotations | Ingress status address. |
| `gateway` / route sources | Gateway API listeners and attached routes, depending on configured source | Gateway or route status address. |
| `crd` | `DNSEndpoint` custom resources | Explicit targets and record types. |

The annotation prefix is still commonly `external-dns.alpha.kubernetes.io/` even though ExternalDNS itself is broadly used in production. Important annotations include:

| Annotation | Use |
| --- | --- |
| `external-dns.alpha.kubernetes.io/hostname` | Declares the DNS name or names to manage when the source does not infer enough from spec. |
| `external-dns.alpha.kubernetes.io/target` | Overrides the target address or hostname. Use carefully because it bypasses normal status-derived targets. |
| `external-dns.alpha.kubernetes.io/ttl` | Requests a TTL when the provider and configuration support it. |
| `external-dns.alpha.kubernetes.io/internal-hostname` | Can publish an internal name, often paired with internal services or private zones. |

## Ownership and Registry

Most production installs use the TXT registry. For each managed record, ExternalDNS creates related TXT metadata that identifies ownership, commonly with `--txt-owner-id`.

This matters because two clusters, two namespaces, or two ExternalDNS instances might point at the same hosted zone. A stable owner ID prevents controllers from stealing or deleting each other's records. Changing `--txt-owner-id`, `--txt-prefix`, or `--txt-suffix` after deployment can orphan registry records and make adoption or cleanup harder.

Use multiple ExternalDNS deployments when you need separate responsibility boundaries:

- one controller for public zones and another for private zones,
- one per cluster with distinct `--txt-owner-id`,
- one per tenant or platform area with separate `--domain-filter`, `--zone-id-filter`, labels, or annotations,
- one read-only dry-run instance during migration.

## Filters, Policy, and Provider Scope

ExternalDNS should not have permission to modify every DNS record in an account.

| Control | What It Limits |
| --- | --- |
| `--domain-filter` | A domain filter for candidate names and target zones by suffix, such as `apps.example.com`. |
| `--exclude-domains` / regex filters | Names that must not be managed even if another filter matches. |
| `--zone-id-filter` / provider zone filters | Specific hosted zone IDs or zone visibility, depending on provider. |
| `--source` | Which Kubernetes object types are watched. |
| `--policy=upsert-only` | Creates and updates records but avoids deleting records. Useful during cautious rollout. |
| `--policy=sync` | The sync policy attempts full reconciliation, including deleting records no longer desired. Useful but higher risk. |

Provider credentials should be least-privilege and zone-scoped. In cloud clusters, prefer workload identity or IAM roles for service accounts over long-lived static secrets when the provider supports it.

## Public, Private, and Split-Horizon DNS

ExternalDNS can manage public DNS, private DNS, or both, but split-horizon DNS needs explicit design. The same name might exist in a public zone and a private hosted zone with different answers. That is valid when intentional and confusing when accidental.

Common patterns:

- Public Ingress hostnames go to public authoritative zones and internet-facing load balancers.
- Internal services go to private zones and internal load balancers.
- Hybrid networks use conditional forwarding so corporate resolvers can reach private cloud zones.
- Bare-metal clusters behind NAT may publish an external IP that differs from the in-cluster or load balancer status address, often through target overrides or controller-specific configuration.

Always test DNS from the same network path as the client. A laptop using public DNS, a Pod using CoreDNS, and a VM using a corporate resolver may all receive different answers for the same name.

## DNS and Kubernetes Timing

ExternalDNS depends on other controllers. If a `LoadBalancer` Service has no external address yet, ExternalDNS may have no usable target. If an Ingress controller rejects an Ingress, the hostname can be syntactically present but still not routable.

DNS also has independent timing:

- provider APIs may batch or rate-limit changes,
- authoritative nameservers may publish quickly while recursive resolvers keep old cached answers until TTL expiry,
- negative caching can preserve an earlier NXDOMAIN after the record is created,
- low TTLs reduce future cache time but do not flush caches that already stored a higher TTL.

## Failure Modes

| Symptom | Likely Cause | Check |
| --- | --- | --- |
| No provider record appears | Hostname not declared, source disabled, namespace excluded, or domain filter mismatch. | Inspect the source object, controller args, and logs. |
| Record target is empty | Service, Ingress, or Gateway has no status address yet. | Check resource status and load balancer controller events. |
| Logs mention ownership conflict | TXT registry record belongs to another owner ID. | Compare `--txt-owner-id`, TXT records, and other ExternalDNS instances. |
| Public clients see private IPs | Public and private zone boundaries are wrong or controller targets the wrong zone. | Check zone filters, provider zone visibility, and authoritative NS. |
| Deleted service leaves DNS behind | Controller uses `upsert-only`, lacks delete permission, or registry ownership is lost. | Check policy, provider permissions, and TXT registry records. |
| CNAME/TXT conflicts | TXT registry record name collides with a CNAME or apex record pattern. | Review `--txt-prefix` / `--txt-suffix` and provider constraints. |
| Updates are slow | TTL, negative caching, provider batching, or API rate limits. | Query authoritative servers directly and compare recursive resolvers. |

## Commands

```bash
kubectl -n external-dns get deploy,sa,secret
kubectl -n external-dns logs deployment/external-dns
kubectl get ingress,svc,gateway,httproute --all-namespaces
kubectl describe ingress <name> -n <namespace>
dig <hostname>
```

Deeper checks:

```bash
kubectl -n external-dns describe deploy external-dns
kubectl -n external-dns logs deployment/external-dns --since=30m
kubectl get service <name> -n <namespace> -o yaml
kubectl get ingress <name> -n <namespace> -o yaml
kubectl get gateway <name> -n <namespace> -o yaml
dig +trace <hostname>
dig @<authoritative-ns> <hostname> A
dig @<authoritative-ns> <hostname> TXT
```

## Troubleshooting Flow

1. Identify the source object that should own the name.
2. Confirm the hostname is present in spec or annotation.
3. Confirm the source object has a usable status address.
4. Confirm ExternalDNS is watching that source, namespace, and ingress class or gateway class.
5. Confirm `--domain-filter` and zone filters include the name and zone.
6. Read ExternalDNS logs for desired endpoints, provider errors, and ownership conflicts.
7. Query the authoritative nameserver directly.
8. Compare recursive resolver answers and TTLs from the affected client network.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does ExternalDNS do?" answer="It watches Kubernetes resources and reconciles matching DNS records through a DNS provider API." %}
  {% include study-card.html question="Is ExternalDNS the same thing as CoreDNS?" answer="No. CoreDNS answers cluster DNS queries; ExternalDNS manages authoritative provider records outside the cluster DNS path." %}
  {% include study-card.html question="Why use a TXT registry and owner ID?" answer="They record which ExternalDNS instance owns a DNS record so multiple controllers or clusters do not overwrite each other." %}
  {% include study-card.html question="What does domain-filter protect?" answer="It limits which DNS names and zones ExternalDNS is allowed to consider for reconciliation." %}
  {% include study-card.html question="Why might ExternalDNS not create a record for a LoadBalancer Service yet?" answer="The Service may not have an external status address, or filters, source settings, permissions, or ownership checks may block it." %}
</div>

## References

- [ExternalDNS documentation](https://kubernetes-sigs.github.io/external-dns/latest/)
- [ExternalDNS flags](https://kubernetes-sigs.github.io/external-dns/latest/docs/flags/)
- [ExternalDNS TXT registry](https://kubernetes-sigs.github.io/external-dns/latest/docs/registry/txt/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/)
