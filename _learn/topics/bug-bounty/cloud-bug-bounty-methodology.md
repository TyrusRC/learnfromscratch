---
title: Cloud bug bounty methodology
slug: cloud-bug-bounty-methodology
aliases: [cloud-bb-method, aws-gcp-azure-bb]
---

> **TL;DR:** Cloud bug bounty splits into two very different worlds: (a) provider-side VRPs (AWS VRP, GCP VRP, Microsoft Online Services / Azure Bounty) that pay for breaks in the cloud platform itself, and (b) customer-tenant programs where the target happens to run on cloud and pays for things like SSRF-to-IMDS, IAM trust abuse, or public storage. Mixing those up is the fastest way to get a report closed N/A or, worse, a takedown notice. Pair this with [[aws-imds-ssrf-pivot]], [[s3-bucket-key-policy-confused-deputy]], [[entra-cross-tenant-sync-abuse]], and [[gcp-workload-identity-federation-abuse]] for the concrete impact paths you will demonstrate inside that scope.

## Why it matters

Cloud surfaces look like web surfaces from outside, but the impact model is completely different:

- A single SSRF on an EC2-hosted app can become full account compromise via IMDSv1, or nothing at all if IMDSv2 is enforced — same bug class, two orders of magnitude in payout.
- A public S3 bucket is sometimes a $0 informational, sometimes a critical, depending on whether it was *intended* public (CDN) or holds tenant data.
- Provider VRPs (AWS, GCP, Azure) reward platform-level breaks (cross-tenant, IAM logic bugs, metadata service flaws) and explicitly **exclude** customer misconfig.
- Customer programs reward impact *against that customer*, not against the cloud provider.

If you cannot articulate which of those two games you are playing before you send the first packet, you will burn the program. See [[program-scope-reading]] and [[scope-vertical-vs-horizontal]] for the general discipline; this note layers cloud-specific rules on top.

## Provider VRPs vs customer-tenant programs

### AWS VRP

- Scope: vulnerabilities in AWS services themselves (control plane, IAM logic, isolation, IMDS), not in customer accounts.
- Out of scope: misconfigured customer buckets, leaked customer keys, customer-side IAM mistakes, social engineering of AWS staff.
- Good targets: cross-account confused-deputy in a service principal, IAM policy evaluation edge cases, STS/AssumeRole logic, container/Lambda isolation, IMDS quirks. See [[s3-bucket-key-policy-confused-deputy]].
- Triage signal: AWS wants a clean, minimal repro in their own test account; do not pivot into other customers.

### GCP VRP

- Scope: Google-owned products and infrastructure, including GCP service control planes, IAM, OAuth, Workload Identity Federation.
- Pays well for IAM/OAuth logic and cross-tenant data exposure. See [[gcp-workload-identity-federation-abuse]] and the pattern study [[case-study-google-vrp-writeup-patterns]].
- Out of scope: customer misconfig, public buckets owned by third parties, brute force.

### Microsoft Online Services Bounty + Azure Bounty

- Scope: M365, Entra ID (Azure AD), Azure platform services, Dynamics, Power Platform.
- High-value classes: Entra tenant isolation, cross-tenant sync abuse ([[entra-cross-tenant-sync-abuse]]), OAuth/consent bugs, admin role escalation ([[m365-admin-attacks]]).
- Strict rules around touching other tenants — use your own test tenants only.

### Customer programs on HackerOne/Bugcrowd/Intigriti

- You are testing *the customer's* attack surface that happens to run on cloud.
- In scope (usually): SSRF on the app that reaches IMDS, IDOR that leaks per-tenant cloud resources, leaked IAM keys, exposed storage with the customer's data.
- Out of scope (usually): attacking the cloud provider itself, lateral movement into other customers, IAM enumeration that touches non-target accounts.

If unsure, read [[program-scope-reading]] again and ask the program before you escalate.

## Classes and patterns

### Identity and IAM

- Long-lived access keys in client-side bundles, CI logs, public repos, mobile apps.
- Over-privileged roles where the app only needed `s3:GetObject` on one prefix but got `s3:*`.
- Trust policies that accept `*` as principal, or accept an external OIDC issuer without `aud`/`sub` claims pinned — the WIF and IAM-Roles-Anywhere story in [[aws-iam-roles-anywhere-abuse]] and [[gcp-workload-identity-federation-abuse]].
- Confused-deputy patterns where service A assumes role B without `ExternalId` — see [[cloud-iam-misconfig-patterns]].

### Metadata service (IMDS) reachability

- Any SSRF on an EC2/GCE/Azure-VM-hosted app is a candidate. See [[ssrf-to-cloud]] and [[ssrf-to-cloud-advanced-chains]] for chaining tricks, and [[aws-imds-ssrf-pivot]] for the AWS-specific pivot.
- Check IMDSv2 enforcement: if the app cannot do PUT for the token, IMDSv1-only SSRF still wins. If hop-limit is 1 you may still reach it from the host but not from a container.

### Storage exposure

- S3, GCS, Azure Blob: enumerate names from CNAMEs, JS bundles, mobile APKs, Wayback. The bucket policy is the real bug; the public listing is just the symptom.
- Look for cross-account bucket policies that grant `*` or a stale account ID. [[s3-bucket-key-policy-confused-deputy]].
- Azure Blob: SAS tokens leaked in URLs, often long-lived; check `se=` (expiry) and `sp=` (permissions).

### Secrets and key services

- KMS key policies open to `Principal: *` with weak conditions.
- Secret Manager / Parameter Store entries reachable via an over-privileged Lambda role.
- Demonstrate read of *your own* test secret you planted, not real production secrets.

### OIDC trust and federation

- GitHub Actions OIDC into AWS/GCP/Azure with `sub` claim regex that is too loose (`repo:org/*` instead of `repo:org/repo:ref:refs/heads/main`). See [[ci-cd-as-cloud-attack-surface]].
- Azure cross-tenant sync and B2B trust — [[entra-cross-tenant-sync-abuse]].

## Process

### Step 1 — read scope, twice

- Provider or customer? In-scope services? Out-of-scope actions (no IAM enum, no recursive S3 list, no pivot)?
- What does the program count as "impact"? Some programs explicitly say "public bucket = N/A unless it contains user data."
- Use [[testing-methodology-checklists]] to capture this in writing before you start.

### Step 2 — discovery without touching the platform

- Subdomains, CNAMEs pointing to `*.amazonaws.com`, `*.cloudfront.net`, `storage.googleapis.com`, `*.blob.core.windows.net`, `*.azurewebsites.net`.
- JS bundles for inline keys (`AKIA`, `ASIA`, `AIza`, `xox`, `eyJ...`).
- Mobile APKs/IPAs for the same, plus hardcoded bucket names. See [[mobile-client-storage-source-audit]].
- GitHub org search for the target's org and forks for leaked keys.

### Step 3 — application-level probing

- SSRF: every URL-fetching feature (webhooks, image proxy, PDF render, SSO metadata fetch, OAuth callback). [[ssrf]].
- IDOR/BOLA on per-tenant cloud resources (presigned URLs, bucket prefixes). [[bola]], [[idor]].
- OAuth/SSO with cloud IdPs — [[oauth-modern-attacks]].

### Step 4 — confirm cloud impact carefully

- Hit IMDS, capture role name + a short hash of the access key, **do not** list buckets or read other resources.
- For exposed keys: `aws sts get-caller-identity` only. Stop. Report. Let triage decide on further enumeration.
- For storage: list one object name pattern, read one *non-sensitive* object, stop. If you happen to read PII, stop immediately and document the stop.

### Step 5 — prove impact minimally

- See [[demonstrating-impact]]. The cloud rule of thumb: prove access, not extent.
- Screenshot `sts:GetCallerIdentity`, `gcloud auth print-access-token` decoded, or `az account show`. That is enough.
- Never dump customer data to your machine. Never run `aws s3 sync`. Never enumerate other tenants.

### Step 6 — report

- Lead with the chain: `app SSRF -> IMDSv1 -> role X -> permissions Y -> impact Z`.
- Include the exact IAM actions you confirmed (from `iam:SimulatePrincipalPolicy` against *your own* identity, not theirs) or from the policy if leaked.
- Map to provider's severity model — AWS, GCP, and Microsoft each publish theirs. See [[report-writing]] and [[report-writing-step-by-step]].

## Defensive baseline (what triagers expect you to know)

- IMDSv2 enforced, hop-limit 1, no IMDS in containers without need.
- Short-lived credentials only; no long-lived access keys in apps.
- Bucket public-access-block at account level; bucket policies reviewed.
- KMS key policies pinned to specific principals + conditions.
- OIDC federation with strict `sub` claim matching.
- CloudTrail / Cloud Audit Logs / Entra sign-in logs centralized.
- See [[cloud-red-team]] and [[cloud-identity-mental-model]] for the broader picture.

## Proof-of-impact discipline

This is what separates a paid report from a closed-N/A or, worse, a legal letter:

- Do **not** enumerate buckets, roles, or other tenants beyond the minimum needed to prove the bug.
- Do **not** read more than one or two non-sensitive objects.
- Do **not** create persistence (new IAM users, new keys, cron jobs).
- Do **not** pivot from one customer tenant to another.
- Do stop and report the moment you have a credential or a single object proving access.
- Document every action with timestamps for triage — see [[disclosure-and-comms]] and [[responsible-disclosure-across-jurisdictions]].

## Legal and AUP

- Cloud provider AUPs apply on top of the bounty program rules. AWS, GCP, and Azure all forbid certain testing patterns even on your own resources (high-volume DoS, port scanning others).
- Stay inside the program's documented scope and the provider's acceptable-use policy at the same time.
- If you discover a provider-level bug while testing a customer, report it to the provider VRP separately, not to the customer.

## How triage scores cloud findings

- Public bucket with no sensitive data: low / informational.
- Public bucket with PII or secrets: high / critical.
- SSRF reaching IMDSv2 token endpoint but no creds extracted: medium (provider may rate higher if it bypasses hop-limit).
- SSRF + IMDSv1 + over-privileged role with prod data access: critical.
- Leaked long-lived AWS key with admin: critical, often capped by program max.
- Cross-tenant data access in a SaaS on cloud: critical, often top payout.

## Workflow to study

1. Pick one provider VRP (start with GCP — clearest rules) and read every public writeup in the last two years. See [[case-study-google-vrp-writeup-patterns]] and [[reading-public-pocs-effectively]].
2. Build a personal test tenant in AWS, GCP, and an Entra tenant. Reproduce one published finding end-to-end.
3. Pick three customer programs that explicitly list cloud assets in scope and document their cloud impact rules.
4. Run [[continuous-recon-automation]] for cloud-flavored signals (new CNAMEs to cloud, new subdomains on cloud edges).
5. For each find, write a one-page chain: entry -> identity -> permission -> impact. Train the reflex from [[hacker-mindset-questioning]].
6. Track dupes per program with [[dupe-mental-model]]; cloud misconfig dupes hard, identity logic bugs dupe less.

## Related

- [[aws-imds-ssrf-pivot]]
- [[s3-bucket-key-policy-confused-deputy]]
- [[entra-cross-tenant-sync-abuse]]
- [[gcp-workload-identity-federation-abuse]]
- [[aws-iam-roles-anywhere-abuse]]
- [[cloud-iam-misconfig-patterns]]
- [[cloud-identity-mental-model]]
- [[cloud-red-team]]
- [[ci-cd-as-cloud-attack-surface]]
- [[ssrf-to-cloud]]
- [[ssrf-to-cloud-advanced-chains]]
- [[m365-admin-attacks]]
- [[program-scope-reading]]
- [[demonstrating-impact]]
- [[responsible-disclosure-across-jurisdictions]]
- [[case-study-google-vrp-writeup-patterns]]

## References

- https://aws.amazon.com/security/vulnerability-reporting/
- https://bughunters.google.com/about/rules/google-friends/6625378258649088/google-and-alphabet-vulnerability-reward-program-rules
- https://www.microsoft.com/en-us/msrc/bounty-online-services
- https://www.microsoft.com/en-us/msrc/bounty-microsoft-azure
- https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_request.html
- https://cloud.google.com/iam/docs/workload-identity-federation
