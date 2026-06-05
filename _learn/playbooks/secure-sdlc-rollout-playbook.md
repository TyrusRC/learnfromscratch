---
title: Secure-SDLC rollout playbook
slug: secure-sdlc-rollout-playbook
aliases: [ssdlc-rollout, secure-sdlc-playbook]
---

{% raw %}

> **TL;DR:** Rolling out a secure SDLC means sequencing controls so each one delivers value without blocking development. Start with secrets-in-code detection (fast, cheap, high-ROI). Move to SAST in CI gating only on high-confidence rules. Add SCA, then threat modelling for new services, then DAST, then security champions. Skip the order and you build a security backlog nobody reads. Companion to [[appsec-maturity-checklist]] and [[sast-dast-ci-integration]].

## Why sequencing matters

Every security control creates friction. A team that hits the wrong control first ("we have to threat-model every PR before merge") burns goodwill and gives up. Sequence to deliver visible wins early.

## The six waves

### Wave 1 (weeks 1-4) — Secrets in code

- Why first: catches the riskiest leak, takes one CI step, false-positive rate is low.
- Tooling: TruffleHog or gitleaks in pre-commit + CI.
- Pre-rollout: scan history once; rotate every found secret.
- Rollout: gate new commits; ratchet up over a week.
- Deliverable: zero new secrets after week 2; rotation runbook documented.

```yaml
# .github/workflows/secrets.yml
on: [pull_request, push]
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: trufflesecurity/trufflehog@main
        with: { extra_args: --only-verified }
```

### Wave 2 (weeks 4-8) — Dependency scanning (SCA)

- Why second: high-value, well-understood (every team already runs `npm audit` informally).
- Tooling: Dependabot/Renovate for PRs, Trivy/Snyk in CI.
- Initial gate: critical only. Don't break the build on highs/mediums yet.
- Deliverable: 30-day mean-time-to-remediate critical CVEs ≤ 7 days; tracked.

### Wave 3 (weeks 8-16) — SAST with curated rules

- Why third: high signal once tuned, but needs rule curation per language.
- Tooling: CodeQL or Semgrep with team-tuned rulesets.
- Initial gate: hand-picked high-confidence rules (no SQLi, eval, command-inj).
- Strategy: enable rules in "audit" mode (report-only) for a sprint; promote to "blocking" only after you've seen them not produce noise.
- Deliverable: 0 deploys with high-confidence SAST findings.

### Wave 4 (weeks 16-24) — Threat modelling for new services

- Why fourth: requires that teams have time + appsec mentorship.
- Pattern: every new service ≥ 1 endpoint requires a threat model before architecture approval.
- Tooling: STRIDE/PASTA template, Microsoft Threat Modeling Tool, or just a Markdown doc.
- Deliverable: 100% of new services have a threat model; quarterly review of legacy.

### Wave 5 (weeks 24-36) — DAST in staging

- Why fifth: produces noise until your test environments mirror prod.
- Tooling: OWASP ZAP baseline scan against staging; Burp Suite Enterprise for deeper.
- Strategy: nightly against staging, weekly against prod (read-only).
- Deliverable: regression-detection within 24h; published runbook for triage.

### Wave 6 (weeks 36-52) — Security champions and bug-bounty

- Why last: requires trust and existing programmes to absorb feedback.
- Champions: one volunteer per team, monthly meet-up, internal Slack channel.
- Bug-bounty: start internal-only (HackerOne private programme); expand carefully.
- Deliverable: external researchers report bugs; SOC routes correctly; SLA met.

## What to *not* do early

| Don't | Why |
|---|---|
| Gate on SAST highs/mediums in week 1 | Noise → team disables it |
| Threat-model every PR | Bottleneck |
| Mandate manual review for every release | Doesn't scale |
| Pick a tool because it's "enterprise-ready" | The fastest tool wins if it ships in CI |
| Run DAST against prod before you control egress | Outages, customer impact |

## Telemetry the rollout team needs

| Metric | Target | Why |
|---|---|---|
| MTTR for critical CVEs | ≤ 7 days | Wave 2 |
| % deploys passing SAST gate | ≥ 99% | Wave 3 |
| % new services with threat model | 100% | Wave 4 |
| Mean DAST findings per week | trending down | Wave 5 |
| External researcher hand-offs to dev | < 5 days median | Wave 6 |

## Anti-patterns

- "We bought $tool, that's our security programme". Tools without process don't move the needle.
- Security team owns remediation. Should own *visibility*; dev teams own remediation.
- One tool per category. Pick one SAST, one SCA, one DAST. Multiple = duplicate findings and triage cost.
- Compliance-driven controls without security-driven controls. PCI-DSS isn't a threat model.

## Handing over to BAU

Each wave's runbook should answer:
- Where does the alert/finding go?
- Who triages?
- What's the SLA?
- How does a finding get closed (fixed / accepted-with-justification / false-positive)?
- Who escalates?

Without these answers, every wave just produces backlog.

## Integration with adjacent disciplines

- **IR**: SAST/DAST findings inform IR playbooks; an incident replays through SAST to confirm the bug class isn't widespread. See [[ir-from-source-signals]].
- **Detection**: vulnerabilities found in SAST seed EDR rules. See [[edr-rules-as-code-from-attack-patterns]].
- **Procurement**: vendor-onboarding security review uses the same threat-model template.

## When the org won't let you start

- Run the first wave (secrets detection) as a personal-time experiment on one team's repos. Show numbers.
- Use a near-miss / public-incident to justify the next wave.
- Tie waves to existing compliance targets (SOC2, ISO 27001 controls).

## References
- [BSIMM](https://www.bsimm.com/) — empirical model of mature appsec programmes
- [OWASP SAMM](https://owaspsamm.org/) — maturity model with concrete activities
- [Microsoft SDL](https://www.microsoft.com/en-us/securityengineering/sdl) — Microsoft's secure SDLC
- [Snyk State of Open Source Security](https://snyk.io/reports/) — empirical data
- See also: [[appsec-maturity-checklist]], [[sast-dast-ci-integration]], [[appsec-threat-modeling]], [[ir-from-source-signals]], [[edr-rules-as-code-from-attack-patterns]]

{% endraw %}
