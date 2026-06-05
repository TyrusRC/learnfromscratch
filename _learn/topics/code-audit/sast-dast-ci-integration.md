---
title: SAST / DAST / IAST in CI — integration patterns
slug: sast-dast-ci-integration
aliases: [security-tools-ci, codeql-semgrep-ci]
---

{% raw %}

> **TL;DR:** Most SAST/DAST tools work; few are wired correctly. The integration matters more than the tool: where in the pipeline, what triggers a block, who reviews findings, and how false positives die quietly. This note covers Semgrep/CodeQL/Bandit/Snyk/Burp/OWASP ZAP integration patterns that scale beyond "we have a daily scan with 5000 unread findings."

## What it is
- **SAST** — Static Application Security Testing: analyses source code. CodeQL, Semgrep, SonarQube, Snyk Code, Bandit (Python), Brakeman (Rails).
- **DAST** — Dynamic Application Security Testing: hits running app. OWASP ZAP, Burp Suite, Nuclei, w3af.
- **IAST** — Interactive: instruments running app (Contrast Security, Seeker).
- **SCA** — Software Composition Analysis (deps): Snyk Open Source, Dependabot, OSV-Scanner, Trivy.
- **Secrets scanning**: gitleaks, trufflehog, GitHub Secret Scanning.

## Goals of CI integration
- Find real bugs before deploy.
- Don't drown the dev team in false positives.
- Block deploy only on high-confidence + high-severity.
- Funnel findings to security review queue with context.
- Track resolution; close out stale findings.

## Pipeline placement

### Pre-commit (developer machine)
- Fast, local. Catch obvious mistakes before push.
- Examples: gitleaks for secrets, Semgrep ruleset for hot-spot patterns, eslint-plugin-security.
- Implementation: husky / lefthook git hooks.

### Pull-request CI
- Runs on PR diff. Fast (< 5 min).
- Comments on findings inline.
- Blocks merge for high-severity new findings (NOT existing — that's noise).
- Examples: Semgrep diff scan, Snyk PR check, CodeQL on changed files (since 2.18, fast mode).

### Main branch / nightly
- Full-scan, slow OK (60+ min).
- CodeQL full database build.
- DAST against staging.
- Output to issue tracker, not PR.

### Pre-deploy / release
- Hard gates on critical findings.
- Dep CVE check (no known-critical CVE in production deps).
- Container scan if shipping containers.

## SAST configuration patterns

### Semgrep
```yaml
# .semgrep.yml
rules:
  - p/owasp-top-10
  - p/javascript
  - p/typescript
  - p/security-audit
  - p/secrets
  - <internal-rules-repo>
```
- Run on PR with `--baseline-ref origin/main` to scope to diff.
- Custom rules for project-specific anti-patterns.
- Findings posted as PR comments via [semgrep-action](https://github.com/returntocorp/semgrep-action).

### CodeQL
- GitHub Code Scanning native integration.
- `codeql-action` workflow on PR (changed-files mode in 2.18+) + nightly full.
- Custom queries in `.github/codeql/custom-queries/` for project anti-patterns.
- Suppress with `# lgtm[ruleid]` comments (legacy) or `// codeql[ruleid]` (current).

### Snyk Code
- PR check via GitHub app.
- Configurable severity gates.
- Auto-fix PRs for some rules.

### Bandit (Python)
- `bandit -r src/ -f json -o bandit-out.json`.
- `# nosec` comments to suppress (audit suppressions periodically).

### Brakeman (Rails)
- `brakeman --rails -A --no-progress --quiet --confidence-level 2`.
- Ignore file `.brakeman.ignore` — committed; reviewed in PRs.

## DAST configuration patterns

### OWASP ZAP
- Baseline scan in PR (passive, fast).
- Full scan nightly against staging.
- Authenticated scan via session script or [zap-baseline-action](https://github.com/zaproxy/action-baseline).

### Burp Suite Enterprise
- Scheduled scans against staging.
- CI integration via REST API.
- Findings funnel to JIRA.

### Nuclei
- Template-based scanner; great for known CVE checks.
- `nuclei -u https://staging -t cves/ -severity critical,high`.

## SCA / Dep scanning

### Configuration
- Snyk Open Source, Dependabot, Renovate, OSV-Scanner.
- Choose one primary; multiples create noise.
- Auto-PR for low-risk dep bumps (patch versions, dev deps).
- Human review for major version bumps.

### Lockfile diff review
- Required reviewer on any `package-lock.json` / `Gemfile.lock` / `go.sum` / `Cargo.lock` change.
- Bot-generated lockfile changes especially.

### CVE response
- New critical CVE on prod dep: hot fix.
- Renovate / Dependabot creates PR within hours of disclosure.
- SLA: critical patched in 24h, high in 7d, medium in 30d.

## Secrets scanning

### Pre-commit
- gitleaks as a hook.
- detect-secrets baseline for monorepos.

### CI on PR
- `gitleaks detect --redact` — fail on new findings.
- GitHub Secret Scanning auto-rotation for partner-supported tokens.

### Periodic full-history
- Full repo scan weekly.
- Builds container scan.
- Production runtime: token honeypots (CanaryTokens) detect leak in use.

## False positive management

### The hard part
- 80% of findings are FP. Without management, dev team disables checks.
- Solutions:
  - Baseline / suppress: existing findings ignored; only new ones block.
  - Per-rule severity tuning.
  - Allowlist file with expirations (auto-reopen after 90 days).
  - Quarterly review of suppressions.

### Anti-patterns
- "Disable rule globally" — kills the signal.
- "Suppress per-file forever" — same.
- "Reviewer rubber-stamps" — no quality gate.

## Findings funnel

### Severity-based routing
- Critical: page on-call security.
- High: JIRA ticket auto-assigned to feature team.
- Medium: queued for sprint planning.
- Low: bulk review monthly.

### Context enrichment
- Findings include: source file, suggested fix, risk explanation, link to docs.
- "Why is this a bug?" — devs need context, not just rule ID.

### Closing the loop
- Track time-to-fix per severity.
- Anomalously slow → investigate (real complexity? rule misfire? team capacity?).

## CodeQL + Semgrep combo (best-of-both)
- Semgrep: fast, custom rules, PR-diff mode. Catches anti-patterns specific to your code.
- CodeQL: cross-file taint analysis, full database. Catches variant bugs.
- Run both; Semgrep on PR, CodeQL nightly + on PR for high-signal queries.

## Maintenance

### Ruleset hygiene
- Quarterly review which rules fire most. High-FP rules → tune or disable.
- New high-signal rules added per recent incident.

### Tool upgrade
- Pin SAST tool version; upgrade quarterly.
- Test upgrade on a sample of historical PRs to detect regressions.

## References
- [Semgrep — getting started](https://semgrep.dev/docs/getting-started/)
- [CodeQL — CodeQL for security research](https://codeql.github.com/docs/)
- [OWASP DevSecOps Guideline](https://owasp.org/www-project-devsecops-guideline/)
- [Snyk integration docs](https://docs.snyk.io/)
- [OWASP ZAP automation](https://www.zaproxy.org/docs/automate/)
- See also: [[whitebox-to-exploit-methodology]], [[source-sink-flow-analysis]], [[secrets-in-code-detection-patterns]], [[appsec-maturity-checklist]]

{% endraw %}
