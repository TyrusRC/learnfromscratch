---
title: Multi-cloud red team scenario walkthrough
slug: multi-cloud-red-team-scenario-walkthrough
aliases: ["multi-cloud-rt-walkthrough","mcrta-scenario-walkthrough"]
date: 2026-06-08
---
{% raw %}

A composite engagement narrative. Names changed, primitives real. The target is a SaaS company running Google Workspace as primary identity, AWS as primary workload, Azure for analytics, and a small on-prem AD that nobody admits exists but everyone still depends on. Goal: Tier 0 in AD, starting from zero context.

## Hop 0: recon and pretext

Public LinkedIn plus a careless engineering blog gave us the GitHub org, the AWS account naming convention (`acme-prod-*`), the fact that they use `gcloud` for analytics, and three names in platform-eng. The blog mentioned "we federate CI to AWS via OIDC, no long-lived keys." Translation: the trust policy on those roles is the attack surface. See [[ci-cd-as-cloud-attack-surface]].

## Hop 1: OAuth device code phish into Workspace

Workspace had hardware keys enforced for admins but not for standard users. We sent a tailored lure to a junior SRE pointing at a fake "internal cost dashboard" that triggered an OAuth device code flow against a malicious app requesting `https://www.googleapis.com/auth/drive.readonly` and `gmail.readonly`. The user pasted the code, consent screen looked routine. See [[oauth-device-code-phishing-m365]] for the M365 variant; Google's flow is structurally identical.

Logged: Workspace admin console shows the app authorization under Security > API controls. Nobody reads it.
Evaded: no MFA challenge because device code flows do not require interactive reauth when the user already has a session.

## Hop 2: Drive to GitHub PAT

Drive search for `ghp_` and `github_pat_` hit a Google Doc titled "onboarding scratch" containing a classic PAT with `repo` and `workflow` scopes. We did not exfiltrate the doc; we copied the token and moved on. Token-stealing patterns generalize, see [[token-stealing-cloud]].

## Hop 3: GitHub Actions OIDC to AWS

With `workflow` scope we pushed a branch to a low-traffic internal repo and edited `.github/workflows/deploy.yml` to add a job that requests an OIDC token and calls `sts:AssumeRoleWithWebIdentity`. The trust policy on `arn:aws:iam::...:role/deploy-prod` had:

```json
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:acme/*:*"
  }
}
```

That wildcard is the bug. Any repo in the org, any branch, any environment can assume the role. We did not need to compromise the production repo; a forgotten sandbox repo worked. See [[gha-oidc-sub-claim-wildcards]].

```
$ aws sts get-caller-identity
Arn: arn:aws:sts::...:assumed-role/deploy-prod/GitHubActions
```

Logged: CloudTrail `AssumeRoleWithWebIdentity` event with the OIDC subject. Detectable if anyone alerts on sub-claim drift, which nobody did.
Evaded: GuardDuty had no finding because the call came from GitHub's IP space, which is on the allowlist.

## Hop 4: AWS to Azure via Entra cross-tenant sync

The `deploy-prod` role had `secretsmanager:GetSecretValue` on a secret named `azure-analytics-sp`. Inside: an Entra service principal credential for the analytics tenant. The analytics tenant had cross-tenant sync configured inbound from the corporate tenant for "shared collaborators." We abused the sync direction to enumerate the corporate tenant's user objects and found a sync-scoped account with elevated group membership in corp. See [[entra-cross-tenant-sync-abuse]] and [[entra-id-enum]].

The primitive: cross-tenant sync provisions B2B guests with attributes the source tenant controls, and the receiving tenant's conditional access often exempts "internal collaborators." We landed a guest identity in corp that bypassed the device compliance CA policy.

Logged: Entra audit log shows `Add user` and `Add member to group` from the sync service principal. Buried under thousands of legitimate sync events.

## Hop 5: Entra Connect on-prem write-back

Corp tenant ran Entra Connect with password hash sync and group write-back enabled. The compromised guest had rights into a cloud group that was written back to on-prem AD as a security group nested into a help-desk role. Help-desk had `Reset password` on a stale service account that was still a member of a legacy "Server Operators" equivalent. See [[entra-connect-exploitation-2025]].

```
PS> Set-ADAccountPassword -Identity svc-legacy-backup -Reset ...
PS> Add-ADGroupMember -Identity "Domain Admins" -Members svc-legacy-backup
```

Tier 0 in AD via a chain that started with a Google OAuth consent.

Logged: on-prem Security event 4724 (password reset) and 4728 (group add). The SOC had a rule but it was scoped to interactive logons; the service account changes came from the Entra Connect server context and were filtered out.

## What this teaches

Each hop is boring in isolation. The chain only exists because trust boundaries between identity providers are configured by different teams with different threat models. Cross-link this with [[multi-cloud-pivoting]] for the conceptual map, [[cloud-identity-mental-model]] for the mental model, and [[osep-ad-attack-chain-walkthrough]] for the on-prem half done in isolation.

Detection bets that paid off for defenders elsewhere: alerting on OIDC sub-claim wildcards, alerting on cross-tenant sync membership delta into privileged groups, alerting on Entra Connect server initiating writes to Tier 0 adjacent objects. Three rules, three hops killed.

Defender homework: enumerate every federation trust you own, write down the worst thing each one can do, and assume the wildcard is hostile.

{% endraw %}
