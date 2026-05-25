---
title: Networking TLS and mTLS Examples
layout: page
permalink: /docs/networking/practical-examples/
summary: "Practical networking examples for certificate inspection and mTLS requests."
tags:
  - examples
  - networking
  - tls
  - mtls
---

# Networking TLS and mTLS Examples

These examples complement [Networking](/docs/networking/), [certificates and HTTPS](/docs/networking/certificates-https/), [TCP, TLS, and HTTP](/docs/networking/tcp-tls-http/), and [firewalls, iptables, and Netfilter](/docs/networking/firewalls-iptables-netfilter/).

## TLS and mTLS Examples

Inspect the served certificate with SNI:

```bash
openssl s_client \
  -connect api.example.com:443 \
  -servername api.example.com \
  -showcerts </dev/null
```

Verify a client certificate and key match before using them for mTLS:

```bash
openssl x509 -in client.crt -noout -modulus | openssl sha256
openssl rsa -in client.key -noout -modulus | openssl sha256
openssl verify -CAfile client-ca.crt client.crt
```

Call an mTLS endpoint:

```bash
curl -v \
  --cert client.crt \
  --key client.key \
  --cacert server-ca.crt \
  https://admin-api.example.com/healthz
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why use SNI with openssl s_client?" answer="Many TLS endpoints choose the certificate based on the requested server name." %}
  {% include study-card.html question="Why compare client certificate and key modulus hashes?" answer="It verifies that the certificate and private key belong together before attempting mTLS." %}
  {% include study-card.html question="What does --cacert validate in an mTLS curl request?" answer="It pins the server trust root so the client validates the endpoint certificate chain." %}
</div>

## References

- [Certificates and HTTPS](/docs/networking/certificates-https/)
- [TCP, TLS, and HTTP](/docs/networking/tcp-tls-http/)
- [OpenSSL s_client](https://docs.openssl.org/master/man1/openssl-s_client/)
