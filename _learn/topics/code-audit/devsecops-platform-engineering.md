---
title: DevSecOps platform engineering
slug: devsecops-platform-engineering
aliases: [devsecops-platform, security-platform-team]
---

> **TL;DR:** A DevSecOps platform team builds the paved road so secure-by-default is the easiest path for developers, not a gate they have to argue with. It pairs security engineers with platform / developer-experience engineers to ship CI templates, vetted base images, integrated SAST/SCA/DAST, secret and IaC scanning, and golden-path frameworks. Companion notes: [[paved-road-pattern-platform]], [[appsec-champions-program]], [[sast-dast-iast-vendor-selection]], [[secure-sdlc-rollout-playbook]], [[sast-dast-ci-integration]].

## Why it matters

Traditional AppSec teams operate as reviewers and gatekeepers. They write standards, run scanners, file tickets, and chase developers. At scale (more than ~50 engineers per security person) this collapses: the backlog grows, devs route around security, and "shift left" becomes a slogan rather than a workflow.

A DevSecOps **platform** team flips the model. The mission is not to review every change — it is to ship reusable, opinionated infrastructure so that doing the right thing is the default. Developers get a paved road; security gets coverage by construction instead of inspection. Related: [[appsec-maturity-checklist]], [[secure-sdlc-rollout-playbook]].

This note is honest about what works and what does not, what teams to actually staff, and why most "DevSecOps transformations" stall.

## Team mission

> Build paved-road security into the developer workflow so that secure choices are the default, fast, and well-documented.

Concrete restatement for leadership:

- We do **not** review every pull request.
- We do **not** own developer workflows — we provide tools developers choose to adopt.
- We **do** own: CI templates, base images, scanning integrations, secret detection, IaC guardrails, golden-path scaffolds, and the docs that explain them.
- Success is measured by **adoption** and **time-to-fix**, not by tickets filed.

If your leadership cannot articulate the mission this way, the team will drift back into a gate-keeping AppSec function within a year.

## Composition

A working platform pod is roughly 3-5 people:

### Security engineer(s)
Background in AppSec, threat modeling ([[appsec-threat-modeling]]), or pentest ([[pentest-engagement-execution]]). Owns "what does secure mean here?" — tuning scanners, writing detection rules, threat-modeling the platform itself.

### Platform / SRE engineer(s)
Owns the pipelines, registries, Kubernetes, Terraform modules. Has shipped production infrastructure and understands developer pain. Without this person, "security templates" are theoretical and break in real builds.

### Developer-experience engineer
Often the most undervalued. Writes the docs, runs office hours, builds the CLI, sits in #help-platform. If developers cannot adopt the paved road in 30 minutes without filing a ticket, the team has failed.

### Optional: product manager
At larger orgs (200+ engineers), a PM for the platform pays for itself. Backlog grooming, roadmap, stakeholder management.

Anti-pattern: a team of five security engineers and zero platform engineers. They will produce policy and scanner findings, not a platform.

## Key services to ship

### Secure-by-default CI templates
Reusable workflow templates (GitHub Actions composite actions, GitLab CI includes, Jenkins shared libraries). New repos inherit SAST, SCA, secret scanning, container scanning, and signed builds without devs writing YAML. See [[github-actions-workflow-source-audit]] and [[sast-dast-ci-integration]].

### Vetted base container images
A small set of hardened, regularly patched base images (distroless, Chainguard-style, or internal builds). Devs build FROM these. Ban arbitrary `FROM ubuntu:latest`. Image registry enforces admission. See [[container-runtime-escapes-modern]] and [[k8s-admission-webhook-abuse]].

### Integrated scanning
- **SAST** running on PR with developer-friendly output (inline comments, not a 400-page PDF).
- **SCA** (dependency scanning) with autoremediation PRs where possible (Renovate, Dependabot tuned by the team).
- **DAST** for staged services, opt-in but easy to enable.
- **Secret scanning** pre-commit and in CI ([[secrets-in-code-detection-patterns]]).
- **IaC scanning** for Terraform / K8s manifests ([[terraform-and-iac-source-audit]], [[k8s-manifest-source-audit]]).

Vendor selection guidance: [[sast-dast-iast-vendor-selection]].

### Golden-path framework / scaffold
A `create-service` CLI that scaffolds a new microservice with auth, logging, telemetry, secrets handling, and CI wired in. Devs that use the scaffold inherit ~80% of the AppSec controls for free.

### Internal documentation
A real docs site, not a Confluence graveyard. Searchable, with runnable examples, owned by the DX engineer. Includes: "how do I rotate a secret", "how do I add a new dependency", "what does this scanner finding mean".

### Supply chain controls
Signed builds (cosign / sigstore), SBOM generation, provenance attestation. Tie into [[ci-cd-as-cloud-attack-surface]].

## Staffing model — a rough rule of thumb

There is no clean ratio, but practitioner heuristics:

- **1 platform engineer per ~50-100 developers** for the platform side.
- **1 security engineer per ~150-300 developers** when paved road is mature.
- A **3-person pod** can support a 200-engineer org if the org has a single language ecosystem and is greenfield-ish.
- Multi-language, multi-cloud, regulated orgs need 5-8 people minimum and several years of work.

Beware vendor pitches claiming one tool replaces the team. The tool is 20% of the work; integration, tuning, and developer enablement are the other 80%.

Augment with [[appsec-champions-program]] — embedded developers who carry security context back to their teams.

## Measurement

What to measure (and report monthly):

### Adoption rate
- % of repos using the paved-road CI template
- % of services built from vetted base images
- % of new services scaffolded via the golden-path CLI

Adoption is the leading indicator. If it stalls, nothing else matters.

### Mean-time-to-fix (MTTF)
- For critical CVEs in dependencies (SCA findings)
- For SAST high-severity findings
- For secrets found in commits

Track per-team. Bad MTTF often means the paved road has friction the platform team needs to fix, not a developer discipline problem.

### Coverage
- % of builds that ran each required check
- % of production services with signed images
- % of IaC merged through scanning

### Lagging indicators
- Incidents caused by classes of bug the platform was supposed to prevent.
- Reduction in pentest findings of the same class year over year ([[pentest-debrief-and-followup]]).

What **not** to measure: number of findings closed, number of tickets opened. These reward ticket-shuffling and punish actual fixes.

## Common failure modes

### Top-down mandate without paved road
Exec announces "all code must pass SAST." No template, no tuning, no docs. Developers either turn it off or treat it as red-tape. Mandate then paved road = guaranteed cynicism.

### Security team owns developer workflows
AppSec writes the CI pipeline and tells devs they cannot change it. Devs cannot ship. Tickets pile up. The pipeline rots because no one who owns it actually uses it. Fix: platform team **provides** templates; devs **own** their pipelines.

### "Security == gate" mindset
Every finding is a release blocker. Devs route around. The platform becomes "the team that says no." Fix: differentiate critical findings (block) from informational (annotate). Measure friction. Tune relentlessly.

### Tool-first, not problem-first
Buying a $500k SAST product before knowing what classes of bug to catch. Almost always wastes a year. Start with one threat model ([[appsec-threat-modeling]]), one ecosystem, one paved road, then layer tools.

### No DX investment
Team is all security and infra engineers, no docs, no CLI, no office hours. Adoption stalls below 30%. The fix is hiring a DX engineer, not buying more tools.

### Reporting to CISO with no engineering peer
If the team only reports up through security, engineering leadership treats it as someone else's problem. Best results: dotted line to both CISO and VP Engineering / Platform.

## How this differs from a traditional AppSec team

| Dimension | Traditional AppSec | DevSecOps platform |
|---|---|---|
| Primary output | Reviews, findings, policy | Reusable templates, scanners, scaffolds |
| Posture toward devs | Reviewer / gatekeeper | Service provider / paved road |
| Org placement | Under CISO only | Joint CISO + Engineering |
| Scaling model | Linear (more reviewers) | Sub-linear (platform leverage) |
| KPIs | Findings closed, audits passed | Adoption, MTTF, coverage |
| Failure mode | Bottleneck, ignored | Builds platform no one uses |

Traditional AppSec is not wrong — for regulated, high-touch areas (payments, identity) it still makes sense. But it does not scale past a few hundred engineers without the platform layer underneath.

## Workflow to study

A realistic first-year roadmap for a new platform pod:

1. **Month 1-2:** Inventory. List every repo, every CI system, every language, every base image. Read [[appsec-maturity-checklist]] honestly. Pick one ecosystem to start (often Go or Node).
2. **Month 2-3:** Build CI template v1 — secret scanning + SCA + lint. Ship to 3 friendly teams.
3. **Month 3-6:** Iterate. Add SAST. Build vetted base image. Write docs. Office hours weekly.
4. **Month 6-9:** Golden-path CLI. IaC scanning ([[terraform-and-iac-source-audit]]). Sign builds.
5. **Month 9-12:** Roll to long tail. Start [[appsec-champions-program]]. Measure adoption.
6. **Year 2:** DAST in staging, supply-chain attestation, threat modeling integration, expand to second ecosystem.

Honest expectation: 50% adoption at end of year 1 is good. 80% by end of year 2 is excellent. 100% is a fantasy unless you have hard executive backing and a small org.

## Who succeeds in this role

- Engineers who have shipped both production code **and** done security work.
- People who measure success in "developer adopted my thing" rather than "I found a bug."
- Pragmatists who can say no to a vendor.
- Patient communicators — most of the job is internal evangelism, docs, and office hours.

Who struggles: pure pentesters who view devs as adversaries; pure platform engineers who do not understand threat models; anyone who believes "the tool will solve it."

## Related

- [[paved-road-pattern-platform]]
- [[appsec-champions-program]]
- [[sast-dast-iast-vendor-selection]]
- [[secure-sdlc-rollout-playbook]]
- [[sast-dast-ci-integration]]
- [[appsec-maturity-checklist]]
- [[appsec-threat-modeling]]
- [[secrets-in-code-detection-patterns]]
- [[terraform-and-iac-source-audit]]
- [[k8s-manifest-source-audit]]
- [[github-actions-workflow-source-audit]]
- [[ci-cd-as-cloud-attack-surface]]

## References

- https://martinfowler.com/articles/devsecops.html
- https://cloud.google.com/architecture/devops
- https://slsa.dev/
- https://www.cisa.gov/securebydesign
- https://owasp.org/www-project-devsecops-maturity-model/
- https://github.com/cncf/tag-security
