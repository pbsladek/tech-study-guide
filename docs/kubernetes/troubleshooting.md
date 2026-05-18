---
title: Troubleshooting
layout: page
permalink: /docs/kubernetes/troubleshooting/
summary: First checks and failure paths for common Kubernetes incidents.
tags:
  - kubernetes
  - troubleshooting
  - operations
---

# Kubernetes Troubleshooting

## First Checks

```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get events --sort-by=.lastTimestamp
```

## Common Paths

| Symptom | Check |
| --- | --- |
| Pod stuck pending | Node capacity, taints, tolerations, PVC binding. |
| CrashLoopBackOff | Container logs, command, env vars, missing config, probes. |
| Service unreachable | Selectors, endpoints, port names, NetworkPolicy, DNS. |
| Image pull failure | Image name, registry auth, tag existence, pull secret. |
