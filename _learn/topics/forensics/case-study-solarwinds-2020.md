---
title: Case study — SolarWinds SUNBURST (2020)
slug: case-study-solarwinds-2020
aliases: [solarwinds-2020, sunburst, unc2452, nobelium]
---

> **TL;DR:** Russian intelligence (APT29, tracked as UNC2452 / NOBELIUM) compromised SolarWinds' Orion build environment, injected a backdoor (SUNBURST) into the Orion DLL, and shipped it to ~18,000 customers via the standard SolarWinds update channel. The implant was passive: it called home to a DGA-generated domain, waited weeks before activating, and was selective about which environments to advance. Used the foothold for downstream cloud / Microsoft 365 / SAML token forging campaigns. The defining cascading supply-chain compromise. Companion to [[case-study-3cx-supply-chain]] and [[cve-2024-3094-xz-utils-backdoor]].

## Why this matters

- ~18,000 organisations received the backdoor; a smaller subset of high-value targets had the chain advanced (US Treasury, Commerce, DHS, FireEye, Microsoft, others).
- Detection came from **FireEye observing one of its own employees register a new MFA token** unexpectedly — a single anomalous Duo registration unravelled the entire campaign.
- The follow-on **SAML token forgery (Golden SAML)** moved laterally into Microsoft 365 tenants without classic AD compromise.
- Defined the cascading supply-chain model that xz (2024) and 3CX (2023) later echoed.

## The kill chain at a glance

1. **Build-environment compromise (mid-2019 onward)** — UNC2452 gained access to SolarWinds' Orion development infrastructure. Methods incompletely public; phishing + credential abuse + persistence in build tooling.
2. **Backdoor implantation** — SUNBURST DLL (`SolarWinds.Orion.Core.BusinessLayer.dll`) modified to include malicious .NET code; rebuilt and re-signed by SolarWinds' legitimate signing pipeline.
3. **Distribution** — shipped via SolarWinds' update channel between March 2020 and June 2020. ~18,000 customers installed.
4. **Dormancy** — SUNBURST waited 12–14 days before contacting C2 to avoid sandbox detection.
5. **Beacon to DGA domain** — `avsvmcloud.com` subdomains. The DNS response signaled whether the victim was "interesting" (based on AV products installed, domain name, etc.).
6. **Selective advance** — only ~100 of the 18,000 had follow-on activity. The 100 were chosen by attacker selection.
7. **Second-stage implants (TEARDROP, RAINDROP)** — Cobalt Strike Beacon variants, fileless loaders.
8. **Lateral movement** — kerberoasting, golden tickets, golden SAML.
9. **Cloud pivot** — forged SAML tokens authenticated to Microsoft 365 / Azure as legitimate users. Often, attackers had administrator-equivalent without ever touching domain controllers in tenant.

## SUNBURST technical highlights

- **Signed by SolarWinds** with valid code signing — bypassed application-whitelisting.
- **Anti-analysis** — checked for AV processes, sandbox indicators; bailed if detected.
- **DGA domain construction** — encoded the victim's domain into the DNS query subdomain, exfiltrating identity.
- **Late activation** — backdoor stayed dormant on most hosts forever; only "interesting" hosts got commands.
- **Code obfuscation** — heavy .NET method-name obfuscation; legitimate-looking class structure.

## Golden SAML

Once attackers had AD-level access, they extracted the AD FS token-signing certificate. With the private key:

- Forge SAML assertions for any user.
- Assertions sign valid against the AD FS public key.
- Microsoft 365 / Azure accept the assertion.

The attacker is then any user — including Global Admins — without ever logging into AD or being seen by AD auth logs. Microsoft 365 sign-in logs show "successful federated sign-in" with no obvious anomaly.

Mandiant's detection rule: SAML assertions issued without a corresponding AD FS auth event.

## Detection — how FireEye caught it

FireEye's employee enrolled a new Duo MFA device unexpectedly. The employee hadn't requested it; the helpdesk pulled the audit trail. Investigation:
1. Found the device enrollment came from an anomalous source.
2. Reviewed the employee's session — credentials being used from non-employee IPs.
3. Pulled lateral movement traces.
4. Identified Cobalt Strike Beacon traffic.
5. Traced beacon-loader to a specific DLL.
6. Traced DLL to Orion update.
7. SolarWinds confirmed compromised build.

One MFA event. The entire campaign hinged on that detection.

## What this teaches

- **Cascading supply chain** — vendor compromise propagates to thousands of downstream customers.
- **Code signing alone is not enough** — every defence relying on "is this binary signed" failed.
- **SBOM and build provenance** matter — see SLSA, in-toto, Sigstore.
- **Identity compromise in cloud SaaS** can occur without classic AD touching points (Golden SAML).
- **Patient adversaries** beat naive detection — 12-day dormancy defeats most sandboxes.
- **One anomaly is enough** — well-tuned identity-anomaly detection (Duo enrollment in this case) was the catch.

## Defensive baseline informed by SUNBURST

- **Continuous Access Evaluation** (CAE) — invalidate sessions on risk events.
- **Token signing certificate protection** — HSM-bound AD FS / Entra Connect signing keys; rotation.
- **SAML assertion auditing** — alert on assertions without corresponding IdP auth events.
- **Build environment isolation** — separate networks, signed-only-from-CI gating.
- **Vendor risk assessment** — supply-chain-specific incident response runbooks.
- **DNS monitoring** — DGA-style domain queries; high-cardinality subdomains.

## IR posture for similar campaigns

If you receive notification that a vendor was compromised:
1. **Inventory** — which versions of the vendor product are deployed where.
2. **Network isolation** of vendor product instances if not already.
3. **Hunt for known IoCs** — hash matches, network indicators.
4. **Behavioural hunt** — anomalous outbound from vendor product instances.
5. **Identity hunt** — anomalous SAML / token activity in any tenant the vendor product touches.
6. **Patch** — apply vendor's fix.
7. **Rotate** — credentials, certificates, SAML signing keys.
8. **Long-term hunt** — adversaries who got in via this vector may have established other persistence; assume environment-wide.

## Related supply-chain cases

- [[case-study-3cx-supply-chain]] — different attacker (DPRK), same cascading pattern.
- [[cve-2024-3094-xz-utils-backdoor]] — different vector (OSS maintainer takeover), similar industry impact.
- [[case-study-okta-2023-support-system]] — different angle on cascading identity-vendor risk.

## References
- [Mandiant — SUNBURST analysis](https://cloud.google.com/blog/topics/threat-intelligence/sunburst-additional-technical-details/)
- [Microsoft — Solorigate post-mortems](https://www.microsoft.com/en-us/security/blog/2020/12/18/analyzing-solorigate-the-compromised-dll-file-that-started-a-sophisticated-cyberattack-and-how-microsoft-defender-helps-protect-customers/)
- [SolarWinds — public IR statements](https://www.solarwinds.com/sa-overview/securityadvisory)
- [CISA — Emergency Directive 21-01](https://www.cisa.gov/news-events/directives/ed-21-01)
- [CrowdStrike — Golden SAML](https://www.crowdstrike.com/blog/golden-saml-newer-better-cousin-pass-ticket-attack/)
- See also: [[case-study-3cx-supply-chain]], [[cve-2024-3094-xz-utils-backdoor]], [[case-study-okta-2023-support-system]], [[adcs-attacks]], [[golden-tickets]]
