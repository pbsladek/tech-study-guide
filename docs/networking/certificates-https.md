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

## Command Examples

```bash
openssl s_client -connect example.com:443 -servername example.com -showcerts
curl -Iv https://example.com/
openssl x509 -in server.crt -noout -text
update-ca-certificates --fresh
ls -l /etc/ssl/certs/ca-certificates.crt
```

Example output and meaning:

| Command | Example output | What it does |
| --- | --- | --- |
| `openssl s_client -connect example.com:443 -servername example.com -showcerts` | Certificate chain, `notAfter`, issuer, and `Verify return code: 0 (ok)`. | Shows the certificate chain served for the exact SNI. |
| `curl -Iv https://example.com/` | TLS version, certificate match, and HTTP status. | Tests how a normal HTTPS client sees the endpoint. |
| `openssl x509 -in server.crt -noout -text` | SANs, key usage, issuer, and expiry. | Inspects a local certificate file before installing or serving it. |

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

## Chain Validation Checklist

A client validating a normal HTTPS server certificate checks more than "is it signed":

1. Build a chain from leaf to a trusted root.
2. Verify every signature in the chain.
3. Check current time against `notBefore` and `notAfter`.
4. Check the requested hostname against the SAN extension.
5. Confirm key usage and extended key usage allow server authentication.
6. Apply path length, name constraints, and CA basic constraints.
7. Apply local policy for weak algorithms, key sizes, revocation, and trust anchors.

Different clients can disagree because they use different trust stores, chain-building logic, revocation policy, or cached intermediates. This is common with browsers, Java, Python, containers, appliances, and corporate TLS inspection.

## SNI and Virtual Hosting

SNI is the hostname in the TLS ClientHello. A server can present different certificates for the same IP and port based on SNI. Always include `-servername` in `openssl s_client` tests when debugging HTTPS virtual hosts.

## Handshake Model

1. Client opens TCP.
2. Client sends TLS ClientHello with SNI, supported versions, cipher suites, and extensions.
3. Server selects TLS parameters and sends certificate chain.
4. Client validates time, hostname, trust chain, key usage, and revocation policy if configured.
5. Client and server derive session keys.
6. HTTP starts inside the encrypted channel.

## mTLS

Mutual TLS adds client certificate authentication. The server still presents its certificate, but it also asks the client for a certificate and validates that client certificate against a trusted client CA or policy.

mTLS is common for service-to-service traffic, private APIs, service meshes, and administrative endpoints. It answers "which client certificate key was presented," not automatically "which human user is allowed." Applications still need authorization rules that map certificate identity, SPIFFE ID, subject, SAN, or issuer to permissions.

Common mTLS failures:

- server trusts public roots but not the private client CA,
- client certificate lacks client-auth EKU,
- client sends the wrong certificate or no certificate,
- proxy terminates TLS before the app sees the client certificate,
- certificate identity does not match the app's authorization policy.

Practical mTLS checks:

```bash
openssl verify -CAfile client-ca.pem -purpose sslclient client.crt
openssl x509 -in client.crt -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage
curl -vk --cert client.crt --key client.key --cacert server-ca.pem https://api.example.com/
```

If a proxy terminates TLS, decide explicitly whether the backend should trust a forwarded identity header, PROXY protocol metadata, a new internal mTLS connection, or no client identity at all. Forwarded identity is security-sensitive and should be accepted only from trusted proxies.

## Certificate Lifecycle

Certificate incidents are usually lifecycle incidents:

- issuance: CSR, ACME, internal CA, or provider workflow,
- placement: load balancer, ingress, reverse proxy, application, or container image,
- renewal: automation, DNS challenge, HTTP challenge, or operator reconciliation,
- rotation: overlap old and new certificates and keys where possible,
- revocation: understand whether clients actually check OCSP or CRLs,
- inventory: know which endpoint, hostname, and trust store uses each certificate.

Short-lived certificates reduce stale credential risk but require reliable automation and monitoring. Long-lived certificates reduce renewal frequency but increase blast radius when keys leak or ownership changes.

For zero-trust network designs, certificate rotation needs trust overlap: deploy new roots or intermediates to validators before serving new leaf certificates, verify SNI and ALPN behavior at the edge, and remove old trust only after old leaves and long-lived clients are gone.

## Certificate Rotation Runbook

Root or intermediate rotation:

1. Inventory endpoints, clients, trust stores, containers, Java stores, meshes, and appliances.
2. Add the new root or intermediate to validators while keeping the old trust chain.
3. Issue test leaf certificates from the new chain.
4. Validate served chain, SNI, ALPN, hostname SAN, and EKU from real clients.
5. Roll new leaf certificates through load balancers, ingress, proxies, and apps.
6. Monitor old-chain usage until it reaches zero.
7. Remove old trust roots only after old leaves expire or are fully removed.

mTLS client CA rotation:

```text
server trusts old client CA + new client CA
clients receive certificates from new CA
server logs confirm new issuer/SPIFFE/SAN identities
old client CA is removed after old clients are gone
rollback keeps old CA trusted until cutover is proven
```

Validation commands:

```bash
openssl verify -CAfile combined-client-ca.pem -purpose sslclient new-client.crt
openssl verify -CAfile new-server-ca.pem -purpose sslserver -verify_hostname api.example.com server.crt
printf '' | openssl s_client -connect api.example.com:443 -servername api.example.com -alpn h2 -showcerts
curl -vk --cert new-client.crt --key new-client.key --cacert new-server-ca.pem https://api.example.com/
```

Rollback is a trust decision: keep the old issuer trusted until every dependent client and server has proven the new chain works.

## Certificate Management Examples

Generate a private key and CSR with Subject Alternative Names. Modern HTTPS clients validate SANs; do not rely on the Common Name alone.

```bash
cat > server-csr.cnf <<'EOF'
[ req ]
default_bits = 3072
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[ dn ]
CN = app.example.com
O = Example Org

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = app.example.com
DNS.2 = www.app.example.com
IP.1 = 192.0.2.20
EOF

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out server.key
chmod 600 server.key
openssl req -new -key server.key -out server.csr -config server-csr.cnf
openssl req -in server.csr -noout -text
```

Create a short-lived local lab CA and issue a server certificate. This is useful for learning and isolated test environments, not for public production trust.

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out lab-root-ca.key
openssl req -x509 -new -nodes \
  -key lab-root-ca.key \
  -sha256 \
  -days 365 \
  -subj "/CN=Lab Root CA/O=Example Org" \
  -out lab-root-ca.crt

cat > server-ext.cnf <<'EOF'
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:app.example.com,DNS:www.app.example.com,IP:192.0.2.20
EOF

openssl x509 -req \
  -in server.csr \
  -CA lab-root-ca.crt \
  -CAkey lab-root-ca.key \
  -CAcreateserial \
  -out server.crt \
  -days 90 \
  -sha256 \
  -extfile server-ext.cnf
```

Verify the certificate, its hostname, its purpose, and whether the private key matches. Prefer these checks before installing a certificate into a load balancer or web server.

```bash
openssl verify -CAfile lab-root-ca.crt -purpose sslserver -verify_hostname app.example.com server.crt
openssl x509 -in server.crt -noout -subject -issuer -dates -ext subjectAltName -ext extendedKeyUsage
openssl x509 -in server.crt -noout -pubkey | openssl pkey -pubin -outform DER | openssl sha256
openssl pkey -in server.key -pubout -outform DER | openssl sha256
```

Inspect a live endpoint, capture its served chain, and check expiration. Always send SNI with `-servername` when the endpoint hosts multiple names.

```bash
printf '' | openssl s_client \
  -connect app.example.com:443 \
  -servername app.example.com \
  -showcerts > served-chain.pem

openssl x509 -in served-chain.pem -noout -subject -issuer -dates -fingerprint -sha256
openssl x509 -in served-chain.pem -checkend 1209600 -noout
curl -vI --resolve app.example.com:443:192.0.2.20 https://app.example.com/
```

`-checkend 1209600` exits nonzero if the certificate expires within 14 days. Use that shape in monitoring, but alert on the actual public endpoint as well as files on disk so reload mistakes are caught.

Install and remove a private root CA on Ubuntu or Debian:

```bash
sudo install -m 0644 lab-root-ca.crt /usr/local/share/ca-certificates/lab-root-ca.crt
sudo update-ca-certificates
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt server.crt

sudo rm /usr/local/share/ca-certificates/lab-root-ca.crt
sudo update-ca-certificates --fresh
```

Certbot examples for a host where the web server already serves `/.well-known/acme-challenge/` from `/var/www/html`:

```bash
sudo certbot certonly --webroot \
  -w /var/www/html \
  -d app.example.com \
  -d www.app.example.com

sudo certbot certificates
sudo certbot renew --dry-run
sudo certbot renew --deploy-hook "systemctl reload nginx"
```

For Nginx, point at Certbot's stable symlink paths and reload after renewal. Test the config before reload.

```nginx
server {
  listen 443 ssl http2;
  server_name app.example.com;

  ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

  location / {
    proxy_pass http://127.0.0.1:8080;
  }
}
```

```bash
sudo nginx -t
sudo systemctl reload nginx
printf '' | openssl s_client -connect app.example.com:443 -servername app.example.com -brief
```

In Kubernetes, cert-manager models certificate issuance as an Issuer or ClusterIssuer plus a Certificate resource. The exact ACME solver depends on DNS and ingress ownership.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ops@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: nginx
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-example-com
  namespace: apps
spec:
  secretName: app-example-com-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - app.example.com
    - www.app.example.com
```

```bash
kubectl -n apps describe certificate app-example-com
kubectl -n apps get certificaterequest,order,challenge
kubectl -n apps get secret app-example-com-tls -o jsonpath='{.type}'
```

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
  {% include study-card.html question="What does mTLS add?" answer="The server also validates a client certificate, allowing certificate-based client identity." %}
  {% include study-card.html question="Why can two clients disagree on the same certificate?" answer="They may use different trust stores, chain builders, revocation policy, cached intermediates, or TLS libraries." %}
  {% include study-card.html question="What should you verify before installing a certificate?" answer="The chain, hostname SANs, validity dates, server-auth purpose, and that the private key matches the certificate." %}
  {% include study-card.html question="Why monitor the served endpoint instead of only cert files?" answer="A renewed file does not prove the proxy or load balancer reloaded and is serving the new certificate." %}
</div>

## References

- [RFC 8446: TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446)
- [RFC 5280: PKIX Certificate and CRL Profile](https://www.rfc-editor.org/rfc/rfc5280)
- [Ubuntu: Install a root CA certificate in the trust store](https://ubuntu.com/server/docs/how-to/security/install-a-root-ca-certificate-in-the-trust-store/)
- [Ubuntu update-ca-certificates(8)](https://manpages.ubuntu.com/manpages/jammy/man8/update-ca-certificates.8.html)
- [OpenSSL x509 command](https://docs.openssl.org/3.4/man1/openssl-x509/)
- [OpenSSL verify command](https://docs.openssl.org/3.1/man1/openssl-verify/)
- [Certbot instructions](https://certbot.eff.org/instructions)
- [cert-manager documentation](https://cert-manager.io/docs/)
