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
- Repo orientation — entry points, routes, framework conventions,
  middleware order.
- Threat-model first: what does this app do, what would matter if it
  failed.

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
- Decompile tooling: CFR, Procyon, jadx, Recaf.

## Stage 4 — across languages and integrate

- Templating sinks across stacks (Jinja, Twig, Velocity, ERB) →
  [[ssti]].
- ORM raw-query escape hatches → [[sql-injection]] sink survey.
- Reflection / dynamic dispatch as deserialisation-equivalent surface.
- File-handling chokepoints → [[file-upload]],
  [[path-traversal]], [[xxe]].

## Stage 5 — automation

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
