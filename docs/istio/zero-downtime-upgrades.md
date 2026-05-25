---
title: Istio Zero Downtime Upgrades on Kubernetes
layout: page
permalink: /docs/istio/zero-downtime-upgrades/
summary: "Operational runbook for low-risk Istio upgrades on Kubernetes using canary control planes, revisions, revision tags, workload restarts, gateway canaries, rollback, PDBs, and validation gates."
tags:
  - istio
  - kubernetes
  - upgrades
  - operations
---

# Istio Zero Downtime Upgrades on Kubernetes

Zero downtime for an Istio upgrade is an operational target, not a command-line guarantee. The safe path is to run old and new control planes side by side, move workloads in controlled batches, keep enough application capacity available, and verify traffic at every step.

```mermaid
flowchart LR
  A[Install new revision] --> B[Analyze config]
  B --> C[Move revision tag or namespace label]
  C --> D[Restart workloads in batches]
  D --> E[Upgrade gateways]
  E --> F[Verify proxy-status and traffic]
  F --> G[Remove old revision]
```

## Upgrade Model

| Layer | Zero-Downtime Goal |
| --- | --- |
| CRDs | Apply compatible CRDs before depending on new fields; avoid removing fields still used by old config. |
| Control plane | Install a new revision beside the old one; do not replace the only working `istiod` first. |
| Sidecar data plane | Move namespaces by revision tag, then restart workloads with rolling-update settings. |
| Gateways | Run revision-specific gateway canaries or shift external traffic gradually. |
| Ambient data plane | Treat ztunnel as node-scoped; node drain or staged rollout may be needed for long-lived connections. |
| Applications | Use readiness, `maxUnavailable: 0`, enough replicas, and PDBs so pod restarts do not create user-visible gaps. |

<aside class="runbook-panel">
  <strong>Runbook shape:</strong> install a revisioned control plane, analyze config, move one namespace or gateway at a time, restart workloads in safe batches, verify proxy status and traffic, then remove the old revision.
</aside>

## Preflight Checks

```bash
istioctl version
istioctl x precheck
istioctl analyze --all-namespaces
istioctl proxy-status
kubectl get pods -n istio-system -o wide
kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration
kubectl get ns -L istio-injection,istio.io/rev,istio.io/dataplane-mode
kubectl get pdb --all-namespaces
```

Before changing anything, capture the current install method, profile, Helm values or IstioOperator settings, revision labels, gateway topology, and SLO-sensitive namespaces. Confirm the target Istio version supports the current Kubernetes version and that add-ons, CNI, gateways, and policy resources are compatible.

## Canary Control Plane

Install the new control plane as a separate revision. Version-shaped revision names avoid ambiguity; replace dots with dashes because revision labels cannot use arbitrary version strings.

```bash
istioctl install --revision=1-30-0 -f istio-values.yaml --skip-confirmation
kubectl get deploy,svc -n istio-system -l istio.io/rev=1-30-0
istioctl proxy-status
istioctl analyze --all-namespaces
```

Installing a new revision does not automatically move existing sidecars. Existing pods keep running against the control plane they were injected for until they are restarted with labels or tags that select the new revision.

## Revision Tags

Revision tags create stable labels for namespaces. Instead of relabeling every namespace from `1-29-1` to `1-30-0`, point namespaces at a tag such as `prod-stable`, then move the tag when ready.

```bash
istioctl tag set prod-stable --revision 1-29-1
istioctl tag set prod-canary --revision 1-30-0
istioctl tag list
kubectl label namespace payments istio.io/rev=prod-canary --overwrite
kubectl label namespace payments istio-injection- 2>/dev/null || true
```

Keep only one injection selector per namespace. A namespace with both `istio-injection=enabled` and `istio.io/rev=...` is harder to reason about and can be caught by analyzer warnings.

## Workload Rollout Guardrails

The control-plane migration happens when pods are recreated and reinjected. Kubernetes rollout settings decide whether that restart is safe.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 4
  minReadySeconds: 15
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  template:
    spec:
      terminationGracePeriodSeconds: 45
      containers:
        - name: api
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
```

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: api
```

Do not use `maxUnavailable: 0` with `maxSurge: 0`; Kubernetes requires at least one side of the rollout to move. For single-replica workloads, there is no real zero-downtime pod restart without adding a second ready replica or external failover.

## Moving a Namespace

```bash
kubectl label namespace payments istio.io/rev=prod-canary --overwrite
kubectl rollout restart deployment -n payments
kubectl rollout status deployment -n payments --timeout=10m
istioctl proxy-status | grep payments
kubectl get pods -n payments -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.labels.istio\.io/rev}{"\n"}{end}'
```

Validation gate:

1. New pods become Ready and stay Ready through `minReadySeconds`.
2. `istioctl proxy-status` shows the namespace connected to the expected `istiod` revision.
3. Error rate, p99 latency, TCP resets, and 503s do not regress.
4. AuthorizationPolicy, RequestAuthentication, PeerAuthentication, and VirtualService behavior match before and after.
5. Rollout can be paused or rolled back before more namespaces move.

## Gateway Upgrades

Gateways are user-facing blast-radius points. Avoid replacing every gateway instance in place unless downtime is acceptable.

Safer patterns:

- run a gateway deployment for the new revision with the same Gateway config selector strategy,
- shift external load balancer traffic gradually when possible,
- use separate gateway Services or load balancer target groups for old and new revisions,
- verify TLS secrets, SNI, route tables, and upstream clusters before shifting all traffic,
- keep the old gateway serving until the new path is proven.

```bash
kubectl get deploy,svc,pod -n istio-system -l istio=ingressgateway
istioctl proxy-config listeners deploy/istio-ingressgateway -n istio-system
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
istioctl proxy-config secret deploy/istio-ingressgateway -n istio-system
curl -vk --resolve app.example.com:443:<canary-lb-ip> https://app.example.com/
```

## Ambient Mode Notes

Ambient upgrades add ztunnel and waypoint considerations. Waypoints are gateway-style Envoy deployments and can use revision-aware rollout patterns. ztunnel is a DaemonSet, so an upgrade can affect all workloads on a node. For workloads with long-lived TCP connections, use node-level staging:

```bash
kubectl get daemonset -n istio-system ztunnel
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl rollout status daemonset/ztunnel -n istio-system --timeout=10m
kubectl uncordon <node>
```

This is slower, but it bounds disruption to workloads that Kubernetes can safely move and gives you a clear rollback point per node group.

## Rollback

Rollback should be prepared before rollout starts.

```bash
istioctl tag set prod-stable --revision 1-29-1 --overwrite
kubectl rollout restart deployment -n payments
kubectl rollout status deployment -n payments --timeout=10m
istioctl proxy-status | grep payments
```

If you installed a canary revision and decide not to proceed, uninstall only the canary after traffic has moved back and gateways are no longer depending on it.

```bash
istioctl uninstall --revision=1-30-0 -y
istioctl tag remove prod-canary
```

## Final Cutover and Cleanup

After every namespace and gateway has moved and remained stable for a full observation window:

1. Move the `default` revision tag if you use default injection.
2. Confirm no pods still connect to the old control plane.
3. Confirm no namespace points at the old revision or old tag.
4. Remove old revision tags.
5. Uninstall the old control plane revision.
6. Run analyzer and proxy sync checks again.

```bash
istioctl tag set default --revision 1-30-0 --overwrite
istioctl proxy-status
kubectl get ns -L istio.io/rev,istio-injection
istioctl tag list
istioctl uninstall --revision=1-29-1 -y
istioctl analyze --all-namespaces
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the safest Istio upgrade pattern for Kubernetes?" answer="Install the new control plane as a separate revision, move workloads in batches, and keep rollback to the old revision available." %}
  {% include study-card.html question="Why do existing sidecars not move when a new Istio revision is installed?" answer="Sidecars use the revision selected at injection time, so workloads must be restarted or recreated to use a new revision." %}
  {% include study-card.html question="What do Istio revision tags reduce?" answer="They reduce namespace relabeling by letting stable labels point to different concrete control-plane revisions." %}
  {% include study-card.html question="Why are gateways special during Istio upgrades?" answer="They are user-facing traffic entry points, so in-place replacement can affect all external traffic at once." %}
  {% include study-card.html question="Why can ambient ztunnel upgrades disrupt long-lived connections?" answer="ztunnel runs as a node-level DaemonSet, so upgrading it can affect traffic for workloads on that node." %}
</div>

## References

- [Istio Canary Upgrades](https://istio.io/latest/docs/setup/upgrade/canary/)
- [Istio In-place Upgrades](https://istio.io/latest/docs/setup/upgrade/in-place/)
- [Istio Installing Gateways](https://istio.io/latest/docs/setup/additional-setup/gateway/)
- [Istio Ambient Upgrade with Helm](https://istio.io/latest/docs/ambient/upgrade/helm/)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes PodDisruptionBudgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
