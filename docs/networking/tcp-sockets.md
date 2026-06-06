---
title: TCP and Sockets
layout: page
permalink: /docs/networking/tcp-sockets/
summary: "TCP state, sockets, listen queues, receive/send buffers, TIME_WAIT, retransmits, keepalive, ephemeral ports, and Linux observability."
tags:
  - networking
  - tcp
  - sockets
  - linux
---

# TCP and Sockets

Sockets are the application-facing API. TCP is the transport protocol that turns packets into a reliable ordered byte stream. To debug full-stack failures, you need to know the difference between a listening socket, a connected socket, a kernel queue, a retransmission, a timeout, and an application read or write stall.

## Command Examples

```bash
ss -ltnp
ss -tan state established
ss -ti dst 203.0.113.10
sysctl net.ipv4.ip_local_port_range
sysctl net.core.somaxconn
cat /proc/net/sockstat
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `ss -ltnp` | `Listening, established, TIME_WAIT, queues, PIDs, or socket summaries.` | Shows socket state and whether applications are listening or backpressured. |
| `ss -tan state established` | `Listening, established, TIME_WAIT, queues, PIDs, or socket summaries.` | Shows socket state and whether applications are listening or backpressured. |
| `ss -ti dst 203.0.113.10` | `Listening, established, TIME_WAIT, queues, PIDs, or socket summaries.` | Shows socket state and whether applications are listening or backpressured. |

## Socket Lifecycle

1. Server creates a socket, binds address/port, and listens.
2. Client creates a socket and connects.
3. TCP handshake creates connection state on both endpoints.
4. Application reads and writes byte streams.
5. Kernel buffers data, acknowledges data, retransmits losses, and applies flow and congestion control.
6. Either endpoint closes; TCP state transitions handle remaining data and delayed packets.

## Listen Queues

A listening service has queues for connection setup and accepted connections. If the service does not call `accept()` fast enough, clients may see timeouts or resets even though the process is running.

Important knobs:

- `net.core.somaxconn`,
- application listen backlog,
- SYN backlog behavior,
- accept loop performance,
- per-process file descriptor limits.

## Buffers, Windows, and Backpressure

TCP send and receive buffers absorb differences between application speed and network speed. If the receiver stops reading, the receive window can shrink and backpressure the sender. If the sender writes faster than the network can carry, send buffers fill and writes block or fail depending on socket mode.

## TIME_WAIT and Ephemeral Ports

`TIME_WAIT` is normal. It protects future connections from delayed packets from old connections. Client-heavy systems can run out of ephemeral ports if they open many short connections to the same destination tuple.

## Keepalive and Timeouts

TCP keepalive is not the same as application health. It only checks whether a TCP connection still appears alive after configured idle periods. Proxies and load balancers often have lower idle timeouts than OS keepalive defaults.

## Practical Failure Examples

Separate refused, reset, timeout, and stalled connections before tuning buffers.

| Error | Packet Evidence | Common Cause |
| --- | --- | --- |
| Connection refused | SYN followed by RST. | Nothing listening, wrong port, active firewall reject, stale Service endpoint. |
| Connection timed out | SYN retransmits without SYN-ACK. | Drop, route, NAT, listener, security group, or return-path failure. |
| Connection reset | RST after connection exists. | App abort, proxy idle timeout, protocol violation, firewall, or load balancer. |
| Write stalls | Send queue grows in `ss`. | Receiver not reading, congestion, flow-control window, or proxy buffering. |

```bash
tcpdump -nn -i any 'host 203.0.113.10 and tcp[tcpflags] & (tcp-syn|tcp-ack|tcp-rst|tcp-fin) != 0'
ss -tanpi dst 203.0.113.10
ss -ltnp '( sport = :8080 )'
```

For client-heavy services, check ephemeral ports and TIME_WAIT before raising random TCP tunables:

```bash
sysctl net.ipv4.ip_local_port_range
ss -tan state time-wait | wc -l
cat /proc/net/sockstat
```

## Ubuntu Notes

On Ubuntu and Debian, package the tools you need explicitly:

```bash
sudo apt update
sudo apt install iproute2 netcat-openbsd tcpdump conntrack procps
ss -s
journalctl -k -g 'TCP|conntrack|martian|SYN'
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is a listening socket?" answer="A server-side socket bound to an address and port waiting for incoming connection attempts." %}
  {% include study-card.html question="Why can a service listen but clients still time out?" answer="Queues, firewall policy, accept-loop stalls, SYN backlog, or return-path problems can fail connections after the process binds." %}
  {% include study-card.html question="Why is TIME_WAIT normal?" answer="It keeps connection identity around so delayed packets from an old connection do not corrupt a future one." %}
  {% include study-card.html question="What distinguishes refused from timed-out TCP connects?" answer="Refused returns a reset; timed-out connects show retransmitted SYNs without a usable response." %}
</div>

## References

- [RFC 9293: Transmission Control Protocol](https://www.rfc-editor.org/rfc/rfc9293)
- [socket(7)](https://man7.org/linux/man-pages/man7/socket.7.html)
- [tcp(7)](https://man7.org/linux/man-pages/man7/tcp.7.html)
- [ss(8)](https://man7.org/linux/man-pages/man8/ss.8.html)
