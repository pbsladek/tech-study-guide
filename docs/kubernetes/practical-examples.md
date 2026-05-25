---
title: Kubernetes Examples
layout: page
permalink: /docs/kubernetes/practical-examples/
summary: "Practical Kubernetes examples for Deployments, Services, PodDisruptionBudgets, NetworkPolicy, and StatefulSet storage."
tags:
  - examples
  - kubernetes
  - networkpolicy
  - storage
---

# Kubernetes Examples

These examples complement [Kubernetes](/docs/kubernetes/), [NetworkPolicy](/docs/kubernetes/network-policy/), [Services and EndpointSlices](/docs/kubernetes/services-endpointslices/), and [Storage and Upgrades](/docs/kubernetes/storage-upgrades/).

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

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What makes a Kubernetes Deployment example operationally useful?" answer="It shows selectors, resources, probes, rollout behavior, and how traffic attaches to the workload." %}
  {% include study-card.html question="Why pair a Service selector with stable labels?" answer="Service endpoints are derived from matching Pods, so labels are the contract between workload and traffic routing." %}
  {% include study-card.html question="Why include DNS egress in a default-deny NetworkPolicy example?" answer="Most applications need name resolution, and default-deny egress breaks DNS unless it is explicitly allowed." %}
</div>

## References

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
