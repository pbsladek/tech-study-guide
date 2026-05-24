---
title: Core Concepts
layout: page
permalink: /docs/kubernetes/core-concepts/
summary: Kubernetes object model, controllers, scheduling, node agents, and reconciliation.
tags:
  - kubernetes
  - architecture
  - control-loops
---

# Kubernetes Core Concepts

Kubernetes is best understood as a set of independent control loops coordinated through the API server. Users write desired state. Controllers, schedulers, kubelets, and add-ons observe that state and update either the cluster or object status.

## API Machinery

The API server is not a passive database front end. It is the consistency boundary for Kubernetes state.

Request path for a normal write:

1. Authentication identifies the caller.
2. Authorization checks whether the caller can perform the verb on the resource.
3. Admission plugins and webhooks can default, validate, mutate, or reject the object.
4. Schema validation verifies known fields and types.
5. The API server writes accepted state to `etcd`.
6. Watches notify controllers, kubelets, and clients.

`resourceVersion` supports optimistic concurrency. If two clients update the same object from stale state, one update may conflict and must be retried from a fresh read. This is why controllers are written as reconciliation loops instead of one-shot scripts.

## Object Model

Every Kubernetes object has:

- **Metadata:** name, namespace, labels, annotations, owner references, finalizers, resource version.
- **Spec:** desired state written by a user, controller, or automation.
- **Status:** observed state written by controllers or node agents.

This spec/status split is central. If a Deployment says `replicas: 5` in `spec` but only three Pods are ready in `status`, the Deployment controller has not finished or cannot satisfy the desired state.

## Controllers and Ownership

Controllers are responsible for specific relationships:

| Controller | Watches | Creates or Updates |
| --- | --- | --- |
| Deployment controller | Deployments | ReplicaSets |
| ReplicaSet controller | ReplicaSets and Pods | Pods |
| StatefulSet controller | StatefulSets and Pods | Ordered Pods and PVCs |
| Job controller | Jobs and Pods | Pods until completions are reached |
| Node controller | Nodes | Node conditions and eviction-related signals |
| EndpointSlice controller | Services and Pods | EndpointSlices for Service backends |

Owner references let Kubernetes understand garbage collection. If a Deployment owns a ReplicaSet and the ReplicaSet owns Pods, deleting the Deployment can clean up the child resources unless propagation behavior is changed.

## Workload Primitives

Different workload APIs encode different ownership and identity assumptions:

| Workload | Best Fit | Important Behavior |
| --- | --- | --- |
| Deployment | Stateless replicated services. | Manages ReplicaSets and rolling updates. |
| StatefulSet | Pods that need stable network identity or stable PVCs. | Creates ordered Pods with predictable names and PVC ownership. |
| DaemonSet | One Pod per matching node. | Common for agents, CNI, log collectors, and storage plugins. |
| Job | Run-to-completion work. | Tracks completions and retries failed Pods. |
| CronJob | Scheduled Jobs. | Adds missed-run, concurrency, and history behavior around Jobs. |

Use the smallest controller that matches the lifecycle. A StatefulSet is not a generic "more reliable Deployment"; it trades rollout flexibility for stable identity and storage relationships.

## Scheduling

The scheduler only decides where a Pod should run. It does not start containers. Scheduling has two broad phases:

1. **Filtering:** remove nodes that cannot run the Pod because of resources, selectors, taints, volume constraints, topology, or other predicates.
2. **Scoring:** rank feasible nodes and bind the Pod to the best candidate.

Important knobs:

- `resources.requests` influence scheduling; `limits` influence runtime enforcement.
- `nodeSelector`, node affinity, and topology spread constraints place Pods deliberately.
- Taints repel Pods unless they have matching tolerations.
- PodDisruptionBudgets do not prevent all disruption; they constrain voluntary evictions.

## Resources and QoS

Requests and limits affect different layers:

- CPU and memory requests are scheduling signals and capacity reservations.
- CPU limits become cgroup CPU quota and can cause throttling.
- Memory limits become cgroup memory limits and can trigger OOM kills.
- Ephemeral storage requests and limits protect node local disk pressure when configured.

Kubernetes assigns Pods a QoS class:

| QoS Class | Shape | Eviction Implication |
| --- | --- | --- |
| Guaranteed | Every container has equal CPU and memory request/limit. | Last to evict under node pressure. |
| Burstable | Some requests or limits set, but not Guaranteed. | Middle priority for eviction. |
| BestEffort | No CPU or memory requests/limits. | First to evict under pressure. |

This explains why "it fit yesterday" is not enough. A Pod can schedule based on requests but later be throttled, OOMKilled, or evicted because runtime usage and node pressure changed.

## Kubelet and Pod Lifecycle

After a Pod is bound to a node, the kubelet:

- creates the Pod sandbox and network namespace,
- asks the CNI plugin to attach networking,
- pulls images through the runtime,
- mounts volumes,
- starts containers,
- runs startup, readiness, and liveness probes,
- reports Pod and Node status.

Readiness controls whether a Pod should receive Service traffic. Liveness controls whether kubelet restarts a container. Startup probes protect slow-starting apps from premature liveness failures.

## CRDs and Operators

CustomResourceDefinitions extend the Kubernetes API with new resource types. Operators are controllers that reconcile those custom resources into real infrastructure state.

Examples:

- ExternalDNS watches Services, Ingresses, Gateways, or custom sources and reconciles provider DNS records.
- Rook watches Ceph custom resources and reconciles Ceph daemons, pools, and CSI integration.
- CloudNativePG watches PostgreSQL cluster resources and reconciles Pods, failover, backups, and services.

Operator-managed systems have two layers of truth: the Kubernetes object status and the underlying system status. During incidents, inspect both. A custom resource can be accepted by the API while the operator cannot satisfy it because of storage, credentials, permissions, admission policy, or external API failures.

## Finalizers

Finalizers are strings on metadata that block deletion until cleanup is done. They are useful for cloud resources, PV cleanup, external DNS records, and operator-managed state. A stuck finalizer means the object has a deletion timestamp but a controller has not removed the finalizer.

## Conditions

Modern Kubernetes APIs use conditions to explain state. A condition usually has:

- `type`
- `status`
- `reason`
- `message`
- `lastTransitionTime`

Read conditions before guessing. They are the controller's explanation of what it sees.

## Commands

```bash
kubectl get pods --all-namespaces
kubectl describe pod <pod-name>
kubectl explain deployment.spec
kubectl get deployment <name> -o yaml
kubectl get pod <pod-name> -o jsonpath='{.status.conditions}'
```

## Failure Patterns

| Symptom | Likely Layer | First Checks |
| --- | --- | --- |
| Pod stays Pending | Scheduler | Events, resource requests, taints, PVC binding, node selectors |
| Pod starts but gets no traffic | Service readiness | Readiness probe, EndpointSlices, labels/selectors |
| Pod is Terminating forever | Finalizers or node issue | Metadata finalizers, kubelet reachability, volume detach |
| Deployment rollout stalls | Deployment/ReplicaSet | `kubectl rollout status`, maxUnavailable, failing new Pods |
| StatefulSet replacement stuck | Storage or identity | PVC state, volume attachment, ordered rollout |
| Custom resource accepted but nothing happens | Operator | Operator logs, CR conditions, RBAC, webhook, external API credentials |
| Pod evicted under pressure | Node/kubelet | QoS class, node conditions, ephemeral storage, memory pressure |

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the smallest deployable unit in Kubernetes?" answer="A Pod. It wraps one or more tightly coupled containers that share networking and storage context." %}
  {% include study-card.html question="What is the difference between spec and status?" answer="Spec is desired state. Status is observed state reported by controllers or node agents." %}
  {% include study-card.html question="Does the scheduler start containers?" answer="No. It binds Pods to nodes. The kubelet on the selected node starts containers." %}
  {% include study-card.html question="What does admission do in Kubernetes?" answer="Admission plugins and webhooks can default, mutate, validate, or reject API requests before they are persisted." %}
  {% include study-card.html question="What is a CRD?" answer="A CustomResourceDefinition extends the Kubernetes API with a new resource type that controllers or operators can reconcile." %}
  {% include study-card.html question="What does Kubernetes QoS affect?" answer="QoS class influences eviction priority under node pressure and depends on container CPU and memory requests and limits." %}
  {% include study-card.html question="Why can a Kubernetes object be stuck deleting?" answer="A finalizer may be waiting for a controller to finish cleanup before the API server removes the object." %}
  {% include study-card.html question="What does readiness affect?" answer="Whether a Pod endpoint should receive Service traffic. It is separate from process liveness." %}
</div>

## References

- [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- [Kubernetes concepts](https://kubernetes.io/docs/concepts/)
