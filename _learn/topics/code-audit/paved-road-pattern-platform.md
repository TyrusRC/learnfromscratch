---
title: Paved road pattern — security platform
slug: paved-road-pattern-platform
aliases: [paved-road, golden-path-platform, secure-defaults-platform]
---

> **TL;DR:** The "paved road" (a.k.a. golden path) pattern flips the security model: instead of gating every change with review, you make the secure path also the easiest, fastest, best-documented path. Devs can go off-road, but they have to do real work to get there — and they own the risk when they do. This is the structural counterpart to [[devsecops-platform-engineering]] and the human counterpart to [[appsec-champions-program]]; it is how mid-to-large orgs scale security without becoming a bottleneck. See also [[secure-sdlc-rollout-playbook]] and [[appsec-maturity-checklist]] for how it slots into a broader program.

## Why it matters

Traditional AppSec scales linearly: more services → more reviews → more reviewers. By the time you hit a few hundred microservices and a few thousand engineers, central review is dead. You either become a rubber-stamp ("ship it, we'll catch it in pentest") or a bottleneck ("six-week security queue, devs route around you").

The paved road pattern is the answer that actually worked at Netflix, Spotify, Capital One, Monzo, and a long tail of mid-size orgs. The premise:

- Security ships **product** for developers, not policy.
- The default templates / libraries / pipelines bake in the right answers for authn, authz, TLS, logging, secret handling, dependency scanning, SBOM, image signing.
- Anyone is **allowed** to go off-road, but it's measurably more work — they have to wire up their own auth, write their own Dockerfile, justify it to a reviewer, take the on-call pager for the consequences.
- Security's job becomes maintaining the road, not policing the traffic.

It is not a silver bullet, and it is not free. The honest tradeoff: you pay massive up-front platform investment in exchange for security-by-default at scale, plus a permanent maintenance tax on the platform itself.

## Core principle and patterns

### The principle in one line

> Make the secure path the path of least resistance. Everything else is implementation detail.

If a developer has to choose between "use the platform" and "do it themselves," the platform must win on every axis they care about: speed to first deploy, documentation, debuggability, on-call support, observability. If it doesn't, they go off-road and you lose.

### Common paved-road components

- **Vetted base images.** A small set of hardened, regularly-rebuilt base images (distroless or minimal). Devs `FROM` these, get patched CVEs for free, get SBOM and signing for free. See [[k8s-manifest-source-audit]] for what "vetted" actually means.
- **Service templates / scaffolders.** `platform new service my-thing` produces a repo with CI, Dockerfile, k8s manifests, auth middleware, structured logging, metrics, tracing, secret-mount config, and a deploy pipeline already wired. Backstage (Spotify) and Netflix's Newt are public-ish examples.
- **Auth-as-a-platform.** Service-to-service mTLS and identity is automatic (Istio / Linkerd / SPIFFE). User auth uses one library with safe defaults; rolling your own JWT verifier is hard, not easy. See [[authorization-patterns-rebac-abac]].
- **Secret management as the only path.** Env-var secrets don't work in prod because the platform won't inject them — Vault / cloud KMS mounting is the only way to get a database password. This is the highest-leverage paved-road component and worth doing early. Cross-ref [[secrets-in-code-detection-patterns]].
- **Vetted libraries with safer defaults.** Internal HTTP client that does TLS verification and retry-with-jitter by default. ORM wrapper that refuses string concatenation. Crypto library that doesn't expose ECB mode. The standard library is the trap; the internal library is the safe default.
- **CI/CD with security baked in.** SAST, dependency scan, container scan, IaC scan, signing, SBOM — all run automatically on the templated pipeline. Devs see results in their PR. See [[sast-dast-ci-integration]] and [[ci-cd-as-cloud-attack-surface]].
- **Deployment templates.** Helm chart or Kustomize base that includes NetworkPolicy, PodSecurityStandard, resource limits, readiness probes, audit logging.
- **Logging / detection wiring.** Structured logs flow into the SIEM without dev intervention. Detection engineers can write rules against a known schema. See [[siem-detection-use-case-catalog]] and [[detection-engineering-pyramid-of-pain]].

### The off-road escape hatch

You always allow off-road. The question is the friction gradient.

- **Soft friction:** off-road requires a documented exception, an owner, a sunset date.
- **Medium friction:** off-road requires a design review with the platform team and a pager rotation for the off-road component.
- **Hard friction:** off-road requires VP-level sign-off and a board-visible risk acceptance.

Match the friction to the risk class. Off-road choice of logging library? Soft. Off-road choice of authentication implementation? Hard. Off-road choice of "we'll just expose Redis to the internet"? Block at the platform layer.

## Defensive baseline — what to actually build first

If you're starting today, build in this order. Each one earns the next.

1. **Secrets management is the only way to get credentials.** Eliminates the single largest source of incidents (leaked keys in repos / env files / S3 buckets). See [[case-study-snowflake-2024]] for what happens when you don't.
2. **One golden CI pipeline template.** Even if it just runs lint + dep scan + container build + sign, it gives you a single chokepoint for future controls.
3. **Vetted base images, automatically rebuilt.** Eliminates the "we shipped Log4Shell because nobody rebuilt their image in eight months" failure mode.
4. **Service scaffolder.** Devs love this; security gets to set defaults for free. Spotify's Backstage is the public reference.
5. **mTLS / service identity.** Removes "is this internal traffic safe?" as a debate. Cross-ref [[cloud-identity-mental-model]].
6. **Structured logging into central SIEM, automatic.** Detection team gets a known schema; devs don't have to think about it. Cross-ref [[soc-runbook-design]].
7. **PR-time security feedback, not blocking.** Devs see findings, fix them, learn. Blocking comes after adoption is high enough that blocking doesn't trigger revolt.

What to **not** do early: write a 40-page policy document, run a "security review board," buy a vendor "platform" that nobody on your team understands.

## Workflow to study

A realistic adoption arc, roughly 18–36 months for a 500–2000-engineer org:

### Quarter 1–2: legitimacy and quick wins

- Hire or designate 2–3 platform-minded security engineers (people who can write Go / Python / Terraform, not just review).
- Pick ONE high-pain quick win — usually secret management or base images.
- Ship it as a real product: docs, Slack support channel, on-call, "office hours."
- Measure adoption weekly. Aim for one flagship team that loves it.

### Quarter 3–4: scaffolding and templates

- Build the service scaffolder. Steal Backstage if you can.
- Wire CI templates with safe defaults but warning-only.
- Publish the "golden path" docs. Make it the answer to "how do I start a new service?"

### Year 2: enforce by attrition

- New services must use the road. Old services migrate opportunistically (during refactors, framework upgrades).
- Off-road requires exception. Track exceptions in a real system; review quarterly.
- Start moving warnings to blocks on the highest-confidence checks (secrets in code, known-bad container images, missing signature on prod deploy).

### Year 3 and beyond: continuous maintenance

- Refresh base images monthly.
- Track adoption metrics; the paved road is a product with a roadmap.
- Sunset legacy templates. Migrate off-road services that have become legacy.

### Measuring adoption

The metrics that actually matter:

- **% of services on current golden-path template** (not "template ever," current).
- **Median time from `git init` to prod deploy** for a new service on the road vs off it.
- **Exception count, exception age, exception owner identified yes/no.**
- **Mean time to patch a critical CVE across the fleet** (this is the killer metric — if it's hours-to-days, the road is real; if it's months, the road is theater).
- **Dev NPS for the platform.** Yes, really. If devs hate the road they will route around it and you will have built shelfware.

## Enforce vs nudge — when to do which

Practitioner reality:

- **Nudge** when you don't yet have the political capital, when adoption is low, or when the control has a meaningful false-positive rate. Warnings, PR comments, dashboards.
- **Enforce** when the control is high-confidence, adoption is already majority, and the failure mode is severe. Block secret commits at pre-receive. Block unsigned prod deploys at the admission webhook. Block known-vulnerable base images at the registry.
- **Never enforce** something the platform itself can't satisfy. The classic failure: AppSec demands "no critical CVEs in production," the base image has a critical CVE, deploys block, devs lose three days, AppSec loses all credibility.

Compare with [[secure-sdlc-rollout-playbook]] for the broader policy/standards layer this sits inside.

## Comparison to traditional gating

| Dimension | Traditional security review | Paved road |
|---|---|---|
| Coverage | What gets submitted for review | Everything on the platform, automatically |
| Scaling | Linear with engineers | Sub-linear; platform investment is fixed-ish |
| Dev relationship | Adversarial / queue-based | Product / customer-based |
| Failure mode | Bottleneck, rubber-stamp, route-around | Stale road, platform team becomes new bottleneck |
| Time-to-secure | Per-service, per-change | Up-front, then automatic |
| What you measure | Reviews completed | Adoption, MTTP, exception count |

Traditional review never disappears entirely — high-risk changes (new auth flows, payment surfaces, custom crypto) still need human review. The paved road just shrinks that surface from "everything" to "the genuinely novel."

## Published examples

- **Netflix:** Paved road is a Netflix-coined term. Public talks describe Spinnaker (deploy), Lemur (cert mgmt), BLESS (SSH cert auth), Repokid (least-privilege IAM) as paved-road components. See Netflix Tech Blog.
- **Spotify:** Backstage developer portal, plus internal "golden path" docs. Backstage is open-source and adopted broadly.
- **Capital One:** Cloud Custodian (policy-as-code) plus internal templates. Their "Hygieia" and platform-engineering posts are public.
- **Monzo / Intercom / similar mid-size:** Public engineering blogs describing service templates, mTLS-everywhere, central logging defaults.

The vendor-marketing version of this — "buy our platform and you'll have a paved road" — is mostly false. The road is org-specific by definition; vendors sell paving stones, not roads.

## Common failure modes (be honest)

- **The road is worse UX than off-road.** Devs ignore it. This is the single most common failure. Fix it by treating the road as a product, with PMs, dev advocates, real docs.
- **No maintenance budget.** Year 2, the templates are stale, the base images are unpatched, the auth library lags upstream by 18 months. Off-road becomes safer than on-road. Brutal.
- **Security team becomes the platform team.** They stop doing security and start doing SRE-for-security. Useful, but you've just lost your AppSec function. Split the roles explicitly.
- **One-size-fits-all road.** ML workloads, batch jobs, mobile backends, and edge functions all need different paved roads. Pretending one template covers all of them produces a template nobody uses.
- **Enforcement before adoption.** Blocking deploys when only 20% of services are on the road creates a revolt. Get to 70%+ adoption before enforcing.
- **Paved road that's actually a paved cul-de-sac.** Locks devs into deprecated frameworks, can't keep up with new languages, blocks legitimate architectural evolution. The road has to move.
- **No measurement.** "We built a paved road" without adoption numbers is faith-based security. The metric stack above is non-negotiable.
- **Confusing paved road with mandatory road.** If everything is mandated, you're just a slow gate with a friendlier name.

Who succeeds: orgs with strong platform/SRE culture, with security leadership that can hire engineers (not just reviewers), with executive air cover for an 18–36 month investment before the payoff is obvious. Who fails: orgs treating paved road as a slide deck, orgs without platform engineering, orgs where security reports to legal/compliance and can't ship code.

## References

- [https://netflixtechblog.com/](https://netflixtechblog.com/) — Netflix engineering blog, paved-road origin posts (search "paved road", "Spinnaker", "BLESS", "Repokid").
- [https://backstage.io/](https://backstage.io/) — Spotify's open-source developer portal and golden-path scaffolder.
- [https://www.capitalone.com/tech/cloud/](https://www.capitalone.com/tech/cloud/) — Capital One platform engineering posts; Cloud Custodian project.
- [https://cloudcustodian.io/](https://cloudcustodian.io/) — Policy-as-code engine used in many paved-road deployments.
- [https://martinfowler.com/articles/developer-effectiveness.html](https://martinfowler.com/articles/developer-effectiveness.html) — Fowler on developer effectiveness; the platform-engineering economic argument.
- [https://internaldeveloperplatform.org/](https://internaldeveloperplatform.org/) — Community reference site for internal developer platforms, golden paths, and paved roads.

## Related

- [[devsecops-platform-engineering]]
- [[appsec-champions-program]]
- [[secure-sdlc-rollout-playbook]]
- [[appsec-maturity-checklist]]
- [[sast-dast-ci-integration]]
- [[ci-cd-as-cloud-attack-surface]]
- [[secrets-in-code-detection-patterns]]
- [[k8s-manifest-source-audit]]
- [[terraform-and-iac-source-audit]]
- [[authorization-patterns-rebac-abac]]
- [[cloud-identity-mental-model]]
- [[siem-detection-use-case-catalog]]
- [[detection-engineering-pyramid-of-pain]]
- [[case-study-snowflake-2024]]
- [[case-study-capital-one-2019]]
- [[policy-and-standards-writing]]
