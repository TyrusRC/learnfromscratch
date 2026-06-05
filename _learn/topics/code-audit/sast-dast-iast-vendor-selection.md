---
title: SAST / DAST / IAST — vendor selection
slug: sast-dast-iast-vendor-selection
aliases: [sast-vendor, dast-vendor, iast-vendor, appsec-tooling-selection]
---

> **TL;DR:** Selecting AppSec tooling (SAST, DAST, IAST, SCA, secrets) is less about "which vendor is best" and more about which tool produces *actionable* findings in *your* CI for *your* languages with a noise level developers will tolerate. Marketing decks all claim 95% accuracy; reality is closer to 30–60% precision out of the box, and you will spend 3–9 months tuning. This note is a buyer's guide companion to [[sast-dast-ci-integration]], [[devsecops-platform-engineering]], [[paved-road-pattern-platform]], [[appsec-champions-program]], and [[appsec-maturity-checklist]].

## Why it matters

AppSec tooling is one of the largest line items in a security budget after headcount, and one of the easiest to get wrong. A six-figure SAST contract that developers ignore because every PR has 200 "criticals" produces zero risk reduction. A free Semgrep deployment with 30 carefully tuned rules can outperform it.

The honest framing for vendor selection:

- **Developers are the customer.** If their experience is bad, findings don't get fixed.
- **False positives kill programs faster than missed bugs.** Every false alarm trains devs to ignore the tool.
- **Coverage matters less than depth.** A tool that finds 5 real SQLi a quarter is worth more than one claiming 47 categories but flagging string concatenation as "command injection".
- **CI integration is the product.** Standalone scanners that produce PDFs are dead.

This note focuses on practitioner-level evaluation, not vendor pitches.

## Tool categories

### SAST (Static Application Security Testing)

Analyzes source code or compiled artifacts without executing them. Finds patterns like SQLi via taint analysis, hardcoded secrets, unsafe deserialization. Best for known anti-patterns in code you own.

Notable vendors:

- **Semgrep** — rule-based, open-source core + paid Pro engine. Fast, low false positives, easy custom rules in YAML. Best fit for engineering-heavy orgs that want to write their own rules. Pro engine adds cross-file taint and proprietary rule packs.
- **GitHub CodeQL** — semantic dataflow engine, free for public repos, included in GitHub Advanced Security (GHAS). Very powerful, steep learning curve to write custom queries (QL is its own language). Best fit if you live on GitHub.
- **Snyk Code** — DeepCode acquisition, ML-assisted. Strong IDE integration, decent UX. Marketing-heavy; technical depth is mid-tier.
- **Checkmarx (CxSAST / CxOne)** — enterprise incumbent. Broad language coverage, historically noisy, expensive, slow scans. Used widely in regulated industries.
- **Veracode** — SaaS-only, scans compiled binaries. Strong compliance reporting (good for [[building-a-pci-dss-program-practitioner]] and FedRAMP work). Slower feedback loop due to binary upload model.
- **Sonatype Lift / Muse** — increasingly bundled with their SCA offering.

### DAST (Dynamic Application Security Testing)

Runs against a deployed application, sending crafted requests and observing responses. Finds runtime issues SAST misses: auth bugs, SSRF, IDORs (sometimes), header misconfigurations.

Notable vendors:

- **Burp Suite Enterprise** — PortSwigger's scaled Burp. Same engine pentesters use, scriptable, good API. Best fit if your team already uses Burp Pro.
- **Invicti (Netsparker + Acunetix)** — "proof-based scanning" marketing claim; in practice good at classic web bugs, weaker on modern SPAs and APIs.
- **Tenable Web App Scanning (was Nessus WAS)** — integrates with broader Tenable vuln management. Average web coverage, useful if you already standardize on Tenable.
- **Rapid7 InsightAppSec** — similar story to Tenable.
- **OWASP ZAP** — free, scriptable, decent for CI smoke tests, not a replacement for a real DAST tool at scale.

### IAST (Interactive Application Security Testing)

Instruments the running application (agent/runtime hook) to observe code paths actually executed during tests. Lower false positives than SAST or DAST because it sees the real runtime flow.

Notable vendors:

- **Contrast Security** — category leader. Agents for Java, .NET, Node, Python, Ruby. Also offers RASP. Pricey, but the runtime evidence is genuinely high quality.
- **Veracode IAST** — bundled with their platform.
- **Synopsys Seeker** — formerly competitive, declining mindshare.

IAST reality check: requires you to actually exercise the code (good QA / integration tests). Useless against code paths your tests never touch.

### SCA (Software Composition Analysis)

Tracks open-source dependencies and known CVEs. The single highest-ROI AppSec tool for most orgs because the majority of code in any modern app is third-party.

Notable vendors:

- **Snyk Open Source** — strong UX, good fix PRs, broad ecosystem coverage. Pricing scales aggressively with developer count.
- **Mend (was WhiteSource)** — solid enterprise SCA, good license compliance features.
- **Sonatype Nexus IQ / Lifecycle** — strong on policy enforcement and proxy/firewall use cases (block bad packages at the registry).
- **GitHub Dependabot** — free, decent for non-critical paths. No reachability analysis; flags every transitive CVE.
- **GitHub Advanced Security (GHAS) SCA** — Dependabot + extras, bundled at per-seat pricing.
- **OWASP Dependency-Check** — free, OWASP, works but high noise.

Reachability analysis (does the vulnerable function actually get called?) is the differentiator in 2025. Snyk, Endor Labs, Semgrep Supply Chain all play here. See [[npm-postinstall-and-typosquat-audit]] and [[python-pypi-supply-chain-audit]] for the threat side.

### Secret scanning

Finds API keys, tokens, credentials in source and history.

- **GitHub Secret Scanning** — free for public, paid (GHAS) for private. Integrates with provider revocation APIs (push protection at commit time is the killer feature).
- **GitGuardian** — broadest coverage, multi-VCS, good triage workflow. Often deployed alongside GitHub native.
- **TruffleHog** — open-source, used by hunters and defenders. Strong entropy + verifier model.
- **Gitleaks** — open-source, easy CI integration.

See [[secrets-in-code-detection-patterns]] for the threat-side analysis.

## Evaluation criteria

When running a POC, score each tool on:

### Developer experience

- IDE plugin quality (VS Code, JetBrains)
- PR comment quality — is the explanation useful or just a CWE link?
- Auto-fix or suggested-fix availability
- Time from commit to feedback (sub-5-minute is the bar)

### Signal quality

- False positive rate on *your* code, not their benchmarks
- False negative rate against a known-vulnerable test corpus (e.g., a fork of OWASP Benchmark or your own past incidents)
- Severity calibration — do "criticals" actually warrant blocking?

### Coverage

- Languages and framework versions you actually use
- Monorepo support
- Container image scanning (often bundled now)
- API security (DAST against OpenAPI specs is now table stakes)

### Operational fit

- CI integration (GitHub Actions, GitLab, Jenkins, Buildkite)
- SBOM generation for [[building-a-pci-dss-program-practitioner]] and SOC2/SLSA needs
- SSO, RBAC, audit log for the platform itself
- API for pulling findings into your own dashboard
- Air-gapped deployment if you need it

### Triage workflow

- Bulk suppression with reasons
- Findings de-duplication across branches and runs
- Per-team views and ownership routing
- Integration with Jira / Linear

## Open source vs commercial

Honest tradeoffs:

| Dimension | OSS (Semgrep CE, ZAP, Trivy, TruffleHog) | Commercial |
|---|---|---|
| Up-front cost | Free | $30k–$500k+/yr |
| Rule quality | DIY or community | Curated, maintained |
| Triage UI | Build your own | Included |
| Support | GitHub issues | SLAs, CSMs |
| Custom rules | Easy (Semgrep) to hard (CodeQL) | Often locked or pro-tier |
| Time-to-value | Weeks of internal eng work | Days to weeks |

Hybrid model that works: Semgrep CE + TruffleHog + Trivy + Dependabot covers ~70% of needs for a small org. Add Burp Enterprise + a paid SCA tier when you cross ~50 engineers or hit a compliance forcing function.

## Realistic timeline

A real rollout (not the demo):

- **Month 0–1:** Vendor shortlist, POCs on 2–3 representative repos. Run each tool, count true vs false positives manually on a known sample.
- **Month 2:** Contract negotiation, procurement, security review of the vendor itself.
- **Month 3–4:** Pilot in CI for 1–2 teams. Tune rules. Expect 50–80% suppression rate initially.
- **Month 5–6:** Roll to all repos in warn-only mode. Build dashboards.
- **Month 6–9:** Flip blocking on for critical findings only. Build [[appsec-champions-program]] to handle triage volume.
- **Month 9–12:** Realistic noise level. Re-evaluate vendor if devs are still complaining.

Anyone promising "wall-to-wall coverage in 30 days" is selling.

## Pricing models

- **Per developer / per committer** — most common (Snyk, GitHub Advanced Security, Veracode). Scales painfully.
- **Per application / per scan target** — Checkmarx, Burp Enterprise. Better for orgs with few apps and many devs.
- **Per LOC** — legacy, mostly gone.
- **Consumption / runtime hours** — IAST agents sometimes priced this way.

Always negotiate. Published list pricing is rarely what enterprises pay; 30–60% discount on multi-year deals is normal.

## Fit with paved-road platform engineering

The right framing: tools are *components* of a [[paved-road-pattern-platform]], not the product itself. The platform team owns:

- Default-on scanning in golden-path CI templates
- Triage routing to owning teams
- Suppression policy and audit trail
- Metrics rollup to leadership

If devs have to discover, install, and configure the SAST tool themselves, adoption dies. See [[devsecops-platform-engineering]] and [[secure-sdlc-rollout-playbook]].

## Defensive baseline (minimum viable AppSec tooling)

For a small org with limited budget, the floor is:

- Dependabot or equivalent SCA, with auto-merge for patch-level updates
- GitHub Secret Scanning + push protection
- Semgrep CE in CI on default branch + PRs, with a curated ruleset (start with ~30 rules)
- One DAST scan per release for internet-facing apps (ZAP or Burp Pro is fine)

This costs roughly zero dollars and beats 80% of enterprises with shelfware.

## Workflow to study

1. Inventory current tooling: what's deployed, what's actually running in CI, what findings are anyone actually fixing.
2. Pull last 12 months of security bugs (incidents, pentest reports, bug bounty). Categorize: which would SAST have caught? DAST? SCA? Secret scan?
3. Build a vulnerable-app corpus from real past findings, not OWASP Juice Shop.
4. Run 2–3 candidate tools against the corpus. Score precision and recall by hand.
5. Survey 10 developers on current DX pain points.
6. Pilot with 1 friendly team for 4–8 weeks. Measure: PRs blocked, findings fixed, time to fix, devs' qualitative feedback.
7. Decide based on data, not demos.

## Related

- [[sast-dast-ci-integration]]
- [[devsecops-platform-engineering]]
- [[paved-road-pattern-platform]]
- [[appsec-champions-program]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[secrets-in-code-detection-patterns]]
- [[npm-postinstall-and-typosquat-audit]]
- [[python-pypi-supply-chain-audit]]
- [[github-actions-workflow-source-audit]]
- [[appsec-threat-modeling]]

## References

- [OWASP Source Code Analysis Tools](https://owasp.org/www-community/Source_Code_Analysis_Tools)
- [OWASP DAST tool list](https://owasp.org/www-community/Vulnerability_Scanning_Tools)
- [NIST SAMATE — Software Assurance Metrics And Tool Evaluation](https://www.nist.gov/itl/ssd/software-quality-group/samate)
- [Semgrep rule registry](https://semgrep.dev/explore)
- [GitHub CodeQL documentation](https://codeql.github.com/docs/)
- [SLSA supply chain framework](https://slsa.dev/)
