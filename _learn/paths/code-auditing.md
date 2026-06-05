---
title: Code auditing (source review)
slug: code-auditing
aliases: [source-code-review, audit-path]
---

> Reading source for security bugs — the discipline behind every
> serious bug-bounty finding in a target with public code, and how
> security teams actually triage internal repos.

## Prereqs

- Read fluently in at least one server-side language (PHP, Java,
  Python, Ruby, Go, or Node).
- Comfort with grep, ripgrep, and a Language Server-aware editor.
- One scripting language for tooling.

## Stage 1 — methodology

Goal: move from "scrolling files" to a repeatable sink-driven workflow.

- [[source-sink-flow-analysis]] — pick a dangerous sink, trace inputs
  backwards.
- [[ssrf-source-sink-flow]] — same shape for SSRF.
- Repo orientation — entry points, routes, framework conventions,
  middleware order.
- Threat-model first: what does this app do, what would matter if it
  failed.
- [[whitebox-to-exploit-methodology]] — chaining primitives, not
  cataloguing single bugs.
- [[debugger-driven-source-review]] — run the code, don't just read it.

## Stage 2 — PHP

PHP remains heavily represented in real-world bug-bounty scope
(WordPress plugins, Laravel apps, legacy CMS forks).

- [[php-code-auditing]] — dangerous sinks: eval, system /
  proc_open, include / require, unserialize, preg_replace with /e on
  ancient code, extract on user input.
- [[php-magic-methods]] — __wakeup / __destruct / __toString /
  __call as gadget entry points.
- [[php-deserialization-gadgets]] — Composer-package gadget hunting,
  POP chains.
- Framework lens — [[laravel-audit-patterns]].
- Practice: [PHPGGC](https://github.com/ambionics/phpggc)
  pre-built chains.

## Stage 3 — Java

Java is the dominant enterprise stack and most rewarding audit target.

- [[java-code-auditing]] — Servlet / filter chain, Spring MVC
  controller surface, MyBatis / JPA query patterns.
- [[java-deserialization-audit]] — any sink reaching
  `ObjectInputStream.readObject` on attacker data; ysoserial chains
  apply per-library.
- [[expression-injection]] — SpEL / OGNL / EL injection.
- Framework lens — [[spring-boot-audit-patterns]].
- Decompile tooling: CFR, Procyon, jadx, Recaf.

## Stage 3.5 — .NET / ASP.NET

Big enterprise + bug-bounty footprint; .NET Core is the modern target.

- [[dotnet-code-auditing]] — controllers, model binding, DI.
- [[dangerous-aspnet-sinks]] — Framework-era sinks.
- [[dangerous-dotnet-sinks-extra]] — Core-era sinks (Minimal APIs,
  System.Text.Json polymorphism, Blazor).
- [[viewstate-attacks]] for the Framework legacy.

## Stage 4 — modern dynamic stacks

- [[nodejs-code-auditing]] · [[dangerous-nodejs-sinks]] ·
  [[nodejs-prototype-pollution-audit]] ·
  [[express-nestjs-audit-patterns]].
- [[python-code-auditing]] · [[python-dangerous-sinks]] ·
  [[django-audit-patterns]].
- [[ruby-code-auditing]] · [[ruby-deserialization-audit]] ·
  [[rails-audit-patterns]].
- [[go-code-auditing]] · [[dangerous-go-sinks]].
- [[rust-code-auditing]] — `unsafe`, FFI, supply chain.

## Stage 5 — chaining

- [[auth-bypass-from-source-review]] — the seven shapes.
- [[second-order-injection-chains]] — storage → read pairs.
- [[blind-vuln-confirmation-from-source]] — close blackbox signals.
- Templating sinks across stacks (Jinja, Twig, Velocity, ERB) →
  [[ssti]].
- ORM raw-query escape hatches → [[sql-injection]] sink survey.
- Reflection / dynamic dispatch as deserialisation-equivalent surface.
- File-handling chokepoints → [[file-upload]],
  [[path-traversal]], [[xxe]].

## Stage 6 — supply chain + provenance

- [[npm-postinstall-and-typosquat-audit]] ·
  [[python-pypi-supply-chain-audit]] ·
  [[go-module-substitution-audit]].
- [[secrets-in-code-detection-patterns]].
- [[ghost-commit-smuggling]] — when the diff lies about itself.

## Stage 7 — automation

- [Semgrep](https://semgrep.dev/) for pattern-based grep++
  rules.
- [CodeQL](https://codeql.github.com/) for query-based variant
  analysis.
- [Joern](https://joern.io/) for cross-language CPG queries.

## Where this earns money / impact

- Bug-bounty programs with source-code-on-GitHub scope.
- Audit firms (Trail of Bits, NCC, Doyensec, Synacktiv) hire on
  source-review skill.
- Security-engineering teams use this exact loop on internal
  pull-requests.

## References

- *The Art of Software Security Assessment* — Dowd, McDonald,
  Schuh. The reference text.
- *Handbook for CTFers* (Nu1L Team, Springer) — chapters on PHP and
  Java code auditing informed this path's structure.
- [PortSwigger Research on Java
  bugs](https://portswigger.net/research) — chained-sink writeups.
- [Doyensec blog](https://blog.doyensec.com/).
