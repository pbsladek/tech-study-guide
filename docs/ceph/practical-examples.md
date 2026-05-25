---
title: Ceph Storage Examples
layout: page
permalink: /docs/ceph/practical-examples/
summary: "Practical Ceph examples for cluster health, replicated pool creation, and RBD image operations."
tags:
  - examples
  - ceph
  - storage
---

# Ceph Storage Examples

These examples complement [Ceph](/docs/ceph/), [RADOS, CRUSH, and Placement](/docs/ceph/rados-crush-placement/), and [Block, File, and Object Interfaces](/docs/ceph/block-file-object/).

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

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why check ceph -s before changing pools?" answer="It shows whether the cluster is already degraded, recovering, or blocked before adding more change." %}
  {% include study-card.html question="What does pool size 3 mean in a replicated Ceph pool?" answer="Ceph stores three replicas of each object when placement and health allow it." %}
  {% include study-card.html question="Why snapshot an RBD image before maintenance?" answer="It provides a point-in-time rollback marker for the block image, subject to application consistency." %}
</div>

## References

- [Ceph pools](https://docs.ceph.com/en/latest/rados/operations/pools/)
- [Ceph RBD](https://docs.ceph.com/en/latest/rbd/)
- [Ceph health checks](https://docs.ceph.com/en/latest/rados/operations/health-checks/)
