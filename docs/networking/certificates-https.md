---
title: Certificates and HTTPS
layout: page
permalink: /docs/networking/certificates-https/
summary: "TLS certificates, HTTPS handshakes, chains of trust, SANs, SNI, OCSP, CA stores, and Ubuntu certificate operations."
tags:
  - networking
  - tls
  - certificates
  - https
---

# Certificates and HTTPS

HTTPS is HTTP carried over TLS. The certificate part proves the server identity to the client, while the TLS handshake negotiates keys and protects the traffic. Many production incidents are not "the network" or "the app"; they are trust-chain, SNI, SAN, intermediate certificate, or CA-store problems.

## First Checks

```bash
openssl s_client -connect example.com:443 -servername example.com -showcerts
curl -Iv https://example.com/
openssl x509 -in server.crt -noout -text
update-ca-certificates --fresh
ls -l /etc/ssl/certs/ca-certificates.crt
```

On Ubuntu and Debian systems, the system trust store is managed by the `ca-certificates` package and `update-ca-certificates`. Custom local root CAs normally go in `/usr/local/share/ca-certificates/` with a `.crt` extension, then `sudo update-ca-certificates` rebuilds `/etc/ssl/certs` and `/etc/ssl/certs/ca-certificates.crt`.

## Certificate Chain

| Part | Meaning |
| --- | --- |
| Leaf certificate | The server certificate for the DNS name clients connect to. |
| Intermediate CA | CA certificate that signs the leaf and chains to a root. |
| Root CA | Trust anchor already present in a client trust store. |
| SAN | Subject Alternative Name list; modern clients validate hostnames here. |
| Key usage / extended key usage | Declares whether the certificate can be used for server auth, client auth, signing, and other purposes. |

The server usually sends the leaf plus intermediates. It should not need to send the root. If the server omits an intermediate, some clients fail while others succeed because they have cached or fetched the intermediate elsewhere.

## SNI and Virtual Hosting

SNI is the hostname in the TLS ClientHello. A server can present different certificates for the same IP and port based on SNI. Always include `-servername` in `openssl s_client` tests when debugging HTTPS virtual hosts.

## Handshake Model

1. Client opens TCP.
2. Client sends TLS ClientHello with SNI, supported versions, cipher suites, and extensions.
3. Server selects TLS parameters and sends certificate chain.
4. Client validates time, hostname, trust chain, key usage, and revocation policy if configured.
5. Client and server derive session keys.
6. HTTP starts inside the encrypted channel.

## Common Failures

- certificate expired or not yet valid,
- hostname missing from SAN,
- SNI mismatch,
- missing intermediate CA,
- server sends wrong certificate,
- local CA store missing a corporate root,
- private key does not match certificate,
- TLS version or cipher policy mismatch,
- HTTPS proxy intercepts traffic with an untrusted root,
- app runtime uses its own CA bundle instead of the OS trust store.

## Ubuntu Operations

```bash
sudo apt update
sudo apt install ca-certificates openssl
sudo cp corp-root-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt server.crt
```

Browsers, Java, Python virtual environments, containers, and language runtimes may not use the same CA bundle as Ubuntu's OpenSSL store. For containers, install `ca-certificates` inside the image and copy trusted corporate roots into the image or mount them deliberately.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does HTTPS add to HTTP?" answer="A TLS layer that authenticates the server, negotiates encryption keys, and protects HTTP traffic." %}
  {% include study-card.html question="Why does SNI matter for certificates?" answer="It lets one IP and port serve different certificates based on the requested hostname." %}
  {% include study-card.html question="Where do custom Ubuntu root CAs normally go?" answer="/usr/local/share/ca-certificates/ followed by sudo update-ca-certificates." %}
</div>

## References

- [RFC 8446: TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 5280: PKIX Certificate and CRL Profile](https://www.rfc-editor.org/rfc/rfc5280)
- [Ubuntu: Install a root CA certificate in the trust store](https://ubuntu.com/server/docs/how-to/security/install-a-root-ca-certificate-in-the-trust-store/)
- [Ubuntu update-ca-certificates(8)](https://manpages.ubuntu.com/manpages/jammy/man8/update-ca-certificates.8.html)
