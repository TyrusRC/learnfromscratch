---
title: Whitebox source review (OSWE-shaped)
slug: whitebox-source-review
aliases: [oswe-prep, oswe-path, whitebox-path]
---

> Reading source to produce unauthenticated-to-RCE chains — the OSWE shape.
> Complement to [[code-auditing]] (which is bug-class indexed). This path
> is workflow-indexed: orient, find primitives, chain, exploit.

## Prereqs

- Comfortable in [[code-auditing]] Stage 1 methodology.
- Fluent in at least one server-side language plus one of (Java/.NET/Node).
- Can write Python/Bash scripts; can drive a debugger end-to-end.
- HTTP fluency: methods, headers, content negotiation, redirects, cookies.

## Stage 1 — orient

Goal: stand the target up locally and understand the trust model in a day.

- Read `README`, `CONTRIBUTING`, `docs/architecture.md`.
- Build with `docker-compose up` or framework equivalent; confirm it
  runs.
- Attach a debugger (see [[debugger-driven-source-review]]).
- Map components: API, frontend, workers, DB, cache, queue.
- List dependencies; flag exotic ones — they're often the audit pivot.

## Stage 2 — entry points

Goal: have a table of every route with auth / authz / role columns.

- Frameworks each have a route printer (`rails routes`,
  `php artisan route:list`, `npx express-list-endpoints`, Spring actuator
  `/mappings`).
- Tag each: unauth / authed / admin; mass-assignable? Resource-bound?
- Prioritise unauthenticated > authenticated > admin during primitive
  hunt.

## Stage 3 — primitives

Goal: find the bug shapes that compose into chains.

- [[auth-bypass-from-source-review]] — the seven shapes.
- [[source-sink-flow-analysis]] — sink-driven taint.
- [[ssrf-source-sink-flow]] — same shape, SSRF.
- Per stack:
  - PHP: [[php-code-auditing]] · [[php-magic-methods]] ·
    [[php-deserialization-gadgets]] · [[laravel-audit-patterns]].
  - Java: [[java-code-auditing]] · [[java-deserialization-audit]] ·
    [[expression-injection]] · [[spring-boot-audit-patterns]].
  - .NET: [[dotnet-code-auditing]] · [[dangerous-aspnet-sinks]] ·
    [[dangerous-dotnet-sinks-extra]] · [[viewstate-attacks]].
  - Node: [[nodejs-code-auditing]] · [[dangerous-nodejs-sinks]] ·
    [[nodejs-prototype-pollution-audit]] ·
    [[express-nestjs-audit-patterns]].
  - Python: [[python-code-auditing]] · [[python-dangerous-sinks]] ·
    [[django-audit-patterns]].
  - Ruby: [[ruby-code-auditing]] · [[ruby-deserialization-audit]] ·
    [[rails-audit-patterns]].

## Stage 4 — chain

Goal: compose primitives into a graph from unauth to RCE.

- [[whitebox-to-exploit-methodology]] — the meta-discipline.
- [[second-order-injection-chains]] — storage → read pairs.
- Typical paths:
  - unauth → user: auth bypass, weak token, registration auto-elevation.
  - user → admin: mass-assignment of role, IDOR, ACL parser differential.
  - admin → RCE: template compile, plugin load, debug exec, deserialise
    config.

## Stage 5 — confirm and exploit

Goal: a single script that walks the chain from blank to callback.

- [[blind-vuln-confirmation-from-source]] — lift blackbox signals.
- [[debugger-driven-source-review]] — set breakpoints on each step.
- Script discipline: self-contained, idempotent, configurable, verbose.
- Verify on a fresh-build instance, then on staging.

## Stage 6 — practice targets

- OSWE labs (offsec.com) — the formal curriculum.
- HackTheBox "Offensive" track + retired Boxes with public source.
- Real OSS apps with CVE history — clone the pre-patch commit, audit
  blind, compare to the disclosed CVE.
- Bug-bounty programs with source-on-GitHub scope (rare but valuable).
- Internal codebases at $job — the highest signal-to-effort ratio.

## Skill bar — when you're done

- Given an unknown app source tree, you can produce a route + auth map
  in a working day.
- You routinely find chains, not single bugs.
- Your exploit scripts run end-to-end on the first manual run, without
  babysitting.
- You can explain why a bug exists, what the developer was thinking,
  and the minimal fix — not just "this is broken."

## References

- [Offensive Security — AWAE / OSWE](https://www.offsec.com/courses/web-300/)
- *The Art of Software Security Assessment* — Dowd, McDonald, Schuh.
- [Doyensec blog](https://blog.doyensec.com/) — audit writeups.
- [Trail of Bits research](https://blog.trailofbits.com/) — chain
  case studies.
- [GitHub Security Lab CodeQL writeups](https://securitylab.github.com/research/).
