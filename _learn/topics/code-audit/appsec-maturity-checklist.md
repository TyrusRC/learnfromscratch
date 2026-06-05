---
title: AppSec maturity checklist
slug: appsec-maturity-checklist
aliases: [appsec-program-maturity, bsimm-samm-checklist]
---

{% raw %}

> **TL;DR:** Maturity models (BSIMM, OpenSAMM, ASVS, NIST SSDF) describe what a mature appsec program looks like. This note is a practical checklist scaled to startup/scaleup teams — what level you're at, what the next step looks like, and what each level catches that the previous misses. Use it to plan, not to audit.

## What it is
A maturity checklist groups practices into levels. Level 1 is "minimum viable security"; higher levels add depth, automation, and culture. The goal is conscious progression — each level builds on the previous and addresses bugs that survive earlier-level practices.

## Level 0 — Aware
*"We know security exists."*
- Someone owns security part-time.
- Customer complaint or pen test happens.
- Findings handled ad-hoc.

**Bugs that survive**: virtually everything.

**Next step**: hire / dedicate someone, write an incident response runbook.

## Level 1 — Reactive
*"We respond when bugs are reported."*
- Bug bounty or report inbox exists.
- Findings triaged and fixed.
- Basic secret-scanning + dep CVE check in CI.
- Sentry / Datadog for runtime error monitoring.

**Bugs that survive**: anything not reported. Specifically: chained bugs, design-level bugs, complete absence of authz on internal endpoints.

**Next step**: introduce SAST in CI, threat-model new features.

## Level 2 — Preventive
*"We catch bugs before deploy."*
- SAST (Semgrep / CodeQL / Snyk Code) in PR with PR-blocking on high-severity new findings.
- SCA (Snyk / Dependabot) in PR.
- Secret scanning pre-commit + CI.
- New features threat-modeled before design freeze.
- Auth/authz code reviewed by a designated reviewer.

**Bugs that survive**: false-negatives of SAST (logic bugs, design flaws), bugs that only appear in integration.

**Next step**: add DAST against staging, write a security-aware test suite.

## Level 3 — Tested
*"We verify, not just check."*
- DAST (ZAP / Burp Enterprise) against staging weekly.
- Authz integration tests per role.
- Security test suite alongside functional tests (negative cases, fuzz).
- Penetration test 2x/year.
- Security champions per team.

**Bugs that survive**: production-only bugs (CDN cache, edge cases), social engineering surfaces, supply-chain.

**Next step**: production observability for security signals, supply-chain hardening.

## Level 4 — Observed
*"We see what's happening in production."*
- WAF or runtime protection (Cloudflare, AWS Shield, RASP).
- SIEM with correlation rules: failed login bursts, privilege change events, unusual data egress.
- Anomaly detection on key actions (refund, admin, data export).
- Pre-deploy security gates with audit trail.
- Supply-chain: SBOM, signed artifacts, reproducible builds, sigstore.
- Incident response drills quarterly.

**Bugs that survive**: novel attack patterns, insider risk, sophisticated APT.

**Next step**: continuous adversarial validation, threat intelligence integration.

## Level 5 — Adversarial
*"We attack ourselves continuously."*
- Red team continuous engagement (in-house or contracted).
- Purple team feedback loop ([[purple-team-feedback-loop]]).
- Threat intel feeding detection engineering.
- Chaos engineering for security (force failure to test detection).
- Pre-prod security regression suite covers all historical incidents.
- Org-wide security training with phishing drills.

**Bugs that survive**: zero-days, unique novel vulnerability classes.

## Checklist (compact form)

### Discover
- [ ] Asset inventory: every service, every repo, every cloud account.
- [ ] Internet-exposed surface continuously catalogued.
- [ ] Per-asset risk tier (P0/P1/P2).

### Build
- [ ] SAST in PR, blocking on new high-severity.
- [ ] SCA in PR, blocking on known-critical CVEs.
- [ ] Secret scanning pre-commit + CI.
- [ ] Threat model for new features touching trust boundaries.
- [ ] Code review by security-aware reviewer for auth / authz / crypto.
- [ ] Test suite includes per-role authz tests + fuzz.

### Deploy
- [ ] Signed artifacts (Sigstore, Notary).
- [ ] SBOM generated and stored per build.
- [ ] Container scan in registry.
- [ ] IaC scan (Checkov / tfsec / Trivy) on Terraform/CloudFormation.
- [ ] No secrets in env or args; secret manager only.

### Operate
- [ ] WAF in front of public surface.
- [ ] Rate limit per-endpoint.
- [ ] Logging includes security events (auth fail, role change, data export).
- [ ] SIEM with alerts on anomalies.
- [ ] On-call rotation includes security paging.

### Verify
- [ ] DAST weekly against staging.
- [ ] Pen test 2x/year.
- [ ] Bug bounty (if scale appropriate).
- [ ] Red team (level 4+).

### Respond
- [ ] Incident response runbook tested via drill.
- [ ] Tabletop exercises quarterly.
- [ ] Post-incident review with action items.
- [ ] Customer disclosure policy documented.

### Train
- [ ] Onboarding includes appsec module.
- [ ] Annual training refresher.
- [ ] Phishing drill quarterly.
- [ ] Internal CTF or hack day.

## Mapping to formal frameworks

| Checklist item | ASVS L1-L3 | NIST SSDF | BSIMM |
|----------------|------------|-----------|-------|
| SAST in CI | V1-V14 | PW.6 | CR2.5 |
| Threat model | V1.1 | PW.1 | AM2.5, AA1.1 |
| Secret scanning | V14.1 | PS.1 | SE2.4 |
| Authz tests | V4 | PW.7 | ST2.4 |
| DAST | V13 | PW.7 | PT3.1 |
| SBOM | V14.2 | PO.5 | SE3.2 |
| Pen test | various | RV.1 | PT1.1 |
| IR runbook | V1.10 | RV.2 | CMVM1.1 |

## How to use this

### Self-assessment
- Honest answer per item: yes/partial/no.
- Score your level.
- One quarter, pick 3 items at the next level to implement.

### Roadmap
- Don't try to jump 2 levels at once.
- Each item has org-change cost. Plan accordingly.

### Audit
- Threat-model is harder than SAST. Threat-model first; SAST follows.
- Authz tests harder than fuzz. Authz first.

## References
- [BSIMM — Building Security In Maturity Model](https://www.bsimm.com/)
- [OWASP SAMM](https://owaspsamm.org/)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
- [NIST SSDF (SP 800-218)](https://csrc.nist.gov/Projects/ssdf)
- [CISA Secure Software Development Attestation](https://www.cisa.gov/secure-software-attestation-form)
- See also: [[appsec-threat-modeling]], [[sast-dast-ci-integration]], [[authorization-patterns-rebac-abac]]

{% endraw %}
