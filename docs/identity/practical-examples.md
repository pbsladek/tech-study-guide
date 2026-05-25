---
title: Identity Examples
layout: page
permalink: /docs/identity/practical-examples/
summary: "Practical OAuth, OIDC, JWKS, and JWT examples for identity troubleshooting and API validation."
tags:
  - examples
  - identity
  - oauth
  - oidc
  - jwt
---

# Identity Examples

These examples complement [Identity and Access](/docs/identity/) and [IdP, SAML, JWT, OAuth, and OIDC](/docs/identity/auth-protocols/).

## Identity OAuth and JWT Examples

OAuth authorization-code token exchange with PKCE:

```bash
curl -sS https://idp.example.com/oauth/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d grant_type=authorization_code \
  -d client_id=example-web \
  -d code="$AUTHORIZATION_CODE" \
  -d redirect_uri=https://app.example.com/callback \
  -d code_verifier="$PKCE_VERIFIER"
```

JWKS key discovery and safe local inspection:

```bash
curl -sS https://idp.example.com/.well-known/openid-configuration
curl -sS https://idp.example.com/.well-known/jwks.json | jq '.keys[] | {kid, kty, alg, use}'
```

JWT claim checks an API should enforce after signature verification:

```json
{
  "iss": "https://idp.example.com/",
  "aud": "https://api.example.com/",
  "scope": "orders:read orders:write",
  "exp": 1779570000,
  "nbf": 1779566400
}
```

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="Why does PKCE include a code_verifier in the token exchange?" answer="It proves the token requester owns the secret derived from the original authorization request." %}
  {% include study-card.html question="Why fetch JWKS during JWT troubleshooting?" answer="The API needs the issuer's current public signing keys to verify token signatures." %}
  {% include study-card.html question="Which JWT claims are commonly checked by APIs?" answer="Issuer, audience, expiration, not-before time, subject, and scopes or roles." %}
</div>

## References

- [OAuth 2.0 RFC 6749](https://www.rfc-editor.org/rfc/rfc6749)
- [PKCE RFC 7636](https://www.rfc-editor.org/rfc/rfc7636)
- [JSON Web Token RFC 7519](https://www.rfc-editor.org/rfc/rfc7519)
