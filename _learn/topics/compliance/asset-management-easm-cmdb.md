---
title: Asset management — EASM and CMDB
slug: asset-management-easm-cmdb
aliases: [easm, asset-management, cmdb-security]
---

> **TL;DR:** You cannot protect, patch, or monitor what you don't know exists. Asset management is the unglamorous foundation under every other security control: vuln management, IR, AppSec, compliance. In practice you run two views — an **EASM** (external attack surface, what attackers see) and a **CMDB** (internal authoritative inventory of owned assets) — and constantly reconcile them against ground truth from cloud APIs, EDR, and DNS. Almost every major breach in recent memory has an asset-management failure in the root cause chain — see [[case-study-equifax-2017]] (unknown unpatched Struts host), [[case-study-capital-one-2019]] (misconfigured WAF on a forgotten role), [[case-study-snowflake-2024]] (untracked SaaS tenants). Companion: [[vulnerability-management-lifecycle]] and [[third-party-risk-management-practitioner]].

## Why it matters

Every framework — PCI DSS 4.0 Requirement 12.5, ISO 27001 A.5.9, NIST CSF ID.AM, CIS Controls 1 & 2 — opens with asset inventory. Auditors ask for it first. Pentesters break in through it. SOC analysts can't triage without it.

The realistic state at most organisations:

- A CMDB last reconciled by a human in 2019.
- An EASM scan that finds 40% more internet-exposed hosts than the CMDB lists.
- A cloud account nobody remembers creating, with admin keys in a wiki page.
- An acquired subsidiary running an old Exchange server nobody told the security team about.
- A "shadow IT" SaaS estate paid for on personal cards and expensed.

Equifax 2017 is the canonical lesson: Apache Struts CVE-2017-5638 had a patch available. The patch team didn't apply it on a specific host because the asset wasn't in the inventory the patch team used. Months later, attackers found the host and exfiltrated 147M records. See [[case-study-equifax-2017]].

Capital One 2019: a misconfigured WAF on an EC2 instance with an over-permissioned IAM role. The role wasn't catalogued. Nobody knew that instance could read the S3 bucket holding 100M credit applications. See [[case-study-capital-one-2019]].

Snowflake 2024: customers had SaaS tenants without SSO/MFA, often unknown to central security teams. Infostealer-harvested credentials walked right in. See [[case-study-snowflake-2024]].

## The two views: EASM and CMDB

### EASM — external attack surface management

What the internet (and an attacker) sees about your organisation. Discovery-driven, no agent, no authentication.

**Inputs**: seed domains, ASNs, known cloud accounts, brand strings, certificate transparency logs, passive DNS.

**Discovery techniques**:
- DNS enumeration, subdomain brute-force, CT log mining (`crt.sh`, Censys CT).
- WHOIS, RDAP, ASN pivot.
- Reverse-DNS sweeps of cloud IP ranges.
- TLS certificate fingerprints (`favicon hash`, JARM, JA4S).
- Web tech fingerprinting (Wappalyzer-style), banner grabbing.
- Cloud-account-aware probes (S3 bucket name guessing, Azure blob enum).
- GitHub/Gist/Pastebin scraping for leaked secrets and host references.

**Commercial EASM tools** (vendor-marketing-vs-reality caveat applies):
- **Censys ASM** — strong on certificate transparency and protocol scanning; honest about discovery quality. https://censys.com/asm
- **Microsoft Defender EASM** (formerly RiskIQ) — large passive-DNS corpus, good for typosquat / spoof-domain discovery. https://www.microsoft.com/en-us/security/business/siem-and-xdr/microsoft-defender-external-attack-surface-management
- **Mandiant Attack Surface Management** — pivots from breach-intel signals, expensive. https://www.mandiant.com/advantage/attack-surface-management
- **Bishop Fox CAST** — consultant-augmented, continuous testing on top of discovery.
- **Tenable ASM** (ex-Bit Discovery) — integrates with Tenable.io vuln scans.
- **Palo Alto Cortex Xpanse** — heavy ASN-and-protocol scanner, good at finding misconfigurations on the edge.
- **runZero** (formerly Rumble) — hybrid: external scanner + on-prem network scanner.

**EASM honest reality**: every vendor over-claims discovery completeness. Run two vendors plus your own scripts. Expect 5–15% false-positive attribution (someone else's S3 bucket assigned to you because of a similar name).

### CMDB — internal authoritative inventory

What you own, who owns it, what it does. Should be the ground truth, rarely is.

**Tooling spectrum**:
- **ServiceNow CMDB** — incumbent at most large enterprises; powerful, often unloved. CSDM data model defines services, business apps, technical services, CIs. https://www.servicenow.com/products/configuration-management-database.html
- **Device42** — agentless discovery + CMDB, good for messy on-prem + cloud. https://www.device42.com/
- **Axonius** — aggregator: pulls from 800+ sources (EDR, MDM, cloud, scanners) and reconciles into a unified asset view. The market-leading "CAASM" (cyber asset attack surface management). https://www.axonius.com/
- **JupiterOne** — graph-based asset and relationship model; strong for cloud-heavy orgs and compliance evidence. https://jupiterone.com/
- **Lansweeper, Snipe-IT** — SMB / mid-market alternatives.

CAASM (Axonius, JupiterOne, Sevco, Panaseer) is the modern answer: don't try to make every system push into one CMDB, instead aggregate the truth that already exists in EDR, MDM, cloud, IdP, scanner, and produce a reconciled view.

## Asset attributes worth tracking

A CI (configuration item) record that's useful for security must answer:

- **Identity**: stable ID, hostname(s), IPs, MAC, cloud resource ID, serial number.
- **Owner**: a human name AND a team/cost-centre. "IT" is not an owner.
- **Business criticality**: tied to a business service (e.g., "payment processing", "marketing site").
- **Data classification**: PII, PHI, PCI cardholder data, IP, public.
- **Exposure**: internet-exposed? in DMZ? internal only? air-gapped?
- **Environment**: prod / staging / dev / sandbox.
- **OS and version, software inventory** (SBOM-grade ideal, package list realistic).
- **Patch status / last-seen / last-scanned**.
- **EDR / log-forwarder coverage** (is it producing telemetry?).
- **Encryption status** (disk, transit).
- **Lifecycle**: in-service date, end-of-support date, decommission date.
- **Compliance scope**: in PCI scope? HIPAA? SOX?
- **Relationships**: depends on / supports / runs on / talks to.

Owner field is the single most important — and the one most often blank. Without an owner, no patch, no incident response, no risk acceptance signature.

## Reconciliation: the actual hard problem

Three views must converge:

1. **EASM** — what the internet sees.
2. **CMDB / CAASM** — what we believe we own.
3. **Ground truth** — cloud control plane (AWS Config, Azure Resource Graph, GCP Cloud Asset Inventory), EDR coverage report, IdP (Okta, Entra) device list, DNS zones, certificate issuance logs.

Delta-hunting workflow:

- **EASM minus CMDB** → "unknown unknowns" — internet-exposed assets we don't track. Highest risk; often shadow IT, acquired subsidiaries, dev environments, marketing campaign sites.
- **CMDB minus ground truth** → "stale CMDB" — recorded but no longer exists, or exists but no EDR / no log forwarder.
- **Ground truth minus CMDB** → real assets the inventory missed; reflects broken provisioning workflow.
- **EASM minus ground truth** → typically attribution false positives; investigate, then exclude or claim.

Cadence: nightly automated diff, weekly review by an asset-management owner, monthly governance review with IT/Security/Business leadership.

## Common organisational failure modes

- **Stale CMDB**: nobody decommissions. Records persist for hosts that died years ago. Patch metrics look bad because they include ghosts.
- **No owner field / "IT" as owner**: tickets bounce, patches stall, IR can't reach a human at 2 AM.
- **Shadow IT**: SaaS bought on personal cards, dev clouds outside the central tenant, marketing AWS accounts. Often discovered only via expense audits or DNS data. CASB / SaaS discovery (Netskope, Adaptive Shield, AppOmni) helps.
- **M&A inheritance**: acquired company assets never migrated into the CMDB. Their old IPs, old creds, old patches. Equifax-style risk. Treat day-1 post-close as discovery day.
- **Cloud account sprawl**: AWS Organizations / Azure Management Groups / GCP folders not enforced. Use cloud-native inventory APIs (AWS Config aggregator, Azure Resource Graph) as ground truth, not a hand-maintained spreadsheet.
- **Asset-without-EDR**: the CMDB says it's a Windows server; EDR coverage report doesn't see it. Either it's dead, or it's running a bypass. Either is an incident-worthy signal.
- **Container and ephemeral asset blindness**: short-lived containers, lambdas, serverless. Don't try to push every container into ServiceNow; aggregate at workload / image / cluster level.

## Interaction with vuln management and IR

**Vulnerability management**: scanner findings without asset context produce noise. A "critical CVE on 10000 hosts" report is useless until you can answer: which are internet-exposed? which process cardholder data? which have a patch SLA in flight? Tie scanner output to CMDB attributes (owner, criticality, exposure) to drive risk-based prioritisation. See [[vulnerability-management-lifecycle]] (companion note).

**Incident response**: the first IR question is always "what is this host, who owns it, what does it do, what does it connect to?". If the CMDB can't answer in 60 seconds, your MTTR is already blown. See [[soc-runbook-design]] and [[ir-from-source-signals]].

**AppSec**: software inventory feeds SBOM and SCA — [[secure-sdlc-rollout-playbook]] and [[appsec-maturity-checklist]].

**Compliance scoping**: PCI scope is defined by which CIs touch CHD — [[building-a-pci-dss-program-practitioner]]. ISO 27001 A.5.9 explicitly requires the inventory — [[building-an-iso27001-isms-practitioner]]. HIPAA covered entities track ePHI-handling assets — [[hipaa-security-rule]]. NIS2 expects asset inventory under risk-management measures — [[nis2-implementation]].

**Third-party risk**: same problem at one remove — your vendors' assets. See [[third-party-risk-management-practitioner]].

## Workflow to study

1. Pick a target seed domain (your own, or with permission). Run `subfinder`, `amass`, `crt.sh` queries, `httpx` probing. Note the unique hosts.
2. Cross-check against a vendor EASM trial (Censys, runZero free tier, Defender EASM trial).
3. Pull cloud inventory: `aws configservice list-aggregate-discovered-resources`, `az graph query`, `gcloud asset list`.
4. Pull EDR coverage report (CrowdStrike / Defender / SentinelOne).
5. Pull IdP device list (Okta devices, Entra registered devices).
6. Build the diff tables described in "Reconciliation".
7. Pick the top 10 EASM-minus-CMDB items. Investigate. Document who owns each, why it's exposed, whether to keep, harden, or kill.
8. Read the asset-management chapter of NIST SP 800-53 Rev 5 (CM-8) and CIS Control 1.

Realistic effort: a first pass on a 5000-employee org is a 6–12 month programme. Quarterly maturity gains thereafter. The exec sponsor must be at CIO/CISO level — asset management cuts across IT, Security, Procurement, Finance, and Legal.

## Who succeeds

- Orgs that put a named **Asset Management Lead** with cross-functional authority.
- Orgs that treat CMDB as a product (versioning, SLAs, KPIs) not a clerical chore.
- Orgs that adopt CAASM aggregation rather than fighting to make ServiceNow the only source.
- Orgs that tie asset hygiene to procurement gates: no asset record, no payment.

## Vendor marketing vs reality

- "100% discovery" — nobody achieves this. Settle for measured coverage with known blind spots.
- "Single source of truth" — false. Reality is *reconciled view of multiple sources*.
- "AI-powered" — usually fuzzy matching and entity resolution. Useful, not magic.
- "Replaces your CMDB" — CAASM tools augment, they don't replace the workflow ServiceNow runs for change management.

## References

- NIST SP 800-53 Rev 5, CM-8 Information System Component Inventory: https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final
- CIS Critical Security Controls v8, Controls 1 & 2: https://www.cisecurity.org/controls/v8
- Gartner Market Guide for CAASM (paywalled summary): https://www.gartner.com/en/documents/4022626
- Censys ASM product overview: https://censys.com/asm
- Microsoft Defender EASM documentation: https://learn.microsoft.com/en-us/azure/external-attack-surface-management/
- Axonius CAASM overview: https://www.axonius.com/platform/cyber-asset-attack-surface-management
- ServiceNow CSDM (Common Service Data Model) whitepaper: https://www.servicenow.com/community/cmdb-articles/csdm-and-the-cmdb/ta-p/2329085

## Related

- [[vulnerability-management-lifecycle]]
- [[case-study-equifax-2017]]
- [[case-study-capital-one-2019]]
- [[case-study-snowflake-2024]]
- [[third-party-risk-management-practitioner]]
- [[building-an-iso27001-isms-practitioner]]
- [[building-a-pci-dss-program-practitioner]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[secure-sdlc-rollout-playbook]]
- [[appsec-maturity-checklist]]
- [[soc-runbook-design]]
- [[ir-from-source-signals]]
- [[cloud-iam-misconfig-patterns]]
