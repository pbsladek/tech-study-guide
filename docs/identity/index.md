---
title: Identity and Access
layout: page
permalink: /docs/identity/
summary: "Identity-provider, federation, SSO, SAML, OAuth, OpenID Connect, JWT, token validation, and access-control study guide."
tags:
  - identity
  - security
  - authentication
  - authorization
---

# Identity and Access

Identity systems answer two different questions that often get mixed together: who is the caller, and what is that caller allowed to do? The operational work is making those answers trustworthy across browsers, APIs, services, certificates, tokens, sessions, and policy engines.

For OAuth token exchange, JWKS discovery, and JWT claim-check examples, see [Identity Examples](/docs/identity/practical-examples/).

## Critical Subtopics

| Topic | Why It Matters |
| --- | --- |
| [IdP, SAML, JWT, OAuth, and OIDC](auth-protocols/) | Covers identity providers, service providers, relying parties, assertions, tokens, OAuth roles, OIDC identity, JWT validation, and common SSO failure modes. |

## Core Vocabulary

| Term | Meaning |
| --- | --- |
| Authentication | Proving who a user, workload, or client is. |
| Authorization | Deciding what an authenticated or anonymous caller may do. |
| Identity Provider (IdP) | System that authenticates users and issues identity information to applications or service providers. |
| Service Provider (SP) | SAML application that trusts assertions from an IdP. |
| Relying Party (RP) | OIDC application that relies on an OpenID Provider. |
| Authorization Server | OAuth component that issues access tokens after authorization. |
| Resource Server | API that accepts access tokens and enforces access decisions. |
| Token | Bearer or proof-bound credential presented to a service. |

## Mental Model

A useful model is: identity is issued by one component, carried by a protocol artifact, then enforced somewhere else.

Examples:

- SAML: an IdP authenticates the user and sends a signed assertion to a Service Provider.
- OAuth: an authorization server issues an access token that a client presents to an API.
- OIDC: an OpenID Provider issues an ID token that a client uses to learn the user's identity.
- JWT: a compact token format that may carry claims inside OAuth or OIDC flows.

Do not assume the protocol artifact alone is the policy. A valid token or assertion proves the issuer made a statement. The receiving system still has to validate issuer, audience, time bounds, signature, replay protections, and local authorization policy.

## Common Failure Shapes

- SSO loop because redirect URI, ACS URL, cookie domain, or SameSite policy is wrong.
- Login succeeds but API calls fail because ID tokens and access tokens are confused.
- JWT decodes cleanly but is accepted without signature, issuer, audience, or expiry validation.
- SAML assertion is signed, but the wrong certificate, entity ID, clock, or NameID format is configured.
- OAuth client uses a flow that does not fit its client type or threat model.
- Token lifetime, refresh-token rotation, or revocation behavior is not aligned with incident response needs.

## Study Path

Start with [IdP, SAML, JWT, OAuth, and OIDC](auth-protocols/) to separate authentication from authorization and to learn which protocol artifact belongs at each boundary.

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does an identity provider do?" answer="It authenticates users or principals and issues identity information that other applications can trust after validation." %}
  {% include study-card.html question="What is the difference between authentication and authorization?" answer="Authentication proves identity; authorization decides what that identity may do." %}
  {% include study-card.html question="Why is a valid token not the whole access decision?" answer="The receiver still needs local policy plus checks for issuer, audience, expiry, signature, and trust boundary." %}
</div>

## References

- [OAuth 2.0 Authorization Framework, RFC 6749](https://www.rfc-editor.org/rfc/rfc6749)
- [JSON Web Token, RFC 7519](https://www.rfc-editor.org/rfc/rfc7519)
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0-18.html)
- [OASIS SAML 2.0 Technical Overview](https://docs.oasis-open.org/security/saml/Post2.0/sstc-saml-tech-overview-2.0.html)
