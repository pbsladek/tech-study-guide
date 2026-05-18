---
title: Kubernetes
layout: page
permalink: /docs/kubernetes/
summary: Cluster architecture, reconciliation, networking, storage, and operations for modern Kubernetes.
tags:
  - kubernetes
  - infrastructure
  - orchestration
---

# Kubernetes

Kubernetes is an API-driven reconciliation system. You submit desired state as objects, the API server persists those objects, controllers observe them, and node agents make the actual workloads run. The important mental shift is that most components do not "call each other" in a long command chain. They watch the API, compare desired state to observed state, and take small corrective actions.

The current upstream release line is Kubernetes v1.36, released on April 22, 2026, while the official releases page also lists supported patch releases for earlier minor lines. Treat this guide as version-aware: always check release notes before upgrades, because feature gates, removals, and skew rules are operationally important.

## The Control Plane

The control plane is the cluster brain:

| Component | Job | Failure Shape |
| --- | --- | --- |
| `kube-apiserver` | Exposes the Kubernetes HTTP API, validates requests, runs admission, and writes accepted state to `etcd`. | If unavailable, new changes stop; existing Pods usually keep running. |
| `etcd` | Stores all persistent API state. | Data loss here is cluster-state loss. Backups and quorum matter. |
| `kube-scheduler` | Watches unscheduled Pods and binds them to suitable nodes. | New Pods stay Pending, but existing Pods continue. |
| `kube-controller-manager` | Runs built-in controllers such as Deployment, ReplicaSet, Node, Job, namespace, and endpoint controllers. | Desired state stops reconciling; drift accumulates. |
| `cloud-controller-manager` | Bridges Service load balancers, routes, and nodes to a cloud provider. | Cloud resources may not be created, updated, or cleaned up. |

The API server is the front door. Controllers and users do not write to `etcd` directly. That centralizes validation, authentication, authorization, admission, optimistic concurrency, audit logging, and watch delivery.

## Request Walkthrough

When you run:

```bash
kubectl apply -f deployment.yaml
```

the flow is roughly:

1. `kubectl` sends an authenticated request to the API server.
2. The API server authorizes the caller, validates the object schema, and runs admission plugins or webhooks.
3. The API server stores the object in `etcd`.
4. The Deployment controller notices a desired Deployment and creates or updates a ReplicaSet.
5. The ReplicaSet controller creates Pods.
6. The scheduler assigns each Pod to a node by writing a binding.
7. The node's kubelet sees Pods assigned to that node and asks the container runtime to start containers.
8. Status flows back through the kubelet to the API server.

This is why `kubectl apply` can return before containers are running. The write succeeded; reconciliation is still happening.

## Worker Node Responsibilities

Nodes are where Pods run:

| Component | Job |
| --- | --- |
| `kubelet` | Node agent. Watches assigned Pods, starts containers through CRI, mounts volumes, reports status, runs probes. |
| Container runtime | Runs containers. Common runtimes use the Container Runtime Interface. |
| `kube-proxy` or replacement | Implements Service virtual IP behavior, usually with iptables, IPVS, eBPF, or a CNI-integrated datapath. |
| CNI plugin | Gives Pods network interfaces and cluster-routable Pod IPs. |
| CSI node plugin | Attaches, stages, and mounts storage volumes when required. |

## What Kubernetes Does Not Do By Itself

Kubernetes defines APIs for many things without prescribing every implementation:

- Pod networking requires a CNI plugin.
- Persistent storage requires a storage backend and usually a CSI driver.
- `type: LoadBalancer` requires a cloud controller, load balancer controller, or bare-metal implementation.
- Ingress requires an Ingress controller. The Ingress API is stable but frozen; Gateway API is where new traffic-management features are developing.
- Backups are your responsibility. Kubernetes backs up neither application data nor `etcd` automatically.

## Operational Model

For operations, think in loops:

- **Declare:** write the desired state.
- **Observe:** check status, events, logs, metrics, and conditions.
- **Reconcile:** let controllers act, or fix the object/infrastructure when they cannot.
- **Protect:** define resource requests, PodDisruptionBudgets, probes, backup policies, and upgrade procedures.

The most useful troubleshooting question is: "Which controller owns the next step, and what condition or event says why it did not happen?"

## Study Path

- [Core Concepts](core-concepts/) for API objects, controllers, scheduling, and reconciliation.
- [Kubernetes Networking](networking/) for Pod networking, Services, CoreDNS, Ingress, Gateway API, and load balancers.
- [Storage and Upgrades](storage-upgrades/) for PV/PVC, CSI, StatefulSets, and kubeadm-style upgrade flow.
- [Troubleshooting](troubleshooting/) for incident entry points and practical commands.

## Commands

```bash
kubectl api-resources
kubectl get --raw /readyz?verbose
kubectl get events --all-namespaces --sort-by=.lastTimestamp
kubectl get componentstatuses
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why does Kubernetes use controllers?" answer="Controllers continuously compare desired state from the API with observed state and make small changes to reduce drift." %}
  {% include study-card.html question="What is the API server's role in the control plane?" answer="It is the front door for Kubernetes state: authn/authz, validation, admission, watch delivery, and persistence to etcd." %}
  {% include study-card.html question="What happens if the scheduler is down?" answer="Existing workloads continue, but newly created Pods that need a node remain Pending until scheduling resumes." %}
</div>

## Practice Deck

{% include study-card-deck.html deck="kubernetes" %}

## References

- [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/)
- [Kubernetes releases](https://kubernetes.io/releases/)
- [Kubernetes v1.36 release announcement](https://kubernetes.io/blog/2026/04/22/kubernetes-v1-36-release/)
