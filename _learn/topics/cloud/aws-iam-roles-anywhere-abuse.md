---
title: AWS IAM Roles Anywhere abuse
slug: aws-iam-roles-anywhere-abuse
aliases: [iam-roles-anywhere-abuse, ira-abuse]
---

> **TL;DR:** AWS IAM Roles Anywhere lets workloads outside AWS assume IAM roles using X.509 certificates issued by a trust anchor (a private CA). If an operator misconfigures the trust anchor — e.g., wildcard subject patterns, public CA, or a CA controlled by a third party — anyone able to issue a certificate matching the pattern can mint AWS credentials. Identity-layer compromise of an AWS account without ever touching the console. Companion to [[aws-assumerole-chains]] and [[cloud-iam-misconfig-patterns]].

## Why this matters

- IAM Roles Anywhere extends AWS identity to **anything that can hold a cert**.
- The trust anchor is just a CA certificate. Cert-based trust is **easy to misconfigure** in ways that look secure.
- The attack class is **lateral from cert infrastructure to AWS** — a path defenders rarely model.

## How it works

The pieces:
- **Trust anchor** — an X.509 CA certificate AWS will trust.
- **Profile** — defines which IAM roles certificates can assume and any session policy.
- **Role** — must trust the IAM Roles Anywhere service in its trust policy.

The client uses its certificate + private key to call AWS' Roles Anywhere endpoint and receive STS credentials.

The trust decision rests on:
1. The certificate validates back to the trust anchor.
2. The certificate's subject / SAN matches the profile's "subject pattern".
3. The profile allows the role.

If any of those checks is weak, the trust collapses.

## Pre-conditions that lead to abuse

- Trust anchor is a **public CA** (e.g., Let's Encrypt). Anyone can get a cert.
- Trust anchor is an **internal CA shared with non-production** environments or with a third-party vendor.
- Profile subject pattern is `*` or a broad wildcard.
- Trust anchor private key compromise — historic incidents in vendor environments.
- Trust anchor CA is **not pinned** to a specific issuer (intermediate substitution allowed).

## The exploit shape

1. Attacker enumerates trust anchors via `aws rolesanywhere list-trust-anchors` (if the attacker has any presence in the account).
2. Identifies a trust anchor pointing to an externally-accessible CA.
3. Obtains a cert from that CA matching the profile's subject pattern.
4. Calls `aws_signing_helper credential-process` with the cert and private key.
5. Receives STS credentials for the role.

## Mass-misconfig patterns observed externally

Cloud-recon writeups have flagged:
- AWS accounts with trust anchors pointing to public CAs and broad subject patterns.
- AWS accounts using a shared internal PKI that includes contractor environments.
- Trust anchors with deprecated profiles still attached.

Open-source scanners (Pacu, Prowler) now check for some of these.

## Recon approach

Inside the target account (read-only credentials):
- `aws rolesanywhere list-trust-anchors`
- `aws rolesanywhere list-profiles`
- `aws iam list-roles | jq '.Roles[] | select(.AssumeRolePolicyDocument | tostring | contains("rolesanywhere"))'`
- For each role, examine the trust policy condition — wildcards in CN are the smoking gun.

External recon:
- Often, trust anchor public certs are referenced in Terraform state files leaked to public S3 buckets or GitHub repos.
- Some organisations document their trust anchor CN scheme — useful for matching.

## Defensive baseline

- Trust anchors must use **internal-only** CAs not shared with third-party vendors.
- Subject patterns must be **as narrow as possible** — full CN match preferred.
- Profile session policies must be **minimum-privilege** — Roles Anywhere is not a free pass to admin.
- Trust anchor private key rotation procedure must exist.
- Audit Roles Anywhere usage via CloudTrail (`rolesanywhere.amazonaws.com` events).
- Use `notBefore`-style age constraints on certs the trust anchor will accept.

## Workflow to study in a lab

1. Stand up a small AWS account with a Roles Anywhere setup.
2. Create a trust anchor pointing to a local CA.
3. Issue a cert and obtain STS creds via `aws_signing_helper`.
4. Modify the subject-pattern to wildcard; observe broader cert acceptance.
5. Audit CloudTrail events for what's logged.

## Detection

- CloudTrail event `CreateSession` from `rolesanywhere.amazonaws.com` — every Roles Anywhere credential issuance.
- The session's source IP and source CN are logged; alert on unfamiliar CNs.
- New trust anchors / profiles created in CloudTrail.

## Related attacks

- **AWS Cognito federated identity** misconfig — similar shape with different identity material.
- **OIDC federation for GitHub Actions** — see [[gha-oidc-sub-claim-wildcards]].
- **GCP Workload Identity Federation** — analogous mechanism with the same misconfig class (see [[gcp-workload-identity-federation-abuse]]).

The pattern: cloud accepting external identity material and trusting it broadly when the cloud admin underestimated the external surface.

## References
- [AWS IAM Roles Anywhere docs](https://docs.aws.amazon.com/rolesanywhere/latest/userguide/introduction.html)
- [Aidan Steele — Roles Anywhere writeups](https://awsteele.com/)
- [SpecterOps / Datadog cloud research](https://posts.specterops.io/)
- [Pacu](https://github.com/RhinoSecurityLabs/pacu) / [Prowler](https://github.com/prowler-cloud/prowler) — auditing tools
- See also: [[aws-assumerole-chains]], [[cloud-iam-misconfig-patterns]], [[gha-oidc-sub-claim-wildcards]], [[gcp-workload-identity-federation-abuse]]
