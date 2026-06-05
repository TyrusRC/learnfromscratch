---
title: Vulnerability exception management
slug: vuln-exception-management
aliases: [vuln-exception, risk-acceptance-process]
---

> **TL;DR:** Vulnerability exceptions (a.k.a. risk acceptances) are the formal mechanism by which an organisation says "we know about this finding, we will not remediate it now, and here is why." Done well they are a controlled, time-boxed deviation from policy with a named compensating control and a named approver. Done badly they become a permanent dumping ground that hides risk from leadership and gets flagged by every auditor that samples them. This note pairs with [[vulnerability-management-lifecycle]], [[audit-evidence-sampling-and-scoring]], [[patch-management-program]], and [[building-an-iso27001-isms-practitioner]].

## Why it matters

Every mature vuln program eventually accepts that some findings will not be fixed on the standard SLA. The patch is too risky, the vendor has not shipped a fix, the asset is being decommissioned in 90 days, the CVSS is high but exploitability in your environment is low. Without a formal exception process those findings sit in the scanner as "open" forever, the SLA dashboard turns red, leadership stops trusting the numbers, and engineers learn to ignore the tool.

An exception process restores trust in the metric. "Open and past SLA" should mean something. "Accepted with compensating control, expiry 2026-09-01, approved by CISO" is a different state and should be reported separately.

It also matters because auditors sample exceptions. Every PCI QSA ([[building-a-pci-dss-program-practitioner]]), every ISO 27001 lead auditor ([[iso-27001-lead-auditor-certification]]), and every SOC 2 auditor ([[soc2-auditor-track]]) will ask for the exception register and pick two or three to walk through. If those exceptions are missing fields, expired without renewal, or approved by the wrong person, the finding is yours.

## The exception record structure

A usable exception record has roughly these fields. Fewer than this and you cannot defend it. More than this and people stop filing them.

- **Exception ID** — short, unique, traceable. EXC-2026-0142.
- **Vulnerability** — CVE, scanner plugin ID, finding title. If it is a class of finding (all TLS 1.0 endpoints on legacy network) say so.
- **Affected asset(s)** — hostname, IP, container image, repo, application. Tie back to CMDB.
- **Severity / CVSS** — both the raw score and your contextualised score ([[cvssscoring-practitioner]] thinking). A CVSS 9.8 on an air-gapped lab box is not the same risk as a 9.8 on the internet-facing API.
- **Requested by** — the engineer or team asking. Must be a human, not a shared mailbox.
- **Business justification** — why are we not fixing it on SLA. "Patch breaks legacy ERP integration, vendor fix expected Q4." Not "we are busy."
- **Compensating control** — see next section. The single most-skipped field, and the single one auditors care about most.
- **Expiry date** — mandatory. Never "permanent." Never "until vendor fix." A real date.
- **Approver** — see severity-tiered approval below.
- **Audit trail** — date filed, date approved, date last reviewed, date closed (and how — remediated, expired, renewed).

Store this in something queryable. A spreadsheet works at small scale; at any scale ticket system (Jira, ServiceNow) or your vuln management platform (Tenable, Qualys, Rapid7, Wiz) is better. Whatever the substrate, the register has to be the single source of truth.

## Compensating-control discipline

This is where most programs fail. An exception without a compensating control is just "we are not fixing it." A real compensating control reduces the likelihood or impact of the unmitigated vulnerability.

Examples that count:

- **WAF rule** blocking the exploit pattern for an unpatched web app CVE. Rule ID and tuning evidence attached.
- **Network segmentation** — vulnerable host is reachable only from a specific jump host, not from user VLAN. Firewall rule export attached.
- **EDR detection** for the post-exploitation behaviour, mapped to [[detection-engineering-pyramid-of-pain]] and ideally validated via [[atomic-red-team-emulation-deep]].
- **Monitoring** — specific SIEM rule firing on indicators of exploitation, with assigned analyst tier ([[soc-tier-1-tier-2-tier-3-progression]]) and runbook ([[soc-runbook-design]]).
- **MFA / conditional access** restricting who can reach the asset, anchoring back to [[conditional-access-bypass-modern]] thinking on what conditional access actually buys you.
- **Decommissioning plan** — the system is being retired in 60 days, replacement is in UAT, decommission ticket linked.

What does not count: "we have an EDR," "the network is firewalled," "users are trained." Generic controls that exist for every asset are not compensating controls for this exception. The control has to be specific, attributable, and testable.

A useful sanity check: if a [[pentest-engagement-execution]] team or red team ([[cloud-red-team]]) tried to exploit this finding tomorrow, would the compensating control actually stop or detect them? If not, it is not a compensating control.

## Expiry and renewal cadence

Every exception expires. The reasonable defaults:

- **Critical / high CVSS**: 30 to 90 days, then mandatory re-review.
- **Medium**: 90 to 180 days.
- **Low**: up to 12 months, but never silent — still reviewed.

At expiry there are three outcomes: remediated (close), renewed (re-justify, re-approve, new expiry), or escalated (the fact it is still here is itself a finding leadership needs to see).

The trap to avoid: auto-renewal. If exceptions roll forward without a human re-justifying them, you have just built a permanent acceptance with extra paperwork. Auditors notice. Build the workflow so renewal requires the requester to re-state the justification and the approver to re-sign — not just tick a box.

A quarterly exception review meeting works well. Security, engineering lead for the affected system, and a GRC analyst ([[grc-analyst-career-track]]) walk the register, focus on expiring-soon and aged exceptions, and force decisions.

## Who approves at what severity

Approval authority should scale with risk. A common tiered model:

- **Low** — team lead or engineering manager of the owning team.
- **Medium** — head of security or director-level engineering.
- **High** — CISO or equivalent. Documented.
- **Critical** — CISO plus business owner sign-off. For regulated environments, sometimes the board risk committee or audit committee for anything that materially affects the risk register.

Document this in your exception standard ([[policy-and-standards-writing]]) and stick to it. Two anti-patterns to avoid:

- **Approver bottleneck.** If only the CISO can approve anything, the queue blocks and engineers route around the process. Delegate by severity.
- **Approver inflation.** If team leads can approve criticals "because the CISO is busy," your risk register is fiction.

In regulated environments (PCI [[pci-dss-4-implementation]], HIPAA [[hipaa-security-rule]], NIS2 [[nis2-implementation]], DORA, financial regulators), expect the regulator's view that risk acceptance at certain severities is a board-level decision, not an engineering one.

## Audit-trail discipline

The audit trail is the artifact you hand to an auditor when they sample EXC-2026-0142. It must show:

- when the exception was filed,
- by whom,
- with what justification,
- what compensating control was proposed,
- when and by whom it was approved,
- every review or renewal since,
- and how it eventually closed.

Ticket history in Jira or ServiceNow with locked approvals is usually enough. Email approvals from the CISO's personal mailbox are not. See [[audit-evidence-sampling-and-scoring]] for how auditors actually pick samples — they will absolutely pick the oldest and the highest-severity exceptions first.

## Common organisational failure modes

Honest list of what goes wrong in real programs:

- **Exceptions that never expire.** "Expiry: indefinite" or "until vendor patch." These are not exceptions, they are silent risk acceptance. Auditors and incident reviewers will both find them.
- **No compensating control specified.** "Risk accepted by business" with nothing else. When the breach happens this paragraph ends up in the regulator letter.
- **Approver bottleneck.** One person approves everything; queue blows out; engineers stop filing exceptions and just leave findings open instead, which is worse.
- **Exception as default.** Teams file an exception the moment a finding appears, rather than trying to remediate. The exception process becomes the patch-management process by negligence. See [[patch-management-program]] for the healthy alternative.
- **Compensating control is generic.** "We have a WAF" not tied to a rule ID. "We have EDR" not tied to a detection. Useless under scrutiny.
- **No link to risk register.** Exceptions accumulate in the vuln tool but never roll up to the enterprise risk register that leadership sees. The CISO is then surprised at audit time.
- **No metric on the exception register itself.** How many open exceptions? Average age? How many past expiry? If you cannot answer these, you do not really have a program.
- **Verbal approvals.** "The CTO said it was fine in standup." Not auditable, not defensible.

## How exception interacts with audit

Auditors sample. Always. The pattern across [[soc2-vs-iso27001]], PCI ROC ([[building-a-pci-dss-program-practitioner]]), HIPAA assessments ([[hipaa-security-rule]]), and internal audit ([[internal-audit-vs-external-audit]]) is the same:

1. Auditor asks for the exception / risk-acceptance register.
2. Auditor picks 3 to 10 samples (often: oldest, highest severity, most recently renewed).
3. For each: walk me through the justification, show me the compensating control, show me approval, show me the most recent review.
4. Anything missing is a finding.

For ISO 27001 ([[building-an-iso27001-isms-practitioner]]) this maps to Annex A controls on vulnerability management and risk treatment. For PCI 4.0 ([[pci-dss-4-implementation]]) it ties to the compensating-control documentation requirements. For SOC 2 ([[soc2-auditor-track]]) it shows up under change management and vulnerability management criteria.

## Regulatory expectations

Briefly, by regime:

- **PCI DSS 4.0** ([[pci-dss-4-implementation]]) — compensating controls are formally defined and require a Compensating Control Worksheet. Not the same as an exception, but adjacent — and PCI is the regime with the most prescriptive language about what "above and beyond" means.
- **ISO 27001** ([[building-an-iso27001-isms-practitioner]]) — risk acceptance is a valid risk treatment option but must be documented in the risk treatment plan, with named owner and review cadence.
- **HIPAA Security Rule** ([[hipaa-security-rule]]) — "addressable" specifications allow alternatives or no implementation if justified; the documentation requirement is real, OCR audits look for it.
- **NIS2 / DORA** ([[nis2-implementation]]) — expect management body accountability for material risk acceptances; regulators will want to see the decision trail.
- **SOC 2** ([[soc2-vs-iso27001]]) — auditors will sample exceptions to validate the change-management and vulnerability-management criteria.

## Workflow to study

1. Pull your current "open past SLA" list from the vuln scanner and tag every item: would-remediate, would-accept, decommissioning, unknown.
2. For each "would-accept", try to write a real exception record using the structure above. Notice how many cannot articulate a real compensating control.
3. Define your approval tiers and write them into the exception standard ([[policy-and-standards-writing]]).
4. Pick a substrate (ticket system, GRC tool, vuln platform module) and migrate the register.
5. Run a quarterly review meeting. Force decisions on aged items.
6. Build the metric: open count, aged count, past-expiry count, by severity. Report monthly.
7. Tabletop ([[tabletop-exercise-design-and-execution]]) a "regulator just asked for the exception register" scenario.

## Related

- [[vulnerability-management-lifecycle]]
- [[patch-management-program]]
- [[audit-evidence-sampling-and-scoring]]
- [[building-an-iso27001-isms-practitioner]]
- [[building-a-pci-dss-program-practitioner]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[soc2-vs-iso27001]]
- [[policy-and-standards-writing]]
- [[third-party-risk-management-practitioner]]
- [[cvssscoring-practitioner]]
- [[grc-analyst-career-track]]
- [[internal-audit-vs-external-audit]]

## References

- https://www.pcisecuritystandards.org/document_library/ — PCI DSS 4.0 and Compensating Control Worksheet guidance.
- https://www.iso.org/standard/27001 — ISO/IEC 27001 risk treatment language.
- https://www.hhs.gov/hipaa/for-professionals/security/index.html — HHS guidance on addressable specifications and documentation.
- https://csrc.nist.gov/projects/risk-management/about-rmf — NIST RMF, including risk acceptance as a treatment option.
- https://www.first.org/cvss/ — CVSS specification, useful when defending contextualised severity in an exception.
- https://www.enisa.europa.eu/topics/risk-management — ENISA guidance relevant to NIS2-era risk acceptance documentation.
