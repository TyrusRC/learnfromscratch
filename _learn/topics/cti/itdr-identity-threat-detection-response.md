---
title: ITDR — Identity Threat Detection and Response
slug: itdr-identity-threat-detection-response
aliases: [itdr, identity-tdr]
---

> **TL;DR:** Identity Threat Detection and Response (ITDR) is the tooling category Gartner coined around 2022 to cover the gap between IAM (which provisions and authenticates) and SIEM/EDR (which watch endpoints and logs) — specifically detecting and responding to attacks *against* the identity fabric itself: Active Directory, Entra ID, Okta, Ping, Workspace. The reason it exists as a category at all is that the past five years of major breaches — [[case-study-solarwinds-2020]], [[case-study-okta-2023-support-system]], [[case-study-snowflake-2024]], Midnight Blizzard at Microsoft — were not endpoint compromises in the traditional sense; they were identity compromises that pivoted through OAuth tokens, federation trust, service principals, and stale privileged accounts. Companion notes: [[entra-cross-tenant-sync-abuse]], [[conditional-access-bypass-modern]], [[bloodhound]], [[detection-engineering-pyramid-of-pain]].

## Why it matters

Identity is now the perimeter. The endpoint is increasingly a managed, EDR-covered thin client; the data lives in SaaS; the only thing between an attacker and the crown jewels is a token. Once that token is valid, no firewall, no EDR, and frequently no SIEM rule will fire — because the request looks like a legitimate authenticated session.

The post-2020 case file is overwhelming:

- **SolarWinds / Nobelium (2020):** Golden SAML against ADFS, forged tokens accepted by M365 — see [[case-study-solarwinds-2020]] and [[apt-tradecraft-russian-svr-fsb]].
- **Okta support-system (2023):** session tokens lifted from a support case file, used against downstream customers — [[case-study-okta-2023-support-system]].
- **Snowflake customer breaches (2024):** infostealer-harvested credentials against accounts without MFA — [[case-study-snowflake-2024]].
- **Midnight Blizzard vs Microsoft (2024):** password-spray against a legacy non-production tenant, then OAuth app consent to pivot into corporate mail.
- **Scattered Spider / 0ktapus:** SMS phishing of helpdesks to reset MFA on privileged accounts.

What these have in common: the attacker never tripped an EDR rule on a workstation. They moved through identity primitives — federation, tokens, app consent, service principals, cross-tenant trust.

SIEM sees the logs but doesn't reason about identity graph relationships. IAM enforces policy but doesn't hunt for abuse. ITDR is the layer that says: *given this directory and these access patterns, what looks anomalous, what is over-privileged, what is exploitable?*

## What ITDR actually covers

The category is fuzzy and vendor-defined, but the consistent capabilities are:

### Identity-graph analysis

Map every identity (user, service account, service principal, managed identity, workload identity), every group, every role, every resource permission, and compute the *reachability graph*. This is what BloodHound did for AD a decade ago — see [[bloodhound]] — and what BloodHound Enterprise (SpecterOps) and Microsoft's exposure management now do continuously for Entra, AD, and increasingly Okta.

### Lateral-movement detection across identity boundaries

Detect Kerberoasting, AS-REP roasting, DCSync, Golden/Silver/Diamond tickets, NTLM relay, certificate template abuse ([[adcs-attacks]]), token theft, refresh-token replay, and cross-tenant pivots ([[entra-cross-tenant-sync-abuse]]).

### Stale and orphaned identity hunting

Service accounts that nobody owns. Guest accounts from acquisitions five years ago. Application registrations whose owner has left. Federation trusts to long-defunct partners. These are the highest-yield targets because nobody is watching them.

### Privileged-account abuse

Anomalous use of break-glass accounts, off-hours admin sign-ins, role activation outside PIM windows, service principals suddenly granted Mail.ReadWrite or Directory.ReadWrite.All, OAuth app consent to new high-privilege scopes.

### Posture management (ITDR's ITDR-PM subset)

Continuously assess directory hygiene: weak/legacy auth still enabled, accounts exempt from Conditional Access, AD with unconstrained delegation, Tier-0 contamination, certificate templates with dangerous EKUs. Semperis and SpecterOps live here.

## Vendor landscape (2024-2026)

Be honest: this market is consolidating fast and the marketing exceeds the reality. Rough buckets as of mid-2026:

### EDR vendors extending into identity

- **Microsoft Defender for Identity (MDI)** — formerly Azure ATP. Strong on on-prem AD with sensor on DCs; weaker historically on Entra-only environments. Bundled in M365 E5, which is its biggest selling point.
- **CrowdStrike Falcon Identity Protection** — acquired from Preempt. Strong on AD, growing Entra/Okta coverage. Plays well with their EDR telemetry.
- **SentinelOne Singularity Identity** — acquired Attivo Networks. Strong on deception/honeytoken integration ([[deception-and-honeypot-strategy]]).

### AD-specialist vendors

- **Semperis** — Directory Services Protector, AD Forest Recovery. Came out of disaster-recovery roots; AD-first, now extending to Entra.
- **Quest** — Change Auditor / On Demand Audit. Long-standing AD auditing player.
- **Tenable Identity Exposure** (formerly Alsid) — posture-management focus.

### Modern identity-fabric and SaaS-first

- **Silverfort** — agentless MFA and ITDR overlay; injects itself into Kerberos/NTLM flows.
- **Push Security** — browser-extension-based, covers SaaS shadow IT and OAuth grants well.
- **Oort** (acquired by Cisco/Duo) — Entra/Okta posture.
- **AuthMind, Mesh Security, Permiso, Reco** — newer SaaS-identity entrants.

### Graph / posture

- **BloodHound Enterprise (SpecterOps)** — continuous attack-path analysis for AD and Entra. The most respected by red teams; defenders use it as offensive ground truth.
- **Microsoft Security Exposure Management** — Microsoft's bundled answer to BloodHound for Entra/AD.

## Defensive baseline

Before buying any ITDR product, do this:

1. **Inventory the identity surface.** AD forests, Entra tenants, Okta orgs, Ping, Workspace, federation trusts in/out, cross-tenant sync agreements. You cannot defend what you cannot list.
2. **Tier-0 hygiene.** Identify Tier-0 assets and accounts (DCs, KDS root keys, AAD Connect servers, ADFS, Entra Global Admins, Okta super admins). No Tier-0 admin should log into a non-Tier-0 workstation. Ever.
3. **Privileged Identity Management (PIM) or equivalent.** Just-in-time activation for every privileged role. No standing Global Admin except 2-5 break-glass accounts.
4. **Conditional Access baseline.** MFA everywhere, block legacy auth, device compliance for admin actions, named-location guardrails — and audit exceptions monthly ([[conditional-access-bypass-modern]]).
5. **Service-principal and OAuth app review.** Quarterly. Look at consented scopes, owner, last credential rotation, last sign-in.
6. **Log identity events to SIEM.** Entra sign-in logs, audit logs, MFA logs, OAuth consent events. Most orgs already pay for these; they often aren't ingested.
7. **Run BloodHound (community edition is free).** Get the attack-path picture before a vendor pitches one to you.
8. **Tabletop the identity-incident.** "Global Admin credentials are confirmed compromised. Walk us through the next 60 minutes." See [[tabletop-exercise-design-and-execution]].

## Workflow to study

### Week 1-2: understand the identity primitives

- AD: Kerberos, NTLM, SIDs, group nesting, GPOs, delegation, certificate services.
- Entra: tokens (id/access/refresh), app registrations vs service principals vs enterprise apps, consent grants, conditional access, cross-tenant access settings.
- Okta: orgs, factors, sign-on policies, API tokens, OIN apps, support-impersonation.
- Federation: SAML, OIDC, WS-Fed, ADFS, golden-SAML mechanics.

### Week 3-4: attack the identity layer in a lab

Stand up a small AD + Entra hybrid lab. Run:

- BloodHound collection ([[bloodhound]])
- Rubeus for Kerberoast/AS-REP
- Certify/Certipy for AD CS ([[adcs-attacks]])
- AADInternals for Entra/hybrid abuse
- ROADtools for Entra enumeration
- Evilginx2 for token theft ([[aitm-evilginx-modern-phishing]])

You cannot evaluate an ITDR product if you do not understand what it is detecting.

### Week 5-6: deploy and tune one ITDR tool

Whichever your org has. Spend time in the detection catalog, write down what is missed, and feed gaps back to the detection-engineering team via [[purple-team-feedback-loop]] and [[edr-rules-as-code-from-attack-patterns]].

### Ongoing

- Read every Microsoft Threat Intel blog on identity attacks.
- Read every SpecterOps blog on AD/Entra abuse.
- Read every Okta and Entra changelog — new features create new attack surface.
- Track the case studies as they unfold: [[case-study-okta-2023-support-system]], [[case-study-snowflake-2024]], [[case-study-solarwinds-2020]].

## Measuring an ITDR program

Useful metrics — don't be the team that only tracks "alerts fired":

- **Tier-0 cleanliness:** count of standing Global Admins, accounts exempt from CA, Tier-0 contamination events per quarter.
- **Privileged role time-to-revoke:** when an admin leaves, how long until every role is gone? Hours, not days.
- **Stale service account count:** non-rotated, no-owner, no-recent-sign-in service principals. Track downward over time.
- **OAuth consent grants per quarter:** new high-privilege scopes granted, by whom, reviewed how.
- **Attack-path count to Tier-0 (BloodHound Enterprise / MSEM):** track downward.
- **Mean time to detect identity anomaly:** measured against red-team or atomic tests ([[atomic-red-team-emulation-deep]]).

## Common deployment failures

- **Hybrid blind spots.** Defender for Identity covers on-prem AD via sensor; Entra ID Protection covers cloud. The hybrid join, AAD Connect server, and federation glue are frequently uncovered. Attackers know this.
- **Okta + Entra dual-IdP.** Many enterprises authenticate to Entra via Okta or vice versa. ITDR tools often see one side cleanly and the other as a black box.
- **Service-principal noise fatigue.** Without baselining, every Graph API call from an Azure DevOps pipeline looks suspicious. Without tuning, the team mutes the channel and misses the real one.
- **Vendor-lock telemetry.** Some ITDR products store the identity graph only in their cloud; if you switch tools you lose history. Negotiate export.
- **No response runbooks.** Detection without "what do we do when this fires at 2am" is theater. Write runbooks for: compromised Global Admin, compromised service principal, golden SAML suspected, OAuth consent grant abuse, helpdesk-social-engineered MFA reset. See [[soc-runbook-design]] and [[ir-from-source-signals]].

## Vendor marketing vs reality

- "AI-powered identity threat detection" usually means a handful of UEBA rules ([[ueba-detection-ml-primer]]) with a logistic regression on top. Ask for the detection list.
- "Covers Entra, Okta, AD, Ping, Workspace" usually means one of those is well-covered and the others are checkbox depth. Ask what specific TTPs are detected per platform.
- "Continuous attack path analysis" — verify whether it actually re-computes daily, or is a quarterly scan dressed up.
- "ITDR replaces your SIEM use cases" — no, it complements. You will still need [[siem-detection-use-case-catalog]].
- BloodHound Enterprise is the honest yardstick. If a vendor's attack-path output disagrees with BHE, trust BHE.

## Related

- [[entra-cross-tenant-sync-abuse]]
- [[conditional-access-bypass-modern]]
- [[case-study-okta-2023-support-system]]
- [[case-study-solarwinds-2020]]
- [[case-study-snowflake-2024]]
- [[bloodhound]]
- [[adcs-attacks]]
- [[detection-engineering-pyramid-of-pain]]
- [[ueba-detection-ml-primer]]
- [[siem-detection-use-case-catalog]]
- [[aitm-evilginx-modern-phishing]]
- [[oauth-device-code-phishing-m365]]
- [[mfa-fatigue-tradecraft]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[cloud-identity-mental-model]]
- [[cloud-iam-misconfig-patterns]]
- [[soc-runbook-design]]
- [[ir-from-source-signals]]
- [[purple-team-feedback-loop]]

## References

- Gartner, "Enhance Your Cyberattack Preparedness With Identity Threat Detection and Response," 2022 — the originating category note: https://www.gartner.com/en/documents/4015983
- SpecterOps BloodHound Enterprise documentation and blog: https://specterops.io/bloodhound-enterprise/
- Microsoft Defender for Identity documentation: https://learn.microsoft.com/en-us/defender-for-identity/
- CISA advisory on Midnight Blizzard / Microsoft Entra activity: https://www.cisa.gov/news-events/cybersecurity-advisories/aa24-057a
- Mandiant / Google Cloud, "APT29 Continues Targeting Microsoft" reporting: https://cloud.google.com/blog/topics/threat-intelligence/
- Push Security identity attacks matrix: https://pushsecurity.com/saas-attacks/

See also: [[defender-for-identity-evasion]], [[ad-coercion-and-relay-matrix-2025]], [[bloodhound-ce-deployment]], [[diamond-and-sapphire-tickets]], [[entra-prt-cookie-theft]]
