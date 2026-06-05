---
title: PortSwigger Top 10 web hacking techniques — by year retrospective
slug: portswigger-top-10-by-year
aliases: [portswigger-top-10-history, ps-top-10-retrospective]
---

> **TL;DR:** The PortSwigger Top 10 web hacking techniques is the community-curated annual list that anchors the appsec research calendar. Walking it year by year exposes the long arcs — request smuggling, cache poisoning, browser desync, SSRF, race conditions — and turns a decade of innovation into a ready-made curriculum. Pair this retrospective with [[case-study-portswigger-top-10-pattern]] for the meta-pattern and [[case-study-orange-tsai-research-pattern]] for a recurring author whose work dominates several editions.

## Why it matters

The list is not a vulnerability database; it is a research index. Each year a panel of judges and the community vote on the most impactful web research published in the prior calendar year, and the top 10 entries become the de facto canon. For practitioners this matters for three reasons:

- It compresses thousands of blog posts, conference talks and disclosed reports into a curated reading list with stable, durable links.
- It surfaces classes that are about to land in scope for bug-bounty programs and pentests, often a year before they appear in mainstream training.
- It encodes a methodology: read, reproduce, generalise, find a variant. That loop is the same one used in [[case-study-portswigger-top-10-pattern]] and is the foundation of [[ctf-to-bug-bounty-transition]].

If you are budgeting study time, the Top 10 gives you the best signal-to-noise ratio of any single appsec resource, comparable to [[keeping-up-with-research-feeds]] for daily reading and [[testing-methodology-checklists]] for execution.

## Voting methodology in brief

The process has remained roughly stable since 2016. PortSwigger collects nominations throughout the year via a public form and Twitter, then runs a two-stage vote: a community vote produces a shortlist (usually around 15 entries), and a panel of well-known researchers ranks the final Top 10. The panel composition rotates but consistently includes practitioners who themselves appear on the list — James Kettle, Nicolas Grégoire, Soroush Dalili, Filedescriptor, Orange Tsai and others. The result is a list with strong technical taste and a bias toward novel primitives over high-severity but well-trodden bugs.

## Year-by-year arc

### 2016 — the modern era opens

The inaugural list set the tone: web cache deception (Omer Gil), HTTPoxy, relative path overwrite, and SSRF variants dominated. The signal was clear — protocol-level and infrastructure-level bugs were back. See [[cache-deception]] and [[ssrf]] for the still-current playbooks.

### 2017 — desync becomes a theme

Server-side request forgery research matured (Orange Tsai's "A new era of SSRF"), DNS rebinding returned, and Mathias Karlsson's "Bypassing CSP using polyglot JPEGs" introduced the polyglot class. The big shift: researchers stopped thinking of HTTP as a single protocol and started exploiting the seams between parsers.

### 2018 — practical attacks on real infrastructure

James Kettle's "Practical Web Cache Poisoning" landed at #1 and reshaped how people thought about CDNs. Same-Origin Method Execution, prototype pollution (Olivier Arteau), and the first Edge Side Includes (ESI) injection work also appeared. Cache poisoning has remained a fixture ever since — track it through [[cache-poisoning]] and [[cache-poisoning-modern-chains]].

### 2019 — request smuggling reborn

Kettle's "HTTP Desync Attacks" reintroduced request smuggling as a mainstream technique, taking #1. DOMPurify bypasses, the SSO research from Sam Curry's circle, and several deserialisation gadget chains rounded out the list. This is the year [[http-request-smuggling]] became a must-know primitive. CL.TE and TE.CL became vocabulary.

### 2020 — protocol-level creativity

Web Cache Entanglement (Kettle), NAT Slipstreaming (Samy Kamkar), and Portable Data exFiltration (Michał Bentkowski) led the year. H2.TE and other HTTP/2 desync variants started to appear. The throughline: protocol downgrades and parser disagreements at every layer. See [[http-smuggling-modern-variants]].

### 2021 — HTTP/2 and dependency confusion

Kettle's "HTTP/2: The Sequel is Always Worse" took #1, demonstrating that the new protocol opened a fresh smuggling surface. Alex Birsan's dependency confusion research, Sam Curry's Apple research, and several prototype pollution gadget catalogues also placed. The year cemented HTTP/2 as a primary research target.

### 2022 — browser-powered desync and SSO

Kettle returned with "Browser-Powered Desync Attacks" — desync from inside the victim's browser. Account hijacking via SAML response confusion (Felix Wilhelm) and the Spring4Shell analysis also placed. Browser desync expanded the attacker model and is now part of any serious smuggling assessment.

### 2023 — SSO, OAuth, race conditions

Kettle's "Smashing the State Machine" reframed race conditions as a primitive on par with smuggling, using single-packet attacks to compress timing windows to microseconds. Frans Rosén's postMessage research, EllipticCurve cryptography flaws, and several SSO chains placed. Race conditions moved from "edge case" to "first-class bug class".

### 2024 — SMTP smuggling and parser confusion

SEC Consult's SMTP smuggling research (Timo Longin) landed near the top, the GitLab pipeline-confusion work appeared, and several path-traversal gadget chains in modern frameworks placed. The lesson: parser disagreements are not limited to HTTP. See [[smtp-injection]].

### 2025 — confidentiality, AI surface, and continued desync

The 2025 list (covering 2024 research) continued the desync arc with new HTTP/3 angles, surfaced prompt-injection-style attacks on agentic systems, and elevated a handful of cloud-edge confusion bugs. Track related notes in [[cloudflare-workers-audit]], [[vercel-edge-and-middleware-audit]] and [[ai-agent-sandbox-design]].

## Recurring patterns

A few classes have appeared, in some form, in nearly every edition since 2018:

- **Request smuggling** — CL.TE, TE.CL, H2.CL, browser-powered, client-side. Tracked in [[http-request-smuggling]] and [[http-smuggling-modern-variants]].
- **Cache poisoning and deception** — unkeyed inputs, ESI, parameter cloaking, DOM-side caches. See [[cache-poisoning]], [[cache-poisoning-modern-chains]], [[cache-deception]].
- **SSRF and gopher-style protocol smuggling** — see [[ssrf]] and [[host-header-injection]].
- **Race conditions** — multi-step state machines, limit-overrun, TOCTOU on auth.
- **Prototype pollution** — gadget chains in Node and browser libraries.
- **Parser disagreement** — between proxies, between client and server, between two libraries in the same app.

The meta-pattern: find a primitive where two components disagree about the meaning of bytes, then build an oracle and weaponise it. This is the same shape covered in [[case-study-orange-tsai-research-pattern]] and the [[one-day-from-patch-diff]] workflow.

## Defensive baseline takeaways

For defenders, the list is a forward-looking detection backlog:

- Maintain a single source of truth for HTTP parsing — terminate TLS, normalise, then forward. Mismatched proxies are the source of most smuggling bugs.
- Key every cacheable response on every input that influences it; assume unkeyed headers will be discovered.
- Treat any state-machine endpoint (signup, password reset, checkout, voucher redemption) as race-vulnerable until proven otherwise.
- Build detection content from the Top 10 each year — the [[edr-rules-as-code-from-attack-patterns]] approach maps cleanly here.
- Feed disclosed Top 10 entries into [[detection-engineering-pyramid-of-pain]] and your [[purple-team-feedback-loop]].

## Workflow to study the list

A repeatable approach that scales to a year of evenings:

1. **Inventory.** Pull the full list (PortSwigger publishes a single index page each year) and create a tracker with columns: year, rank, author, primitive class, target tech, lab availability.
2. **Reproduce labs first.** Web Security Academy mirrors many entries as free labs. Always reproduce before reading deeper writeups.
3. **Read the primary source.** The original blog post or paper, not a summary. Note vocabulary and diagrams.
4. **Build a minimal PoC.** Even a curl one-liner counts. The goal is muscle memory; see [[reading-public-pocs-effectively]].
5. **Find a variant.** Pick one assumption in the original and break it. Different proxy, different framework, different content-type. This is where new research begins.
6. **Document.** Write a short note per entry — title, primitive, oracle, minimal repro, generalisation idea. Pattern matches [[h1-disclosed-report-reading-method]] and [[report-writing-step-by-step]].
7. **Rotate years.** Two weeks per year, oldest to newest. You will see the same primitives mutate across editions.

For bug-bounty hunters, pair each year's reading with a session on [[expanding-attack-surface]] and [[getting-feel-for-target]] so the techniques land on real programs rather than staying theoretical.

## Using the list as a curriculum

A practical 12-week plan:

- **Weeks 1-2:** 2016-2017 — cache deception, SSRF basics, CSP polyglots.
- **Weeks 3-4:** 2018-2019 — practical cache poisoning, HTTP desync v1.
- **Weeks 5-6:** 2020-2021 — H2 desync, dependency confusion, NAT slipstream.
- **Weeks 7-8:** 2022 — browser-powered desync, SSO confusion.
- **Weeks 9-10:** 2023 — race conditions, postMessage, single-packet attacks.
- **Weeks 11-12:** 2024-2025 — SMTP smuggling, pipeline confusion, agentic-AI surface.

Each two-week block should produce three artefacts: a reproduced lab, a written note, and one novel variant attempt. That cadence is consistent with [[building-a-research-home-lab]] and avoids the burnout patterns flagged in [[burnout-and-pipeline]].

## Common misuses of the list

- **Treating it as a vuln list.** It is a research index. Many entries are primitives without an immediate target. Translate them.
- **Reading only the top 3.** The #8 entry of a given year often becomes the #1 primitive two years later.
- **Skipping reproduction.** Reading without building leaves you with vocabulary but no instincts.
- **Ignoring older years.** 2016-2018 entries are still under-exploited on most targets, especially mid-size SaaS that has never been audited for cache deception or RPO.

## Related

- [[case-study-portswigger-top-10-pattern]]
- [[case-study-orange-tsai-research-pattern]]
- [[case-study-h1-top-disclosed-2024-2025]]
- [[case-study-google-vrp-writeup-patterns]]
- [[http-request-smuggling]]
- [[http-smuggling-modern-variants]]
- [[cache-poisoning]]
- [[cache-poisoning-modern-chains]]
- [[cache-deception]]
- [[ssrf]]
- [[host-header-injection]]
- [[smtp-injection]]
- [[reading-public-pocs-effectively]]
- [[h1-disclosed-report-reading-method]]
- [[keeping-up-with-research-feeds]]
- [[testing-methodology-checklists]]
- [[building-a-research-home-lab]]
- [[ctf-to-bug-bounty-transition]]
- [[expanding-attack-surface]]
- [[one-day-from-patch-diff]]

## References

- PortSwigger, Top 10 web hacking techniques (annual index): https://portswigger.net/research/top-10-web-hacking-techniques-of-2024
- James Kettle, HTTP Desync Attacks (2019): https://portswigger.net/research/http-desync-attacks-request-smuggling-reborn
- James Kettle, Practical Web Cache Poisoning (2018): https://portswigger.net/research/practical-web-cache-poisoning
- James Kettle, Smashing the State Machine (2023): https://portswigger.net/research/smashing-the-state-machine
- Orange Tsai, A new era of SSRF (2017): https://blog.orange.tw/2017/07/how-i-chained-4-vulnerabilities-on.html
- PortSwigger Web Security Academy labs index: https://portswigger.net/web-security/all-labs
