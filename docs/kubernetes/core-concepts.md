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

## Scheduling

The scheduler only decides where a Pod should run. It does not start containers. Scheduling has two broad phases:

1. **Filtering:** remove nodes that cannot run the Pod because of resources, selectors, taints, volume constraints, topology, or other predicates.
2. **Scoring:** rank feasible nodes and bind the Pod to the best candidate.

Important knobs:

- `resources.requests` influence scheduling; `limits` influence runtime enforcement.
- `nodeSelector`, node affinity, and topology spread constraints place Pods deliberately.
- Taints repel Pods unless they have matching tolerations.
- PodDisruptionBudgets do not prevent all disruption; they constrain voluntary evictions.

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

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is the smallest deployable unit in Kubernetes?" answer="A Pod. It wraps one or more tightly coupled containers that share networking and storage context." %}
  {% include study-card.html question="What is the difference between spec and status?" answer="Spec is desired state. Status is observed state reported by controllers or node agents." %}
  {% include study-card.html question="Does the scheduler start containers?" answer="No. It binds Pods to nodes. The kubelet on the selected node starts containers." %}
  {% include study-card.html question="Why can a Kubernetes object be stuck deleting?" answer="A finalizer may be waiting for a controller to finish cleanup before the API server removes the object." %}
  {% include study-card.html question="What does readiness affect?" answer="Whether a Pod endpoint should receive Service traffic. It is separate from process liveness." %}
</div>

## References

- [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- [Kubernetes concepts](https://kubernetes.io/docs/concepts/)
