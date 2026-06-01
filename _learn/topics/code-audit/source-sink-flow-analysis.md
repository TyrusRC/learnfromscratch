---
title: Source-sink flow analysis
slug: source-sink-flow-analysis
---

> **TL;DR:** Pick a dangerous sink (eval, exec, query, deserialize), trace data flow backwards to any user-reachable source, and decide whether the sanitiser in between is sufficient. CodeQL / Semgrep / Joern automate the search.

## What it is
Most code-review bugs are taint-flow bugs: tainted data (source) reaches a dangerous API (sink) without an effective sanitiser. Instead of reading every file, you enumerate sinks of interest, then ask "can untrusted input get here?". This inverts traditional review and scales to millions of LOC.

## Preconditions / where it applies
- Source code (or decompiled bytecode) available — Java JARs, PHP, .NET assemblies, JS bundles
- Known sink list for the language/framework — see [[dangerous-php-sinks]], [[dangerous-java-sinks]], [[dangerous-aspnet-sinks]]
- A definition of "source" for the target — typically HTTP request fields, message queues, file uploads, external API responses

## Technique
1. **Enumerate sinks.** Grep / AST-search the codebase. For PHP `eval|system|exec|passthru|popen|include|require|unserialize|preg_replace.*\/e`. For Java `Runtime.exec|ProcessBuilder|ObjectInputStream.readObject|InitialContext.lookup|ScriptEngine`. For ASP.NET `BinaryFormatter|LosFormatter|XmlSerializer|Process.Start`.
2. **Classify sinks** by impact (RCE > SQLi > SSRF > path traversal) and by trust required (whether arg must be string-controlled or only partially).
3. **Backtrack** each callsite to its parameters. Follow getters, DI containers, framework binders. Stop when you hit a request object (taint confirmed), a hard-coded literal (dead), or a normaliser that fully encodes the value (safe).
4. **Use a query language** for repeatability:

```ql
// CodeQL: PHP eval reachable from $_GET
import php
from EvalExpr e, Variable v
where v.getAnAccess().getEnclosingCallable() = e.getEnclosingCallable()
  and v.getName() = "_GET"
select e, "eval reaches $_GET"
```

```yaml
# Semgrep: Java Runtime.exec with non-literal arg
rules:
- id: java-exec-from-request
  pattern: Runtime.getRuntime().exec($X)
  pattern-not: Runtime.getRuntime().exec("...")
  message: exec sink with non-literal arg
  languages: [java]
  severity: ERROR
```

5. **Confirm reachability** end-to-end — route mapping, auth filter, role gate. A sink is only a bug if a real HTTP path reaches it.
6. **Triage sanitisers.** Identify whether the encoder is correct for the sink context — `htmlspecialchars` does not stop SQLi; `addslashes` does not stop `LIKE` wildcards; `escapeshellarg` does not stop arg injection on Windows.

## Detection and defence
- CI-integrate Semgrep/CodeQL queries — block PRs that introduce new sink+source pairs
- Maintain an internal sink catalogue per stack and keep it current as new framework helpers ship
- Prefer parameterised APIs over string concatenation — kills entire bug classes at the sink
- Tag tainted sources at the framework layer (annotate request DTOs) so static analysis can propagate trust automatically

## References
- [CodeQL — about data flow analysis](https://codeql.github.com/docs/writing-codeql-queries/about-data-flow-analysis/) — official guide
- [Semgrep taint mode](https://semgrep.dev/docs/writing-rules/data-flow/taint-mode/) — sources, sinks, sanitisers
- [Joern Code Property Graph](https://docs.joern.io/code-property-graph/) — alternative flow-analysis engine
- [OWASP Code Review Guide](https://owasp.org/www-project-code-review-guide/) — general methodology
