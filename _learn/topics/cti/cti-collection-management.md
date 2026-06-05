---
title: CTI collection management
slug: cti-collection-management
aliases: [cti-collection, collection-management-framework, cmf]
---

> **TL;DR:** A CTI programme needs a **Collection Management Framework (CMF)** — a documented map of what intelligence requirements exist, what sources feed them, what gaps remain. Without a CMF, a SOC drowns in noise from too many feeds and still misses what matters. Practical CMF: define stakeholders, derive Priority Intelligence Requirements (PIRs), map sources, score sources for reliability and timeliness, retire / replace under-performing sources. Companion to [[detection-engineering-pyramid-of-pain]] and [[keeping-up-with-research-feeds]].

## Why this matters

- CTI investment without process produces noise.
- Most SOCs report feed-overload as a top operational pain.
- Stakeholders (SOC, IR, threat hunt, executive, regulatory) have different intelligence needs.
- Without explicit collection plan, feeds are kept because cost is sunk; gaps go unmonitored.

## The CMF in practice

A CMF documents:
1. **Stakeholders** and their intelligence needs.
2. **PIRs (Priority Intelligence Requirements)** — questions the stakeholders need answered.
3. **Sources** — where each PIR is sourced from.
4. **Coverage matrix** — which PIRs are well-sourced, which have gaps.
5. **Source quality metrics** — reliability, timeliness, false-positive rate.
6. **Lifecycle** — sources reviewed regularly, retired or replaced.

## Step 1 — Identify stakeholders

- **SOC** — needs IoCs and detection logic.
- **IR** — needs adversary-tradecraft details during incidents.
- **Threat hunt** — needs hypotheses + supporting evidence.
- **Vulnerability management** — needs prioritisation signal.
- **Brand / executive** — needs early warning of campaigns affecting org.
- **Compliance / regulatory** — needs reporting input.
- **Business / fraud** — needs financial-threat intel.

Each has different requirements.

## Step 2 — PIRs

Derive specific questions per stakeholder. Examples:

For SOC:
- What new IoCs exist for currently-active campaigns relevant to our sector?
- Which vulnerabilities are being exploited in the wild?

For IR:
- For an active incident attributed to actor X, what other indicators / tools should we hunt?

For threat hunt:
- What TTPs are actors targeting our sector currently using that we may not detect?

For exec:
- What strategic threats face our organisation in the next quarter?

A typical CMF starts with 10–20 PIRs; more is unmanageable.

## Step 3 — Sources

Categories:

### Open-source

- Vendor CTI blogs (Mandiant, Microsoft, CrowdStrike, ESET, Kaspersky, etc.).
- Researcher Twitter / Mastodon / Bluesky.
- Researcher blogs (subscribed via RSS — see [[keeping-up-with-research-feeds]]).
- Public IoC feeds (CISA KEV, AbuseIPDB, AlienVault OTX).
- Government advisories (CISA, NCSC, ASD).
- ISACs / ISAOs (FS-ISAC, H-ISAC, E-ISAC, MS-ISAC).

### Commercial

- Mandiant Advantage, CrowdStrike Falcon Intelligence.
- Recorded Future, Flashpoint, Intel 471.
- Sector-specific: ZeroFOX, Group-IB.

### Internal

- SIEM alerts.
- Honeypot data ([[deception-and-honeypot-strategy]]).
- DNS / proxy logs.
- IR findings.
- Red team / pen test results.

### Closed

- Trust groups (informal, vetted communities).
- Government briefings (cleared individuals).
- Vendor TI customer-only feeds.

## Step 4 — Map PIRs to sources

For each PIR, list which sources answer it. Highlight:
- PIRs with no source — gap.
- PIRs with one source — single-point-of-failure.
- PIRs with multiple sources — over-served.

## Step 5 — Score sources

For each source, rate:
- **Reliability** — how often it's correct (track FPs).
- **Timeliness** — how quickly relevant intel arrives.
- **Coverage** — which PIRs it serves.
- **Cost** — financial + operational.

Score quarterly. Retire low-scoring sources.

## Step 6 — Lifecycle

- New source on trial 3 months — measured against scoring.
- Quarterly source review.
- Annual full CMF refresh.

## Common CMF anti-patterns

- **All-source posture** — subscribe to everything, drown.
- **Source bias** — over-rely on one big vendor.
- **Stale PIRs** — never revisit; intel produced no longer matches needs.
- **No measurement** — no idea which sources actually deliver.
- **No stakeholder feedback loop** — intel produced doesn't address actual needs.

## Outputs of a CTI programme

Different forms for different stakeholders:

- **Tactical** (SOC, IR): IoCs, detections, fact-sheets.
- **Operational** (threat hunt): TTP analyses, threat-actor profiles.
- **Strategic** (exec, board): threat-landscape briefs, geopolitical assessment.

Use the **Three Cs**:
- **Customer-focused** — products serve specific stakeholders.
- **Coverage-aware** — products tied to PIRs.
- **Confidence-rated** — Admiralty Code or similar.

## Admiralty Code

Two-character grade per piece of intel:
- Source reliability A-F.
- Information credibility 1-6.
- "A1" = reliable + confirmed; "F6" = unreliable + improbable.

Stakeholders can quickly judge confidence.

## Workflow to study

1. Identify your stakeholders.
2. Derive 10 PIRs.
3. Inventory current sources.
4. Map PIRs to sources; identify gaps.
5. Score one quarter's outputs.
6. Adjust.

## Tooling

- **MISP** — open-source threat intelligence platform.
- **OpenCTI** — open-source CTI platform.
- **Anomali ThreatStream**, **ThreatConnect**, **Recorded Future** — commercial.
- **Sigma** for detection-as-code.
- **MITRE ATT&CK Navigator** for coverage visualisation.

## Related

- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[atomic-red-team-emulation-deep]]
- [[keeping-up-with-research-feeds]]
- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-dprk-lazarus]]
- [[apt-tradecraft-iranian-irgc]]
- [[ransomware-affiliate-playbook]]

## References
- [SANS — Cyber Threat Intelligence](https://www.sans.org/cyber-security-courses/cyber-threat-intelligence/)
- [Sergio Caltagirone — CMF research](https://www.activeresponse.org/)
- [MISP project](https://www.misp-project.org/)
- [OpenCTI](https://www.opencti.io/)
- [MITRE ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)
- See also: [[detection-engineering-pyramid-of-pain]], [[siem-detection-use-case-catalog]], [[keeping-up-with-research-feeds]], [[apt-tradecraft-russian-svr-fsb]]
