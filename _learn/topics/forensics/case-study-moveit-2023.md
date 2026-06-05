---
title: Case study — MOVEit Transfer / Clop ransomware (2023)
slug: case-study-moveit-2023
aliases: [moveit-2023, clop-moveit, cve-2023-34362]
---

> **TL;DR:** Progress Software's MOVEit Transfer (a managed file-transfer product widely used for B2B data exchange) had a SQL injection vulnerability (CVE-2023-34362) in a customer-facing endpoint. Clop ransomware crew mass-exploited it in May-June 2023, extracting data from ~2,700+ organisations spanning healthcare, finance, and government. No ransomware deployment — just data theft + extortion. Defining MFT-class incident of 2023; pattern reprised by Cleo 2024 ([[cve-2024-50623-cleo-rce]]). Companion to [[case-study-3cx-supply-chain]] and [[case-study-cleo-2024]].

## Why this matters

- **Largest single-CVE mass-extortion campaign** at the time, by number of affected organisations.
- Pattern: **MFT product, internet-exposed by design, with unauth SQL injection** → mass data theft.
- Clop's extortion ran for months as new victim names were posted to their leak site.
- Recovery for many victims was complicated by downstream-customer notification obligations.

## The vulnerability

CVE-2023-34362: SQL injection in MOVEit Transfer's web interface, specifically in the `/human.aspx` endpoint and related guest-access paths. Pre-authentication.

The injection allowed:
1. Database read of MOVEit's internal tables (users, file metadata, session tokens).
2. Read of stored credentials encrypted with the application's master key.
3. With master key in hand: decrypt sensitive metadata + reach the underlying file store.
4. Through a chain of carefully crafted queries: write a webshell (`human2.aspx`) to disk.
5. With webshell: read files, escalate.

The webshell was the signature artifact: many incident-response teams detected based on `human2.aspx` presence.

## The chain

1. **Late 2022 / early 2023** — Clop reportedly discovered the bug; built tooling.
2. **May 27, 2023** — Mass exploitation begins. Hundreds of internet-facing MOVEit instances hit within hours.
3. **May 31, 2023** — Progress Software publishes advisory and emergency patch (CVE assigned later).
4. **June 2023 onward** — Clop publishes victim names on their leak site, extorts them.
5. **July 2023 – ongoing** — Progress publishes additional CVEs and patches for follow-on bugs.
6. **Late 2023** — Victim list grows past 2,700 organisations.

## What attackers achieved

- File exfil from victim MOVEit instances.
- Customer-data of *downstream* customers — banks, payroll providers, pension funds, healthcare networks who used MOVEit for B2B data exchange exposed the data of their own customers.
- Notable named victims: BBC, British Airways, Boots (UK), Aon, PwC, Deloitte, IBM, Shell, US Department of Energy, multiple state governments, university systems.

## Why MFT products keep getting hit

MFT products share characteristics that make them high-impact:
- **Internet-exposed** by design.
- **Service-account scope** is wide — they handle data for many internal teams and external partners.
- **Complex parsing** (file formats, encrypted attachments).
- **Legacy code** — many MFT vendors evolved from earlier products, accumulating debt.
- **Customer concentration** — many large organisations use the same MFT vendor.

Pattern that recurs (Accellion 2021, GoAnywhere 2023, MOVEit 2023, Cleo 2024).

## What this teaches

- **Treat MFT products as crown jewels** — they shouldn't be internet-exposed without a perimeter (VPN, zero-trust proxy).
- **Vendor security maturity matters**; MFT vendor selection should include security-program assessment.
- **Downstream customer notification** — your MFT compromise is your customers' incident too.
- **Backup data-flow** — MFT failures should not block legitimate business; design for vendor-incident continuity.

## Detection lessons

Indicators that surfaced during investigation:
- New ASP.NET files in MOVEit web directory (`human2.aspx`).
- New users / sessions in MOVEit database.
- Outbound data volume from MOVEit instance.
- Process spawns from `w3wp.exe` (IIS worker) running `cmd.exe` or `powershell.exe`.
- Specific file-content patterns (encryption / RAR / sequential reads).

Behavioural detection picked up the chain; signature-only detection missed it until Clop's tooling was studied.

## IR posture for similar campaigns

If you receive notice that an MFT product you run is compromised:

1. **Take instance offline immediately**. Even patching isn't sufficient if attackers were already in.
2. **Hunt for webshells** in the application's web directory.
3. **Audit the MOVEit database** for new users / sessions / suspicious config.
4. **Identify data exfil window** — analyse logs for the suspected exposure period.
5. **Notify downstream customers** whose data was on the platform during the window.
6. **Rotate** all credentials, API keys, SSH keys, certs the MFT touched.
7. **Forensic preservation** — capture the instance for later analysis; the IR window extends months.
8. **Reimage and restore** from clean baseline; don't trust in-place remediation for MFT.

## Defensive baseline informed by MOVEit

- **MFT behind perimeter** — VPN, zero-trust proxy, or restrict to known partner IPs.
- **MFT service account least-privilege** — segregated per-customer / per-folder if possible.
- **Behavioural EDR** on MFT hosts.
- **Audit logs to long-term storage** — 90 days is too short for MFT incidents.
- **File-system integrity monitoring** on web-application directories.
- **Volume anomalies** — outbound to non-business addresses, large data flows out of hours.
- **Vendor incident watch** — KEV catalogue, vendor advisories, threat-intel feeds.

## Lessons from the Clop / MOVEit affiliate model

Clop's operation was professional:
- **Pre-positioned tooling** — burst exploitation in hours, not days.
- **Selective extortion** — chose which victims to publish based on extort value.
- **Public victim list** — drove negotiation pressure.
- **Adapted to scrutiny** — issued advisories addressing specific victims' positions.

This is the modern ransomware-extortion playbook even without ransomware deployment.

## Related

- [[case-study-3cx-supply-chain]] — supply-chain class.
- [[cve-2024-50623-cleo-rce]] — directly analogous 2024 MFT incident.
- [[case-study-equifax-2017]] — adjacent "preventable through patching" theme.
- [[third-party-saas-misconfig-patterns]] — supplier-class.
- [[sql-injection]] — underlying class.

## References
- [Progress MOVEit advisory](https://www.progress.com/security/cve-2023-34362)
- [Mandiant — UNC4857 MOVEit campaign](https://cloud.google.com/blog/topics/threat-intelligence)
- [Microsoft Threat Intelligence — Clop MOVEit](https://www.microsoft.com/en-us/security/blog/)
- [Rapid7 analysis](https://www.rapid7.com/blog/)
- [Huntress — MOVEit investigation](https://www.huntress.com/blog)
- See also: [[cve-2024-50623-cleo-rce]], [[case-study-3cx-supply-chain]], [[sql-injection]], [[third-party-saas-misconfig-patterns]]
