---
title: DNS Records, Responses, and Transport
layout: page
permalink: /docs/dns/records-transport-operations/
summary: "DNS record types, response codes, EDNS, UDP and TCP transport, truncation, reverse DNS, mail records, and operational debugging."
tags:
  - dns
  - operations
  - troubleshooting
---

# DNS Records, Responses, and Transport

DNS operations are not only A records and TTLs. Operators need to recognize response codes, understand when DNS uses UDP or TCP, know why EDNS changes packet size behavior, and separate record-data problems from resolver, firewall, and transport problems.

## First Checks

```bash
dig example.com A
dig example.com AAAA
dig example.com MX
dig example.com TXT
dig +bufsize=1232 example.com DNSKEY
dig +tcp example.com DNSKEY
dig -x 203.0.113.10
```

## Records Operators Should Recognize

| Record | Meaning | Common operational issue |
| --- | --- | --- |
| A / AAAA | IPv4 / IPv6 address data. | Broken dual stack when AAAA exists but IPv6 path is bad. |
| CNAME | Alias to another canonical name. | Long chains add latency and each target has its own failure modes. |
| NS | Authoritative nameservers for a zone. | Parent and child NS sets can drift. |
| SOA | Zone authority metadata. | Negative caching and serial drift depend on SOA data. |
| MX | Mail exchangers. | MX targets must be names, not raw addresses. |
| TXT | Text metadata. | SPF, DKIM, and verification records often break through quoting or splitting mistakes. |
| SRV | Service discovery with priority, weight, port, and target. | Target is a name and must not be an address literal. |
| PTR | Reverse DNS. | Reverse zones are delegated separately from forward zones. |
| CAA | Certificate authority authorization. | Incorrect CAA can block certificate issuance. |

## Response Codes

The answer section is not the whole result. The DNS response code tells you whether the server considered the query successful.

| Code | Meaning | Operator interpretation |
| --- | --- | --- |
| NOERROR | Query completed. | The name may still have NODATA for the requested type. |
| NXDOMAIN | Name does not exist. | Can be negatively cached. |
| SERVFAIL | Server failed to complete the query. | Often DNSSEC, upstream timeout, lame delegation, or resolver policy. |
| REFUSED | Server refuses the query. | Common with recursion disabled or ACL policy. |
| FORMERR | Server did not understand the query. | Can point to EDNS, middlebox, or software compatibility issues. |

NODATA is not a response code. It is a NOERROR response where the name exists but has no record set for the requested type.

## UDP, TCP, EDNS, and Truncation

Classic DNS uses UDP for most queries and TCP for zone transfers and responses that need reliable transport. Modern DNS also uses TCP when UDP responses are truncated. EDNS allows clients and servers to signal larger UDP payload sizes and options, but middleboxes and firewalls can still break large DNS responses.

Operational rules:

- test both UDP and TCP port 53,
- do not assume DNS is always a tiny UDP packet,
- watch the `TC` truncated flag in responses,
- consider DNSSEC and large TXT records when packet size changes,
- avoid blocking all ICMP because it can break path MTU behavior for large DNS responses.

## Reverse DNS and Mail Records

Reverse DNS lives under `in-addr.arpa` for IPv4 and `ip6.arpa` for IPv6. Forward and reverse zones are independent, so fixing an A record does not fix PTR data.

Mail-related DNS commonly spans MX, SPF in TXT, DKIM selector records, DMARC policy records, PTR, and sometimes MTA-STS or TLS reporting records. A mail incident can be a DNS incident even when web traffic works.

## Debugging Flow

1. Read the full `dig` output, including status, flags, authority, and additional sections.
2. Query A and AAAA separately.
3. Check response code and whether the result is NXDOMAIN or NODATA.
4. Test the same query over UDP and TCP.
5. Test with a conservative EDNS buffer size.
6. Check reverse DNS separately from forward DNS.
7. For mail, inspect MX, SPF, DKIM, DMARC, PTR, and CAA.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What is NODATA?" answer="A successful DNS response where the name exists but has no record set for the requested type." %}
  {% include study-card.html question="Why test DNS over TCP?" answer="Large or truncated responses, DNSSEC, and firewall differences can make TCP 53 fail while UDP appears fine, or the reverse." %}
  {% include study-card.html question="What can a bad CAA record break?" answer="Certificate issuance by a certificate authority that is not authorized by the zone's CAA policy." %}
</div>

## References

- [RFC 1035: Domain Names - Implementation and Specification](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 2308: Negative Caching of DNS Queries](https://www.rfc-editor.org/rfc/rfc2308)
- [RFC 6891: Extension Mechanisms for DNS](https://www.rfc-editor.org/rfc/rfc6891)
- [IANA DNS Parameters](https://www.iana.org/assignments/dns-parameters/dns-parameters.xhtml)
- [RFC 8659: DNS Certification Authority Authorization](https://www.rfc-editor.org/rfc/rfc8659)
