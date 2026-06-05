---
title: Security policy and standards writing
slug: policy-and-standards-writing
aliases: [policy-writing, standards-writing]
---

> **TL;DR:** Security policy work is unglamorous load-bearing infrastructure. A policy says *what we do and why*; a standard pins down *the specific requirement*; a procedure is *the how-to*; a guideline is *a recommendation*. Most policy disasters come from copy-pasted templates that contradict reality, mandate impossible controls, or are too long to read. This note is the practitioner companion to [[building-an-iso27001-isms-practitioner]], [[building-a-pci-dss-program-practitioner]], [[grc-analyst-career-track]], [[security-auditor-career-track]], and [[appsec-maturity-checklist]] — written for the security engineer who got handed "own the InfoSec policy set" and needs to ship something an auditor and an SRE will both tolerate.

## Why it matters

Policies are how the security function scales beyond a single human. They are also the artefact every auditor, regulator, customer security questionnaire, and incoming CISO reads first. Bad policy creates three failure modes:

- **Audit findings.** ISO 27001, SOC 2, PCI DSS 4.0, HIPAA, NIS2 all require documented policies reviewed at defined cadence. See [[soc2-vs-iso27001]] and [[pci-dss-4-implementation]] for the specific control families that demand documents.
- **Operational drift.** Engineers ignore policy that contradicts the platform reality. Once ignored, the policy becomes evidence of negligence in a breach.
- **Risk-acceptance black holes.** If the standard says "MFA on every admin account" and 12% of accounts can't support it, you need a formal exception path. No path means undocumented risk hiding in tickets.

Policy is not paperwork theatre. It is the contract between security and the rest of the business that decides what risk gets accepted, by whom, and for how long.

## The document hierarchy

Confusing these four layers is the single most common mistake on a young GRC team.

### Policy

- **What it says:** Intent and scope. "We require multi-factor authentication on all access to systems handling customer data."
- **Audience:** Executives, auditors, the board, regulators.
- **Length:** 1–4 pages. If it's longer, you're writing a standard.
- **Change cadence:** Annual review, executive sign-off.
- **Voice:** Declarative, plain English, no vendor names.

### Standard

- **What it says:** The specific, measurable requirement. "MFA must be phishing-resistant (FIDO2 or smartcard) for all production admin access. TOTP is acceptable for non-admin workforce access until 2026-12-31."
- **Audience:** Engineers, control owners, internal audit.
- **Length:** 3–20 pages depending on domain.
- **Change cadence:** Reviewed at least annually; revised whenever the threat model or platform changes.
- **Voice:** Testable. Every clause should produce a yes/no audit answer.

### Procedure

- **What it says:** Step-by-step how to comply. "To onboard a new admin: open ticket in IAM project, attach manager approval, run script `provision-admin.sh`..."
- **Audience:** Operators doing the work.
- **Length:** Whatever it takes; lives in the runbook system, not the policy portal.
- **Change cadence:** Whenever the tooling changes.

### Guideline

- **What it says:** Recommended practice when no strict rule applies. "We recommend storing secrets in the platform secret manager rather than environment variables."
- **Audience:** Engineers making design choices.
- **Voice:** Advisory, not mandatory. Use "should" not "must".

If you only remember one thing: **policies do not contain commands; standards do not contain rationale; procedures do not appear in audit reports.** Mix them and every layer becomes unmaintainable.

## Tone and audience

Write for two readers at once and the document fails both. Split the set instead.

- **Executive policy** is read by the audit committee and the legal team. Keep it under four pages, no acronyms without expansion, no implementation detail. The CEO should be able to read it on a phone and understand what they just signed.
- **Engineering standards** are read by SREs, platform teams, application security, and internal audit. These can be specific, opinionated, and reference platform primitives by name ("EKS pod security admission", "Azure Policy `[Deny] storage account public access`"). Engineers respect documents that show the author has actually shipped the control.
- **Guidelines and runbooks** sit in the wiki next to the code. Cross-link from standards rather than duplicating.

Common voice mistakes:

- Using "shall" everywhere. "Must" is clearer in modern English; pick one and stay consistent.
- Hedging with "where appropriate" or "as feasible" — these phrases neuter the requirement and auditors will flag them.
- Naming a single vendor in a policy ("Okta MFA"). Use the capability ("a centrally managed identity provider supporting FIDO2"). Standards can name the chosen vendor; policy should not.

## Length discipline

Long policies don't get read. Long policies don't get *enforced*. A 60-page "Information Security Policy" PDF is a confession that the organisation has no working policy at all.

Rule of thumb:

- Policy: under 4 pages.
- Per-domain standard (access control, cryptography, logging, vulnerability management): 5–15 pages.
- Total policy/standard set for a mid-size org: 80–150 pages across 12–20 documents.

If you're at 400 pages, you've either copied a template wholesale or you're using policy as a place to dump procedures. Both are fixable: split, demote to runbook, or delete clauses that nobody can point to a control owner for.

## Reference frameworks as scaffolding

Don't write from a blank page. Map your policy set against a well-known control catalog and let the framework do the structural work.

- **ISO 27001 Annex A (2022 edition, 93 controls in 4 themes)** is the most common scaffolding outside the US. Group your standards along Organizational, People, Physical, Technological themes. See [[building-an-iso27001-isms-practitioner]].
- **NIST CSF 2.0** (Govern, Identify, Protect, Detect, Respond, Recover) is more popular in US and increasingly EU critical-infrastructure contexts.
- **CIS Controls v8.1** is engineer-friendly and pairs well with technical standards; not sufficient on its own for ISO/SOC 2 audit but excellent for the "what should our baseline actually be" question.
- **PCI DSS 4.0** is prescriptive enough to double as a standard for the cardholder-data environment scope. See [[pci-dss-4-implementation]].
- **HIPAA Security Rule** maps cleanly onto an access-control + audit-logging + encryption triad for ePHI scope. See [[hipaa-security-rule]].
- **NIS2** drives policy requirements around incident reporting timelines and supply-chain risk in the EU. See [[nis2-implementation]].

Maintain a **control mapping spreadsheet** (rows = your standards' clauses, columns = ISO Annex A, NIST CSF, SOC 2 CC, PCI DSS, HIPAA, CIS, internal control IDs). This single artefact saves weeks of audit prep per year.

## Version control and change management

Policy without version control is fiction. Practical pattern:

- Source of truth is Markdown in a Git repo with PR review. Render to PDF/HTML for the policy portal on merge.
- Every document has a header block: version, effective date, next review date, owner role (not person), approver role.
- Use semantic-ish versioning: major = scope or requirement change, minor = clarification, patch = typo.
- Tag the repo at each executive approval; the tag is the evidence auditors want.
- Maintain a changelog at the bottom of each document. Auditors and engineers both ask "what changed since last year?"

Avoid Word documents emailed around for sign-off. They get lost, branched, and the wrong copy ends up in the customer trust portal six months later.

## Exception handling

No policy survives contact with production. Build the exception process *before* you publish the first standard.

A workable exception record contains:

- The specific clause being violated.
- The system, scope, and business owner.
- The compensating control (what mitigates the risk in the absence of compliance).
- The risk acceptance level and who signed it (typically tiered: engineering manager up to CISO up to CEO based on residual risk).
- An expiry date (90 days, 6 months, 12 months — never "permanent").
- A re-review trigger.

Track exceptions in the same system as risks (GRC tool, Jira, whatever the org already uses). The metric that matters: **count of expired exceptions still in production**. If it grows, the process is broken or the standard is unrealistic.

This is the bridge to risk acceptance: every exception is a documented risk acceptance, and the aggregate of exceptions tells you where your policy set is out of step with reality.

## Common bad patterns

- **Template copy-paste.** A policy that mentions "datacentre badge access" when the company is 100% cloud-native signals you bought a template. Auditors notice. So do engineers, who then dismiss the whole set.
- **Contradictions across documents.** Access policy says 90-day password rotation; identity standard says NIST SP 800-63B passphrase model with no rotation. Pick one. Run a quarterly internal review to catch drift between documents.
- **Impossible controls.** "All code must be reviewed by two engineers before merge to main" — fine for product code, impossible for emergency hotfixes, terraform auto-formatting bots, dependabot PRs. Carve out exceptions in the standard itself, not later in a sea of one-off approvals.
- **Buzzword stuffing.** "Zero Trust", "AI-driven", "shift left" in policy text adds nothing and dates instantly.
- **Mandating tools the org doesn't own.** Don't require DLP if there's no DLP budget. Either get the budget approved before writing the clause or write the clause to match what you actually have.
- **No control owner.** Every standard clause should map to a named role responsible for the control. "Security team" is not a role.
- **Forgetting the auditor's view.** If a clause cannot be evidenced (log, report, screenshot, signed record), it cannot be audited and probably isn't really enforced.

## Regulator and auditor expectations on review cadence

Most frameworks expect at least annual policy review with documented approval. Practical reality:

- **ISO 27001:** Annual management review of the ISMS includes policy review. Document the meeting minutes.
- **SOC 2:** Auditors want evidence the policy was reviewed and approved within the audit period. Date-stamped approval in the repo + ticketing system works.
- **PCI DSS 4.0:** Annual review explicitly required; some controls require more frequent (e.g., risk analysis tied to customised approach).
- **HIPAA:** "Periodic" review; in practice annual is the safe interpretation.
- **NIS2:** Member-state transposition varies, but expect annual review plus event-driven updates after significant incidents or threat-landscape shifts.

Set calendar reminders 60 days before each policy's next-review date. Treat the review as a real exercise: ask the control owner whether the clause still matches reality, not a rubber-stamp re-approval.

## Workflow to study

A realistic first 90 days if you've just been handed the policy set:

1. **Inventory.** List every document, its owner, last approval date, and where it lives. Half of them will be unowned.
2. **Map to a framework.** Pick ISO 27001 Annex A or NIST CSF and build the control-mapping spreadsheet.
3. **Find contradictions.** Read access control, identity, cryptography, logging, and vulnerability management end-to-end. Note every conflict.
4. **Interview five engineers.** Ask "which of these do you actually follow?" The gap between policy and practice is your real backlog.
5. **Triage.** Mark each document: keep / rewrite / merge / delete.
6. **Rewrite the top three.** Usually access control, acceptable use, and incident response. Get them through executive approval.
7. **Stand up the exception process** before publishing the rewritten standards.
8. **Move to source control.** Migrate from Word/PDF to Markdown-in-Git with PR review.
9. **Build the review calendar.** Stagger annual reviews so you're not approving 15 documents in one quarter.

Pair this with the maturity baseline in [[appsec-maturity-checklist]] and the rollout pattern in [[secure-sdlc-rollout-playbook]].

## Related

- [[building-an-iso27001-isms-practitioner]]
- [[building-a-pci-dss-program-practitioner]]
- [[grc-analyst-career-track]]
- [[security-auditor-career-track]]
- [[appsec-maturity-checklist]]
- [[soc2-vs-iso27001]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[secure-sdlc-rollout-playbook]]
- [[responsible-disclosure-across-jurisdictions]]

## References

- ISO/IEC 27001:2022 and 27002:2022 — official standards, purchase via https://www.iso.org/standard/27001
- NIST Cybersecurity Framework 2.0 — https://www.nist.gov/cyberframework
- CIS Critical Security Controls v8.1 — https://www.cisecurity.org/controls
- PCI DSS v4.0.1 document library — https://www.pcisecuritystandards.org/document_library/
- SANS Information Security Policy Templates — https://www.sans.org/information-security-policy/
