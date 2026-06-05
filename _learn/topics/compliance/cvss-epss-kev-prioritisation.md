---
title: CVSS, EPSS, KEV — vulnerability prioritisation
slug: cvss-epss-kev-prioritisation
aliases: [vuln-prioritisation, epss-kev, cvss-vs-epss]
---

> **TL;DR:** CVSS tells you how bad a vulnerability *could* be in theory. EPSS tells you how likely it is to be exploited in the next 30 days. CISA KEV tells you it has *already* been exploited in the wild. Mature programmes combine all three — CVSS sets a severity ceiling, EPSS drives prioritisation under that ceiling, KEV triggers immediate-fire SLAs. Companion to [[vulnerability-management-lifecycle]], [[cvss-scoring-practitioner]], [[keeping-up-with-research-feeds]], and [[one-day-from-patch-diff]].

## Why it matters

Most enterprise vulnerability programmes are drowning. A typical mid-size org running Tenable, Qualys, or Rapid7 sees tens of thousands of "critical" or "high" findings per scan cycle. Patching is slow, change windows are scarce, and business owners push back on every reboot. If you treat every CVSS 9.0+ as equally urgent you will burn out your patch team on theoretical risks while a CVSS 7.2 on the CISA KEV list — currently being mass-exploited — sits in a backlog.

The shift over the last five years is that severity (CVSS) is no longer the primary prioritisation signal. Likelihood-of-exploit (EPSS) and known-exploited (KEV) signals have matured enough that ignoring them is professional negligence. Regulators have caught on too — CISA Binding Operational Directive 22-01 makes KEV remediation mandatory for US federal civilian agencies, and auditors increasingly ask private-sector orgs the same questions.

## The three signals

### CVSS — severity ceiling

CVSS (Common Vulnerability Scoring System, currently v3.1 with v4.0 rolling out) produces a 0.0–10.0 base score derived from attack vector, complexity, privileges required, user interaction, scope, and CIA impact. It is a *severity* score — it answers "if this is exploited, how bad is the technical outcome?"

What CVSS does not tell you:
- Whether public exploit code exists.
- Whether it is being exploited right now.
- Whether your environment is actually exposed (compensating controls, network position, configuration).
- Business context (asset criticality, data sensitivity).

CVSS Temporal and Environmental metrics exist to address some of this, but almost nobody calculates them at scale. Treat the base score as a severity ceiling, not a priority. See [[cvss-scoring-practitioner]] for scoring nuances.

### EPSS — probability of exploitation

EPSS (Exploit Prediction Scoring System), maintained by FIRST.org, outputs a daily-updated probability (0.0–1.0) that a given CVE will be exploited in the wild in the *next 30 days*. The model ingests features from MITRE ATT&CK, exploit databases (ExploitDB, Metasploit, Nuclei templates), social media chatter, vendor advisories, and observed exploitation telemetry from contributing sensor networks.

Key properties:
- It is *predictive*, not deterministic. EPSS 0.97 means "we expect this will be exploited", not "it has been".
- Distribution is heavily skewed. Roughly 5 percent of CVEs have EPSS above 0.10. Most sit below 0.01.
- Updated daily. A new PoC drop on GitHub can spike EPSS overnight.
- Available free at api.first.org/data/v1/epss.

### CISA KEV — confirmed in the wild

The CISA Known Exploited Vulnerabilities catalog is a curated list of CVEs with evidence of active exploitation. Each entry includes a remediation due date (typically two weeks for federal agencies under BOD 22-01) and a ransomware-use flag.

KEV is conservative — CISA only adds a CVE when they have reliable evidence of in-the-wild exploitation. The signal-to-noise ratio is near-perfect. If something is on KEV, treat it as fire.

### Other signals worth knowing

- **Tenable VPR (Vulnerability Priority Rating)** — proprietary score combining CVSS, threat intel, exploit code maturity, and asset context. Useful inside Tenable, opaque outside.
- **Qualys TruRisk** — similar concept, blends CVSS, threat indicators, and asset criticality.
- **Rapid7 Real Risk Score** — same pattern, different weighting.
- **Microsoft Exploitability Index** — for Microsoft CVEs, ratings 0–3 of likelihood of working exploit in 30 days.
- **Vendor PSIRT advisories** — Cisco, Fortinet, Palo Alto, VMware, Oracle. Often the only place "exploited in customer environments" is hinted at before KEV catches up.
- **Sector ISACs** — FS-ISAC, H-ISAC, E-ISAC. Sector-specific exploitation reports often lead KEV by days or weeks. See [[financial-sector-defender-playbook]] and [[healthcare-sector-defender-playbook]].
- **CTI feeds** — Mandiant, CrowdStrike, Recorded Future, GreyNoise. See [[cti-collection-management]] and [[keeping-up-with-research-feeds]].

Vendor scores are not a substitute for EPSS and KEV — they are useful supplements but the weightings are proprietary and you cannot reproduce them. Use them inside the vendor tool, but report up the stack using open signals.

## Combining the three

The mental model most mature programmes converge on:

| Signal | Role | Action |
|---|---|---|
| CVSS | Severity ceiling | Determines maximum SLA bucket eligibility |
| EPSS | Likelihood driver | Promotes/demotes within ceiling |
| KEV | Immediate-fire override | Triggers emergency SLA regardless of CVSS |

### A worked example

Two findings hit your scanner the same day:

- **CVE-A**: CVSS 9.8 (theoretical RCE in a niche XML parser), EPSS 0.002, not on KEV.
- **CVE-B**: CVSS 7.2 (privilege escalation in a widely deployed VPN appliance), EPSS 0.91, on KEV with ransomware flag.

A CVSS-only programme patches A first. A combined programme patches B first — and probably gets paged about it at 2 a.m. The ransomware flag alone says "active affiliate use, expect lateral movement within 24h of initial access". See [[ransomware-affiliate-playbook]].

### Translation to SLA buckets

A defensible internal SLA model:

| Bucket | Criteria | Target |
|---|---|---|
| Emergency | KEV listed, or EPSS >= 0.50 with CVSS >= 7.0 | 72 hours or next change window |
| High | CVSS >= 7.0 and EPSS >= 0.10 | 14 days |
| Medium | CVSS >= 7.0 and EPSS < 0.10 | 30–60 days |
| Low | CVSS < 7.0 and EPSS < 0.01 | Quarterly cycle / risk-accept |

Adjust thresholds for your environment. Internet-facing assets should have tighter brackets than internal segmented systems. Crown-jewel systems get their own track regardless of score.

## Why CVSS alone over-prioritises

The base CVSS distribution is bimodal — vendors tend to score either conservatively or maximally. NVD analysts add their own scores, sometimes disagreeing with the vendor. The result: the "critical" bucket is huge, and a programme that treats all criticals equally cannot keep up.

Concrete failure modes from CVSS-only programmes:
- Patch teams exhausted chasing theoretical RCEs in software the org does not even run.
- Real exploited CVEs sit in 30-day SLA buckets because their base score happens to be 7.x.
- Business owners learn to distrust "critical" labels because most never matter, then ignore the ones that do.
- Auditors find a KEV CVE unpatched at 45 days and the org cannot defend the prioritisation logic.

## Regulatory recognition

- **CISA BOD 22-01** (US, 2021) — mandates KEV remediation for federal civilian executive branch agencies. Two-week SLA by default. Private-sector orgs increasingly adopt similar language voluntarily or under contract.
- **NIS2** (EU) — Article 21 requires risk-based vulnerability handling; KEV/EPSS are now standard evidence in maturity assessments. See [[nis2-implementation]].
- **PCI DSS 4.0** — Requirement 6.3 explicitly requires risk-ranking and prioritising vulnerabilities, with "industry best practice" as the benchmark. KEV and EPSS are widely accepted as that benchmark. See [[pci-dss-4-implementation]] and [[building-a-pci-dss-program-practitioner]].
- **SOC 2 / ISO 27001** — auditors increasingly probe whether your vulnerability prioritisation uses exploit-likelihood signals, not just CVSS. See [[soc2-vs-iso27001]] and [[building-an-iso27001-isms-practitioner]].
- **DORA** (EU financial sector) — ICT risk management requirements lean on exploitability evidence for third-party and own-system patching.

## Defensive baseline

If you run a vulnerability programme, this is the minimum:

1. Enrich every scanner finding with current EPSS score (daily refresh) and KEV membership.
2. Override severity-only SLA with KEV emergency bucket whenever a finding hits the catalog.
3. Track *time-to-remediate* by signal, not just by CVSS. Report KEV-tagged mean time to remediate separately to leadership.
4. Re-score the backlog weekly — EPSS moves, KEV grows.
5. Feed prioritised findings into [[vulnerability-management-lifecycle]] workflow with clear owner, deadline, and compensating-control escape valve.
6. Document the prioritisation logic in a written standard so auditors and engineers see the same rules. See [[policy-and-standards-writing]].

## Workflow to study

- Pull the current CSV from CISA KEV. Sort by date added. Read the last 30 entries and note which vendors, products, attack vectors dominate.
- Pull EPSS for those same CVEs. Look at the EPSS score on the *day before* CISA added them to KEV — often EPSS rose first.
- Pick three CVEs and read the public patch-diff write-ups (see [[one-day-from-patch-diff]]) to understand how exploitation evidence reached CISA.
- Cross-reference with your scanner data — how many of those are present in your environment? How fast did you close them?
- Replay a recent KEV addition: pretend it just hit, walk the on-call rotation through the emergency SLA bucket, and time the response. This is a useful [[tabletop-exercise-design-and-execution]] scenario.
- Read FIRST's EPSS model documentation to understand which features drive the score — it makes the daily updates interpretable rather than magic.

## Common organisational failure modes

- "We only patch criticals" — ignores KEV mediums and highs, leaves obvious holes.
- Static SLA based on initial CVSS — fails to re-score when EPSS rises or KEV adds the CVE later.
- Vendor-rating lock-in — relying solely on Tenable VPR or Qualys TruRisk and unable to defend the methodology to auditors or to leadership unfamiliar with the vendor.
- Ignoring asset context — a KEV CVE on an isolated lab box and on a domain controller are not the same priority. Asset criticality and network exposure must layer on top.
- Treating EPSS as deterministic — it is a 30-day probability, not a guarantee. Some KEV-listed CVEs had EPSS under 0.05 the day before they were exploited.
- No feedback loop with detection — exploited CVEs in your sector should feed both prioritisation and [[detection-engineering-pyramid-of-pain]] coverage.
- Reporting CVSS averages to the board — the board does not care about averages. They care about KEV exposure and time-to-remediate trend.

## Realistic effort and who succeeds

Bolting EPSS and KEV onto an existing programme is not a quarter-long project — most teams can wire it up in two to four weeks. The hard part is cultural: convincing patch owners, change managers, and asset owners that a "high" with EPSS 0.85 outranks a "critical" with EPSS 0.001. That takes months of reporting changes, executive air cover, and a few well-narrated incidents where the new model would have saved you.

Programmes that succeed have a named owner with authority to declare emergency-SLA findings, a clear escape valve for compensating controls (so business owners are not boxed in), and a regular metric story that survives auditor scrutiny. Programmes that fail usually have either no executive backing or no automation — manually enriching findings every week does not scale and burns out the analyst doing it.

## Related

- [[vulnerability-management-lifecycle]]
- [[cvss-scoring-practitioner]]
- [[keeping-up-with-research-feeds]]
- [[one-day-from-patch-diff]]
- [[pci-dss-4-implementation]]
- [[nis2-implementation]]
- [[soc2-vs-iso27001]]
- [[building-a-pci-dss-program-practitioner]]
- [[ransomware-affiliate-playbook]]
- [[cti-collection-management]]
- [[detection-engineering-pyramid-of-pain]]
- [[financial-sector-defender-playbook]]
- [[healthcare-sector-defender-playbook]]
- [[tabletop-exercise-design-and-execution]]
- [[policy-and-standards-writing]]

## References

- CISA Known Exploited Vulnerabilities Catalog — https://www.cisa.gov/known-exploited-vulnerabilities-catalog
- CISA Binding Operational Directive 22-01 — https://www.cisa.gov/news-events/directives/bod-22-01-reducing-significant-risk-known-exploited-vulnerabilities
- FIRST EPSS — https://www.first.org/epss/
- FIRST CVSS v3.1 specification — https://www.first.org/cvss/v3.1/specification-document
- FIRST CVSS v4.0 specification — https://www.first.org/cvss/v4.0/specification-document
- Cyentia / Kenna "Prioritization to Prediction" research series — https://www.cyentia.com/library/
