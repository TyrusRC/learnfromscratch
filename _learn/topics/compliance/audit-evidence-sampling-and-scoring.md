---
title: Audit evidence, sampling, and scoring
slug: audit-evidence-sampling-and-scoring
aliases: [audit-evidence, sampling-methodology]
---

> **TL;DR:** Audit conclusions are only as defensible as the evidence behind them. This note covers the four classic evidence types (inquiry, observation, inspection, re-performance), how to size and select samples without fooling yourself, how to score findings (effective / partially / ineffective, or SOX-style deficiency tiers), and how to write findings that survive pushback from a control owner who really does not want a "fail." Companion to [[security-auditor-career-track]], [[pentest-report-writing-deep]], [[soc2-vs-iso27001]], and [[pci-dss-4-implementation]].

## Why it matters

A finding without evidence is an opinion. An opinion does not move a control rating, does not satisfy a regulator, and does not survive a thirty-minute meeting with an angry VP of Engineering. Auditors who lose those meetings stop getting invited to the next engagement. Auditors who win them have a workpaper that lays out exactly what they asked for, what they got, when, from whom, and how it failed to meet the stated criteria.

The discipline is not glamorous. It is closer to bookkeeping than to hacking. But it is the backbone of every SOC 2, ISO 27001, PCI, SOX ITGC, HIPAA, and internal IT audit — and increasingly of the assurance work behind [[nis2-implementation]] and AI governance regimes. If you want to do the work credibly, you owe yourself a clear mental model of how evidence and sampling actually function.

## Evidence types, ranked by reliability

Auditors talk about evidence on a rough hierarchy. Higher up means more persuasive, more expensive to produce, and harder to argue away.

### Inquiry (least reliable)

You ask, they answer. A conversation, an email, a Slack thread, a questionnaire. Inquiry is necessary — you cannot test something you do not understand — but it is never sufficient on its own. If a workpaper has nothing but "control owner stated that backups are tested quarterly," that is not a tested control. That is a transcribed claim.

Use inquiry to scope, to identify control owners, to learn how the process is supposed to work, and to surface where to look for corroborating artifacts. Then go look.

### Observation

You watch the control happen in real time. A SOC analyst triages an alert in front of you. A change-advisory board meeting runs while you sit in. A badge reader denies an un-enrolled card during a physical walkthrough.

Observation is point-in-time. It proves the control can run, not that it does run consistently. It pairs well with inspection of historical records.

### Inspection of records

You look at artifacts the system produced as a byproduct of normal operation: ticket history, access-review exports, change-management approvals, CloudTrail events ([[cloud-ir-aws-cloudtrail]]), Azure activity logs ([[cloud-ir-azure-activity-log]]), GCP audit logs ([[cloud-ir-gcp-audit-logs]]), Kubernetes audit logs ([[cloud-ir-k8s-audit-logs]]), SIEM exports ([[siem-detection-use-case-catalog]]), IAM role grants, firewall rule diffs.

This is the bread and butter. Most of audit life is requesting populations, picking samples, and matching artifacts against criteria.

### Re-performance (most reliable)

You re-run the control yourself and compare your result to the system's. You re-calculate a privileged-access list from raw IAM data and compare to the official quarterly review. You re-execute a backup restore. You replay a vulnerability scan against the assets the team claims were scanned.

Re-performance is expensive but decisive. When inspection and inquiry produce contradictory stories, re-performance settles them.

## Sample-size guidance

There is no universal table. AICPA, IIA, and the big-four firms publish their own. A practical rule of thumb most auditors carry in their head:

### Small populations: 100% test

If the control fires fewer than roughly 25 times in the period (annual access reviews, quarterly DR tests, monthly patching cycles), test every occurrence. Sampling a population of 4 quarterly events does not save time and does not improve coverage.

### Medium populations: judgmental sample

Populations from roughly 25 to a few hundred — say, code-change tickets in a month, new-hire provisioning events, terminated-user revocations. Typical sample sizes land at 25, 40, or 60 depending on control frequency and risk. A commonly cited reference: AICPA's frequency table suggests roughly 2 for annual, 2 for quarterly, 5 for monthly, 15 for weekly, 25 for daily, 40 for many-times-daily controls — see external references below.

### Large populations: statistical sampling

Populations in the thousands or tens of thousands (every login, every transaction, every API call). Use a statistical method (attribute sampling, monetary-unit sampling for financial work) with a stated confidence level (typically 90 to 95%) and tolerable deviation rate (typically 5 to 10%). The math gives you a sample size; document the parameters in the workpaper.

### Random vs judgmental selection

Random selection (RANDBETWEEN, Python's `random.sample`, a sampling tool seeded and recorded) is the default. It protects against bias and is the easier story to defend.

Judgmental selection — deliberately picking high-risk items, items near period boundaries, items involving privileged users — is appropriate when you have a reason. Document the reason. "Selected three high-value wire transfers and seven random transactions" is fine; "selected ten transactions" with no method noted is not.

## Walkthrough vs detailed test

A **walkthrough** traces one transaction through the entire control. One change ticket from request through approval through deploy through post-deploy review. The goal is to confirm the control as designed exists and operates. Walkthroughs are usually performed once per control per audit period.

A **test of operating effectiveness** samples the population and checks each sample item against the control's criteria. This is where the bulk of evidence sits.

Mixing the two confuses readers. Keep walkthrough workpapers separate from test-of-operating-effectiveness workpapers, and label them clearly.

## Evidence retention and workpaper hygiene

A workpaper that cannot be re-opened two years later by a different auditor is not a workpaper. Conventions vary by firm, but the core elements are stable:

- **Request log**: what was requested, of whom, when, when received, what was received.
- **Population evidence**: the raw export, with a hash or timestamp, that defines what you sampled from.
- **Sampling method**: the seed, the formula, or the screenshot of the random selection.
- **Sample evidence**: per-item artifacts — screenshots, log excerpts, config snippets, ticket exports. Date and source visible.
- **Tester notes**: pass or fail per item, with a short rationale.
- **Conclusion**: control rating with reference to the work performed.
- **Reviewer sign-off**: separate person, separate date.

Screenshots should show the URL bar, the date, and the user account. Config snippets should record where they came from (`kubectl get ... -o yaml`, `aws iam get-role-policy --role-name ...`, etc.). Logs should be exported with their query and time range visible.

Retention is typically seven years for SOX, five for SOC 2, three to seven for ISO 27001 depending on certification body, six for PCI ([[pci-dss-4-implementation]]). Encrypted at rest, access-logged, with chain-of-custody where the audit may feed litigation.

## Scoring frameworks

### Effective / partially effective / ineffective

The framework most SOC 2 and ISO 27001 work uses. **Effective**: control operated as designed for all sample items. **Partially effective**: control operated for most items but with exceptions that did not aggregate to a control failure (and the residual risk is acceptable). **Ineffective**: control failed for enough items, or one critical item, that the control objective is not met.

The "partial" rating is where most arguments happen. Be explicit about what threshold turned a partial into an ineffective — for example, "more than one exception in a sample of 25" or "any exception involving a privileged account."

### SOX-style deficiency tiers

For financial-reporting controls (and increasingly for security controls scoped into SOX):

- **Control deficiency**: control did not operate as designed, but the risk to the financial statements is low.
- **Significant deficiency**: less severe than material weakness, but important enough to merit attention by those charged with governance.
- **Material weakness**: reasonable possibility that a material misstatement would not be prevented or detected on a timely basis.

The line between significant deficiency and material weakness is judgment-heavy and is where external auditors and management most often disagree. Document the qualitative and quantitative factors that led to the rating.

### Risk-rated security findings

For internal security audits and penetration-test-style work ([[pentest-report-writing-deep]]), most teams use Critical / High / Medium / Low / Informational with a defined rubric (CVSS-adjacent or a custom matrix mapping likelihood and impact). Pick one rubric per engagement and stick to it.

## Finding write-up discipline: the five Cs

Every finding, regardless of framework, benefits from the same structure:

- **Condition**: what we observed. Concrete, dated, with evidence reference.
- **Criteria**: what should be true. Cite the policy, control objective, framework requirement, or contractual obligation.
- **Cause**: why the gap exists. Often the most informative section.
- **Effect**: what could go wrong, with a realistic threat scenario — link to [[case-study-snowflake-2024]], [[case-study-okta-2023-support-system]], or similar incidents where useful.
- **Recommendation**: what management should do, at a level of specificity they can act on.

Some firms add a sixth — **management response** — captured verbatim from the control owner.

## Audit-trail integrity

Your own audit trail must be at least as defensible as the evidence you collect about others. Workpapers in a versioned system, sign-offs recorded, changes to conclusions tracked. If a regulator inspects your firm's workpapers (PCAOB for SOX, ICO for UK data-protection audits, state boards for CPAs), they look for the same things you look for in client controls: who did what, when, and how it was reviewed.

## Pushback management

Control owners argue when they think they will lose. The strongest response is calm and document-driven:

- Re-state the criterion verbatim from the control description or framework. Do not re-litigate what the criterion means in the meeting; you wrote it down at the start of the engagement and the control owner signed off on it.
- Re-state the condition with evidence references. Pull up the screenshot, the log line, the ticket.
- Acknowledge mitigating factors but separate them from the rating. A control can be ineffective and the residual risk can still be low; both can be true on the same page.
- Offer the management-response field. Most disputes deflate when the control owner realises their side of the story will be printed alongside yours.

If the dispute is genuinely about the criterion (the control description was ambiguous, or the framework moved), escalate to the engagement partner. Do not change the rating informally over Slack.

When pushback turns into pressure to suppress a finding, the [[security-auditor-career-track]] note covers professional-conduct expectations and the standards (AICPA, IIA, ISACA) that protect auditors who hold the line.

## Workflow to study

Build one end-to-end test on a control you own at work, even a small one. Pick something concrete — quarterly access review, monthly patching, or daily backup verification. Then practise the full motion:

1. Write the control description and criteria in one paragraph.
2. Identify the population for the period and export it with a timestamp.
3. Choose a sample size using the guidance above, document the rationale.
4. Select samples randomly with a recorded method.
5. Collect inspection evidence for each sample, label each file consistently.
6. Score each item pass or fail with a one-line rationale.
7. Write the conclusion using the five Cs.
8. Hand the workpaper to a colleague and ask them to re-perform your conclusion from the artifacts alone — no conversation, no Slack. If they cannot, the workpaper is not finished.

Repeat for an automated control, a manual control, and a preventive control. After a dozen iterations the rhythm becomes muscle memory and the framework arguments fall away — the work is just the work.

## Related

- [[security-auditor-career-track]]
- [[pentest-report-writing-deep]]
- [[soc2-vs-iso27001]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[siem-detection-use-case-catalog]]
- [[cloud-ir-aws-cloudtrail]]

## References

- https://www.aicpa-cima.com/resources/landing/audit-and-attest-standards
- https://www.theiia.org/en/standards/2024-standards/global-internal-audit-standards/
- https://pcaobus.org/oversight/standards/auditing-standards
- https://www.isaca.org/resources/it-audit
- https://www.iso.org/standard/27001
