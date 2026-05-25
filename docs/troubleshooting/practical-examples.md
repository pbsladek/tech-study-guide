---
title: Troubleshooting Examples
layout: page
permalink: /docs/troubleshooting/practical-examples/
summary: "Practical troubleshooting examples for repeatable incident capture and evidence preservation."
tags:
  - examples
  - troubleshooting
  - operations
---

# Troubleshooting Examples

These examples complement [Troubleshooting and Error Handling](/docs/troubleshooting/) and [Logs and Observability](/docs/linux/logs-observability/).

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

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why capture incident evidence into files?" answer="It preserves volatile state and makes the timeline reviewable after the system changes." %}
  {% include study-card.html question="Why include timestamps and host identity in incident capture?" answer="They make evidence correlatable across systems, logs, and later handoffs." %}
  {% include study-card.html question="Why use best-effort commands with || true in capture scripts?" answer="One missing tool or failed command should not stop the rest of the evidence collection." %}
</div>

## References

- [Troubleshooting and Error Handling](/docs/troubleshooting/)
- [Logs and Observability](/docs/linux/logs-observability/)
