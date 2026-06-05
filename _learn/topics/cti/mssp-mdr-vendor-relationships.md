---
title: MSSP / MDR vendor relationships
slug: mssp-mdr-vendor-relationships
aliases: [mssp-mdr, mdr-vendor]
---

> **TL;DR:** MSSPs sell broad managed security operations (firewall management, log review, vulnerability scanning), MDR vendors sell narrower detection-and-response on EDR/SIEM telemetry, and XDR/"SOC as a service" sits somewhere in the middle. Buying one of these is not the same as having a SOC — you still need internal people who can run [[soc-runbook-design]], drive [[ir-from-source-signals]], and govern the vendor like any other critical supplier per [[third-party-risk-management-practitioner]]. The contract, the responsibility split, and the SLA are where most of the value (or pain) actually lives. Companion to [[soc-tier-1-tier-2-tier-3-progression]] and [[detection-engineering-pyramid-of-pain]].

## Why it matters

Most organizations cannot staff a real 24x7 SOC. The math is brutal: covering nights, weekends, holidays, and burnout backfill takes 6 to 8 analysts minimum, plus a manager, plus detection engineering, plus an IR lead. That payroll alone is well north of a million USD a year in most Western markets before tooling. So leaders look at MSSP / MDR pricing — often a fraction of that — and sign.

The catch is that the brochure is not the contract. The brochure promises "24x7 monitoring, expert analysts, rapid response." The contract usually says: vendor will triage alerts from agreed sources, notify a named contact within X minutes for a Sev-1, and may take a defined set of containment actions on endpoint only. Everything else is yours. If you walked in expecting "they'll handle security," you will be disappointed and exposed.

A clean MSSP / MDR relationship is one of the highest-leverage moves a small security team can make. A bad one wastes budget, hides risk, and gives a false sense of safety. The difference is almost entirely about how you scope, contract, and govern — not which logo you pick.

## Classes of vendor

### MSSP — Managed Security Service Provider

Broader scope, older model. Typically manages: perimeter firewalls, IDS/IPS, SIEM log collection and review, vulnerability scanning, sometimes patch orchestration. Strength: one throat to choke for multiple operational tasks. Weakness: detection quality is often shallow, alerts are noisy or rubber-stamped, and "response" usually means "we email you a ticket."

Examples in this category: Verizon, AT&T Cybersecurity (formerly AlienVault), NTT, Atos, Trustwave, Secureworks (now Sophos), Kudelski, Orange Cyberdefense.

### MDR — Managed Detection and Response

Newer, narrower, opinionated. Usually built on the vendor's own EDR or a curated stack. Strength: focused on real attacker behavior, faster maturing detections, often actually-will-isolate-a-host response capability. Weakness: scope often limited to endpoint plus a couple of cloud sources; network and identity coverage varies wildly.

Examples: Mandiant Managed Defense, CrowdStrike Falcon Complete, SentinelOne Vigilance, Arctic Wolf, Expel, Red Canary, Rapid7 MDR, Sophos MDR, Huntress (SMB-focused), Binary Defense.

### XDR and "SOC as a service"

Vendor-marketed extension of MDR to multi-telemetry (endpoint + identity + cloud + email + network). In practice, XDR usually means "MDR running on our XDR product." If you do not already use their stack, XDR offerings get expensive fast.

### Pure SIEM-as-a-service / co-managed SIEM

Some vendors will operate your Splunk / Sentinel / Chronicle and write detections in it. Useful if you already invested in a SIEM and want operators, not a replacement.

## Build vs buy decision

### When buying makes sense

- Headcount below ~4 dedicated security FTEs.
- No realistic 24x7 internal coverage.
- Need to demonstrate monitoring quickly for compliance (PCI 10/12, SOC 2 CC7, ISO A.8.16 — see [[building-a-pci-dss-program-practitioner]], [[soc2-vs-iso27001]]).
- Limited detection engineering maturity (see [[detection-engineering-pyramid-of-pain]]).

### When building makes sense

- Regulated or high-risk environment where data egress to a vendor is itself a problem (defense, certain finance, certain healthcare).
- Existing strong detection eng + IR capability that an MDR would actually slow down.
- Highly bespoke telemetry (OT, custom protocols, see [[manufacturing-ot-defender-playbook]]) that no vendor covers well.

### The honest middle

Most mid-market companies should buy MDR for 24x7 endpoint + identity coverage, and keep a small internal team focused on detection engineering, IR leadership, vendor management, and the things the MDR will not touch (cloud config, appsec, insider, fraud). This hybrid is more common than either pure model.

## Responsibility split

The single most important question, asked early and in writing: **what does "response" mean in this contract?**

There are roughly four tiers, in increasing vendor responsibility:

1. **Notify-only.** Vendor opens a ticket, sends an email, maybe calls a hotline. You do everything else. Common, cheap, frustrating at 3am.
2. **Notify + recommend.** Vendor includes triage notes and recommended actions. Still you do the work.
3. **Notify + contained response on endpoint.** Vendor can isolate hosts, kill processes, quarantine files via their EDR, with pre-agreed scope. Most modern MDR.
4. **Full active response.** Vendor can disable accounts, block at firewall, push EDR policies, coordinate with your IR retainer. Rare, expensive, requires deep integration and trust.

Map every alert class to a tier. "Sev-1 ransomware behavior on endpoint" might be tier 3 with auto-isolate. "Sev-2 suspicious AWS IAM activity" might be tier 1 because the vendor has no AWS write access. Document the matrix. Test it in a tabletop ([[tabletop-exercise-design-and-execution]]).

## SLA structure that actually matters

Vendors love to quote MTTR. It is usually meaningless on its own. The SLAs you should pin down:

- **Time to detect (TTD).** From log/event timestamp to alert raised in the vendor console. Hard to enforce because depends on ingestion, but ask anyway.
- **Time to acknowledge (TTA).** From alert raised to a human analyst opening it. This is the realistic measure of vendor staffing. Push for under 15 minutes for high severity.
- **Time to notify (TTN).** From acknowledge to customer contact made. The number the contract should be most explicit about. Under 30 minutes for Sev-1 is reasonable; under 10 is aggressive.
- **Time to contain (TTC).** From notify to containment action (if vendor has authority). Only meaningful if you bought tier 3 or 4.
- **False positive rate / closure quality.** Often missing from contracts; insist on monthly reporting.

Severity definitions must be in the contract, not in the vendor's internal runbook. "Sev-1" should be a defined list of detections (ransomware behavior, domain admin compromise, exfil patterns), not the vendor's opinion that day.

## Measuring vendor performance

You need to grade them or you will be graded by an attacker.

### Monthly operational metrics

- Alerts ingested, triaged, escalated, false-positived.
- TTA / TTN per severity, percentile (p50, p95), not just average.
- New detections deployed; old detections tuned or retired.
- Coverage map against MITRE ATT&CK techniques relevant to your industry (cross-reference [[apt-tradecraft-chinese-mss]], [[apt-tradecraft-russian-svr-fsb]], [[ransomware-affiliate-playbook]] for what to expect).

### Quarterly tests

- Purple team or atomic test against the vendor (see [[atomic-red-team-emulation-deep]], [[purple-team-feedback-loop]]). Did they detect? In what time?
- Tabletop with vendor IR lead present.

### Annual

- Independent review of detection coverage and gaps.
- Renegotiation leverage point. Always know the next 2 vendors' pricing before this date.

If the vendor refuses to be measured, that is the answer.

## Contractual cleanup

Things that look boring at signing and matter desperately at exit or incident:

- **Data ownership.** All raw logs, parsed events, detection content, tickets, and analyst notes are yours, exportable in a documented format. Get this in writing.
- **Detection IP.** Detections written specifically for you (custom analytics, suppressions, parsers) should be yours. Vendor-proprietary detections obviously not, but you should at least get a list of what coverage you had.
- **Exit clause.** Defined notice period (90 days is normal), data return format and timeline, transition assistance hours included.
- **Sub-processors.** Where does your telemetry actually live? Often an offshore SOC. Important for [[gdpr-incident-implications]], [[pdpa-singapore]], [[appi-japan]], and similar regimes.
- **Breach notification to you.** Vendor must notify you of incidents affecting their environment that touch your data, within a defined window. Tie to your own regulatory clocks (NIS2 24/72-hour — see [[nis2-implementation]]).
- **Liability cap.** Almost always capped at 12 months fees. Negotiate carve-outs for gross negligence and confidentiality breach.
- **Tooling lock-in.** If the MDR is built on their proprietary agent, exiting means re-deploying EDR everywhere. Price that into the build-vs-buy.

## Red flags

- Demos that only show finished cases, never the queue.
- Refusal to share their analyst playbooks or escalation tree at any level of detail.
- "We use AI" with no explanation of where humans intervene.
- No named TAM or escalation contact, only a generic portal.
- All telemetry must flow into their cloud with no option for keeping a copy.
- Pricing model based on endpoint count with no consideration of cloud or identity coverage — you will end up paying more for things you also bought elsewhere.
- Cannot articulate how they would have detected a recent public incident (e.g., walk them through [[case-study-snowflake-2024]] or [[case-study-3cx-supply-chain]] and listen).
- High analyst turnover; ask about average tenure of L2/L3 analysts.

## How MSSP/MDR fits with internal SOC tiering

Refer to [[soc-tier-1-tier-2-tier-3-progression]] for the internal model. Common patterns:

- **MDR as outsourced Tier 1+2, internal Tier 3 and IR lead.** Most common. Vendor handles initial triage and routine containment; your senior staff own complex investigations, threat hunting ([[cti-collection-management]]), and post-incident.
- **MDR as Tier 1 only, internal Tier 2+3.** When you have decent staffing but need night coverage. Vendor escalates fast.
- **MSSP as ops layer (firewall, vuln mgmt), separate MDR for detection.** Sometimes necessary, doubles vendor management overhead.
- **Co-managed SIEM, internal detection engineering.** You write detections, they operate them 24x7. Highest control, requires mature internal team.

Whichever pattern, document the handoff in [[soc-shift-handoff-runbook]] and feed lessons back through [[purple-team-feedback-loop]].

## Defensive baseline

- Named internal owner for the MSSP/MDR relationship (not the CISO directly — usually SecOps lead or SOC manager).
- Onboarding plan with a defined "go-live" criteria, not just "we turned it on."
- Severity matrix, escalation tree, and containment authority in writing before go-live.
- Monthly service review with metrics, quarterly business review with leadership.
- Annual tabletop including the vendor.
- Internal capability to read raw logs independently — never let the vendor be the only one who can see your telemetry.
- Treat them as a critical third party: SIG/CAIQ, SOC 2 report on file, reviewed annually ([[third-party-risk-management-practitioner]]).

## Workflow to study

1. Inventory current telemetry: endpoints, identity, cloud, network, email, SaaS. Note what is missing — that is what the MDR will not magically fix.
2. Define the response tiers you want per telemetry source.
3. Write a draft severity matrix and notification tree before talking to vendors.
4. Run an RFP with 3 to 5 vendors. Insist on a proof of value (POV), not just slideware. Feed the POV real test cases ([[atomic-red-team-emulation-deep]]).
5. Score vendors on detection quality, response capability, contract terms, exit, and analyst quality — not just price.
6. Negotiate SLAs, data ownership, exit clause hard.
7. Onboard in waves: a pilot business unit, then expand. Define go-live criteria.
8. Stand up monthly metrics from week one. Do not let the first quarter pass without measurement.
9. Run a purple team test within 90 days of go-live and again annually.
10. Diary the renewal date 6 months out; start benchmarking alternatives.

## Vendor marketing vs reality

- "24x7 expert analysts" usually means tiered offshore L1/L2 with a smaller onshore L3 pool. Not bad, but ask the ratio.
- "AI-powered detection" usually means correlation rules and some clustering. The hard part is still the rule library and the humans.
- "MTTR under 10 minutes" usually means time to acknowledge, not time to resolve.
- "Full incident response included" usually means a handful of IR hours, then a retainer kicks in.
- "Compliance ready" does not mean compliant. You still own your audit.

## Who succeeds with this

Organizations that treat MSSP/MDR as a force multiplier for a small but real internal team, with strong contract hygiene and monthly measurement, get great value. Organizations that treat it as "we bought security" get a false sense of safety, and discover at the worst possible moment that the vendor's job ended at the email notification.

## References

- <https://www.gartner.com/en/information-technology/glossary/managed-detection-and-response-mdr-services>
- <https://www.mandiant.com/services/managed-defense>
- <https://www.crowdstrike.com/services/managed-services/falcon-complete/>
- <https://expel.com/blog/>
- <https://redcanary.com/resources/guides/threat-detection-report/>
- <https://attack.mitre.org/resources/get-started/>

## Related

- [[soc-tier-1-tier-2-tier-3-progression]]
- [[soc-runbook-design]]
- [[soc-shift-handoff-runbook]]
- [[soc-ticket-hygiene-mttr]]
- [[ir-from-source-signals]]
- [[third-party-risk-management-practitioner]]
- [[detection-engineering-pyramid-of-pain]]
- [[purple-team-feedback-loop]]
- [[atomic-red-team-emulation-deep]]
- [[cti-collection-management]]
- [[tabletop-exercise-design-and-execution]]
- [[nis2-implementation]]
- [[soc2-vs-iso27001]]
- [[ransomware-affiliate-playbook]]
- [[case-study-snowflake-2024]]
