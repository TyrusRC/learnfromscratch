---
title: Threat modelling — STRIDE deep dive
slug: threat-modelling-stride-deep
aliases: [stride-deep, stride-threat-modelling-practitioner]
---

> **TL;DR:** STRIDE is a category-based threat elicitation framework (Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation of Privilege) that works best when applied per-interaction across a tightly-scoped data-flow diagram (DFD). It is a tool, not a programme — pair it with [[appsec-threat-modeling]] for the broader process, [[threat-modelling-pasta]] for risk-driven flavour, [[threat-modelling-linddun-privacy]] for privacy gaps STRIDE misses, and feed findings into [[appsec-maturity-checklist]] tracking. The most common failure mode is not the framework — it is boil-the-ocean DFDs and no follow-up tracking.

## Why it matters

STRIDE has been around since the late 1990s (Loren Kohnfelder and Praerit Garg at Microsoft) and remains the default vocabulary most appsec teams reach for. Why it still earns its place:

- Junior engineers can learn the six categories in an afternoon — unlike attack trees or PASTA, which need facilitation skill.
- It maps cleanly to defensive controls: each STRIDE category has a near-symmetric mitigation family (authn for spoofing, integrity controls for tampering, logging for repudiation, encryption / minimisation for disclosure, rate-limiting + capacity for DoS, least privilege for EoP).
- It produces output that a sprint team can act on — individual threats become Jira tickets.

But STRIDE is not a silver bullet. It under-covers privacy harms ([[threat-modelling-linddun-privacy]] fills that gap), business-logic abuse, and supply-chain risk. Practitioners who use it as their only tool tend to ship surface-level threat models.

## Classes and patterns

### The six categories

| Category | Property violated | Typical example |
|---|---|---|
| **S**poofing | Authentication | Attacker logs in as another user via stolen session cookie |
| **T**ampering | Integrity | Modifying a JWT payload, altering DB rows directly |
| **R**epudiation | Non-repudiation | User denies action, no audit trail to disprove |
| **I**nformation Disclosure | Confidentiality | Verbose error leaks stack trace, S3 bucket public |
| **D**enial of Service | Availability | Algorithmic complexity attack, ReDoS, unbounded query |
| **E**levation of Privilege | Authorisation | IDOR, broken access control, JWT alg=none |

### Per-element vs per-interaction

Two flavours exist, and choosing the wrong one wastes time:

- **STRIDE-per-element** (the original): walk each DFD node — process, data store, external entity, data flow — and ask which STRIDE categories apply. Microsoft published a famous matrix showing, e.g., external entities can only be spoofed or repudiated. Faster, easier for beginners, but produces generic threats.
- **STRIDE-per-interaction**: walk each *interaction* (source → destination via a specific flow) and ask STRIDE against the triple. Slower but produces much more concrete, actionable threats because the context (who is talking to whom, over what protocol, crossing which trust boundary) is in the threat itself.

In production, most experienced practitioners default to per-interaction for any flow crossing a trust boundary and per-element for internal-only components. See also Adam Shostack's *Threat Modeling: Designing for Security*, which formalises this trade-off.

### Building a DFD that does not boil the ocean

A useful DFD has:

- **Processes** (circles): code you wrote.
- **External entities** (rectangles): users, third-party APIs, anything you do not control.
- **Data stores** (parallel lines): databases, caches, queues, blob storage.
- **Data flows** (arrows): labelled with protocol + auth method, e.g. `HTTPS + mTLS`, `gRPC + JWT`.
- **Trust boundaries** (dashed lines): the *only* part that really matters. A DFD without trust boundaries is a useless architecture diagram.

Number every element (`1.1 Web frontend`, `1.2 API gateway`, `2.1 Postgres`) so threats can reference them stably: "T-12: Tampering on flow 1.2→2.1 because no integrity check on cached values". Numbering also lets you track which threats have been triaged or fixed.

**Boil-the-ocean trap.** Junior modellers draw the whole system. Stop. Scope to one feature, one new service, or one specific sprint goal. A DFD with more than 15 nodes is almost certainly too big to threat-model in a single workshop. Break it up.

### Prioritisation

After elicitation, you will have 30–100 threats per service. You cannot fix them all. Common prioritisation approaches:

- **DREAD** (legacy Microsoft) — Damage, Reproducibility, Exploitability, Affected users, Discoverability. Scored 1–10, averaged. Subjective, but it works if you calibrate as a team.
- **Bug bar / severity rubric** — map threats to your existing bug severity scale (CVSS-aligned — see [[cvss-scoring-practitioner]]).
- **Risk register** — feed into the org's existing risk register (relevant for [[soc2-vs-iso27001]] / ISO 27005 alignment).

For each threat, decide: **fix**, **accept** (document the residual risk with owner + review date), **transfer** (insurance, contract clause to vendor), or **avoid** (remove the feature). Write the decision down. A threat model with no decisions is just a list.

## Defensive baseline mappings

STRIDE shines because each category has a default mitigation family. Use this as a starting checklist, not the answer:

- **Spoofing** → strong authn (MFA, mTLS, signed assertions), session management, anti-spoofing on email (SPF/DKIM/DMARC for phishing-adjacent flows — see [[aitm-evilginx-modern-phishing]]).
- **Tampering** → input validation, signed payloads (HMAC/JWS), database integrity constraints, WORM storage where appropriate, file integrity monitoring on hosts.
- **Repudiation** → structured audit logging, signed logs, log shipping to a tamper-evident store, correlation IDs end-to-end (feeds [[siem-detection-use-case-catalog]]).
- **Information Disclosure** → encryption at rest and in transit, least-data-by-default APIs, error message hygiene, secret scanning ([[secrets-in-code-detection-patterns]]).
- **Denial of Service** → rate limiting, quotas, circuit breakers, capacity planning, ReDoS-safe regex, query timeouts.
- **Elevation of Privilege** → least privilege, mandatory authz on every endpoint ([[authorization-patterns-rebac-abac]]), separation of duties, no implicit trust between services.

Tie these into your secure SDLC ([[secure-sdlc-rollout-playbook]]) and CI gates ([[sast-dast-ci-integration]]).

## Integration with sprint SDLC

The fantasy: every feature gets a full threat model.
The reality: you have an hour with the engineering team, every two weeks.

Practical patterns that survive contact with a delivery org:

- **One DFD per service, updated per significant feature.** The service-level DFD is the canonical artefact. Features add or change interactions; the modeller updates the DFD diff and runs STRIDE only on changed interactions.
- **Threat-model-as-code.** OWASP Threat Dragon stores models as JSON; pytm and threagile use Python/YAML. Diff in PRs. Treat the DFD like infrastructure.
- **Design review checkpoint.** Embed a "threat model review" gate in the design doc template — engineers fill in the DFD and STRIDE table; appsec reviews async; sync only for ambiguous items.
- **Track threats as tickets with a `threat-model` label.** Without follow-up tracking, the exercise is theatre. Quarterly, review unresolved threats — accepted, fixed, deferred — and report metrics ([[appsec-maturity-checklist]]).
- **Don't model every sprint.** Reserve full sessions for genuinely new architecture or new trust boundaries.

## Tooling

- **OWASP Threat Dragon** — free, open source, browser or Electron. Decent DFD editor, built-in STRIDE prompts. Best for teams just starting out.
- **Microsoft Threat Modeling Tool** — free, Windows-only, the canonical STRIDE tool. Per-element matrix built in. Last meaningful update was years ago — quality varies.
- **IriusRisk** — commercial. Strong on automation, control libraries, compliance mappings. Vendor pitch oversells "automated threat models" — you still need humans to model.
- **threagile** — open source, YAML-defined model, generates threat reports. Loved by engineering-led teams.
- **pytm** — Python DSL by Izar Tarandach. Threats as code.
- **drawio + a spreadsheet** — honestly, what most experienced practitioners actually use. The tool matters less than the discipline.

**Vendor reality check.** "AI threat modelling" tools promise to read your repo and produce a threat model. As of writing, results are uneven — they generate plausible-looking but generic threats and miss business-logic / trust-boundary nuance. Treat output as a first draft, not the finished artefact.

## STRIDE limitations (be honest)

- **Privacy.** STRIDE was designed for security properties; it does not naturally surface privacy harms like linkability, identifiability, or unawareness. Use [[threat-modelling-linddun-privacy]] alongside it for systems handling personal data ([[gdpr-incident-implications]], [[pdpa-singapore]], [[lgpd-brazil]], [[dpdp-india]], [[appi-japan]]).
- **Business logic.** "Buy item for $0 by manipulating the discount field" rarely surfaces from a STRIDE walk — abuse cases / misuse cases work better.
- **Supply chain.** STRIDE misses build-system compromise and dependency risk — see [[case-study-solarwinds-2020]], [[cve-2024-3094-xz-utils-backdoor]], [[npm-postinstall-and-typosquat-audit]], [[github-actions-workflow-source-audit]], [[ci-cd-as-cloud-attack-surface]].
- **Risk-driven framing.** PASTA ([[threat-modelling-pasta]]) starts from business impact; STRIDE starts from technical assets. For high-stakes systems regulated by [[pci-dss-4-implementation]], [[hipaa-security-rule]], [[nis2-implementation]], or DORA, PASTA outputs may map better to risk committees.
- **Cloud / k8s.** Generic STRIDE under-models cloud IAM nuances — supplement with [[cloud-iam-misconfig-patterns]], [[cloud-identity-mental-model]], [[k8s-admission-webhook-abuse]].

## Workflow to study

1. Read Adam Shostack's *Threat Modeling: Designing for Security* — chapters 1–4 cover STRIDE per-element vs per-interaction. The rest covers wider process.
2. Read the Threat Modeling Manifesto (a four-question framing: what are we working on, what can go wrong, what are we doing about it, did we do a good enough job).
3. Pick one of your own small services. Draw the DFD in drawio. Identify trust boundaries first.
4. Run STRIDE-per-interaction on every flow crossing a boundary. Write threats as `T-N: <category> on <interaction> because <reason>; mitigated by <control or "none">`.
5. Triage: fix / accept / transfer / avoid. Open tickets.
6. Repeat next quarter against the updated DFD — track which threats persisted.
7. Compare STRIDE output to a LINDDUN ([[threat-modelling-linddun-privacy]]) and PASTA ([[threat-modelling-pasta]]) pass on the same system. See what each misses.
8. Sit in on (or run) a real workshop. Facilitation skill matters more than framework knowledge — see [[tabletop-exercise-design-and-execution]] for parallels.

## Realistic effort and who succeeds

- A first DFD + STRIDE workshop on a small new service: 2 facilitator hours of prep, 90-minute workshop, 2 hours documenting. Expect 20–40 threats.
- An updated DFD per feature: 15–30 minutes if the artefact is maintained, hours if it has rotted.
- Practitioners who succeed: ones who *write things down* and *track tickets*. The framework choice is secondary.
- Practitioners who fail: ones who run one beautiful workshop and never revisit. Worse than not modelling at all because it creates a false sense of coverage.

Threat modelling is a habit, not an artefact. Pair with [[appsec-threat-modeling]], [[secure-sdlc-rollout-playbook]], and the broader [[appsec-maturity-checklist]] for organisational integration.

## References

- https://shostack.org/resources/threat-modeling — Adam Shostack's reference page (book, papers, training).
- https://www.threatmodelingmanifesto.org/ — Threat Modeling Manifesto (Shostack, Tarandach, et al.).
- https://owasp.org/www-community/Threat_Modeling_Process — OWASP threat modelling process overview.
- https://owasp.org/www-project-threat-dragon/ — OWASP Threat Dragon project.
- https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats — Microsoft Threat Modeling Tool STRIDE reference matrix.
- https://github.com/izar/pytm — pytm: Pythonic framework for threat modelling.

## Related

- [[appsec-threat-modeling]]
- [[threat-modelling-pasta]]
- [[threat-modelling-linddun-privacy]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[authorization-patterns-rebac-abac]]
- [[sast-dast-ci-integration]]
- [[cvss-scoring-practitioner]]
- [[secrets-in-code-detection-patterns]]
- [[siem-detection-use-case-catalog]]
- [[cloud-iam-misconfig-patterns]]
- [[tabletop-exercise-design-and-execution]]
