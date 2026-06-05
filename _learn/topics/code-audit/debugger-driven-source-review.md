---
title: Debugger-driven source review
slug: debugger-driven-source-review
aliases: [whitebox-debugger, dynamic-source-audit]
---

{% raw %}

> **TL;DR:** Reading source tells you what *should* happen; running it under a debugger tells you what *does*. The single highest-leverage habit in whitebox work is stepping through suspected vulnerable code with attacker-controlled input. Set breakpoints on sinks, trigger the route, inspect taint flow live. Bugs that look uncertain in source become obvious in the debugger.

## What it is
Senior auditors don't audit code by reading — they audit code by *running*. The debugger is the difference between "this might be exploitable depending on the sanitiser" and "I just watched the unsanitised value reach the sink." This note is the discipline.

## Why it matters
- Framework defaults are often invisible in source. Spring's `MessageConverter`, Rails' parameter coercion, Express's body-parser — each can sanitise, normalise, or reject input before your "vulnerable" code runs. A debugger shows what's actually in the variable.
- Reflection/DI/AOP code paths are not greppable. A `@Aspect` that runs before every method, a `pyenv hook`, a Rails `before_action :sanitize` — invisible in the handler, visible in the call stack.
- Middleware ordering bugs are runtime-only. The debugger shows you what fires in what order.
- Annotation-driven security (`@PreAuthorize`, `@UseGuards`, `before_action`) silently fails when misconfigured. The debugger shows whether the guard ran.

## Setup per stack

### Java / Spring
- IntelliJ remote debug or `mvn spring-boot:run` with `-Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=*:5005`.
- Set conditional breakpoints on sinks: `Runtime.exec`, `ObjectInputStream.readObject`, `EntityManager.createNativeQuery`.
- Use "Evaluate expression" to compute payload variants on the fly.

### .NET
- `dnSpy` for decompiled DLLs (closed-source apps), Visual Studio / Rider for source.
- Attach to `dotnet` or IIS worker; conditional breakpoints on `BinaryFormatter.Deserialize`, `Process.Start`, `SqlCommand` constructor.

### Python
- `pdb`/`ipdb` inline; `debugpy` for remote (`python -m debugpy --listen 5678 --wait-for-client`).
- For Django: `python manage.py runserver` + `import pdb; pdb.set_trace()` at the sink.
- VS Code Python debug attach to running process.

### Ruby / Rails
- `binding.pry` or `debugger` (`debug` gem on Ruby 3.1+) at suspected sink.
- `rails console` to evaluate payload constructions without re-running the request.
- `byebug` for older codebases.

### Node.js
- `node --inspect-brk` + Chrome DevTools `chrome://inspect`, or VS Code "Attach to Node".
- Conditional breakpoint on `child_process.exec`, `eval`, `vm.runInThisContext`.
- For NestJS: `npm run start:debug` is the standard incantation.

### PHP
- Xdebug + VS Code/PhpStorm; set `xdebug.start_with_request=trigger` and `XDEBUG_TRIGGER=1` cookie/header.
- Breakpoints on `eval`, `unserialize`, `include`/`require`, `exec`-family.

### Go
- `dlv debug` (Delve) or `dlv attach`. VS Code Go extension wraps it.
- Conditional breakpoints on `exec.Command`, raw query construction.

## Workflow

1. **Trigger from blackbox first.** Confirm a route reaches code by sending a request and watching logs.
2. **Set sink breakpoints.** All suspected sinks in the route's reachable code.
3. **Set source breakpoints.** Where request data enters (controller method, middleware boundary).
4. **Send the request.** With a "marker" payload that's distinctive (e.g., `SENTINEL_QUOTE_123'`).
5. **Step over middleware.** Note what transforms the input. The marker shows you exactly which transformations apply.
6. **Watch the sink.** Did the marker arrive intact? Partially escaped? Replaced with placeholder?
7. **Iterate payload.** Use "Evaluate expression" or restart with adjusted payload to find the variant that bypasses the transform.

## Use cases beyond exploit dev

### Confirm authorization
- Set breakpoint inside `@PreAuthorize`/`canCan`/`Policy` method. Send a request as a low-priv user. Does it run? What does it return? `false` and skipped means no auth fired.

### Confirm sanitiser
- Set breakpoint on the sanitiser function. Send distinctive input. Did sanitiser run? With what arguments? Did it modify or just check?

### Find hidden code paths
- Breakpoint everywhere; trigger a route; the call stack at each break reveals AOP/decorator/middleware code you didn't know existed.

### Reproduce race conditions
- Breakpoint on the read; freeze; send a parallel write request; observe the read still sees stale state. TOCTOU confirmed.

## Pitfalls
- **Hot reload / bytecode rewriting** (Spring DevTools, Django auto-reload) sometimes loses breakpoints. Pin to debug mode and disable hot reload.
- **Optimised builds** strip line info. Audit on debug builds.
- **Remote debugger over the internet is dangerous** — JDWP is unauthenticated by default. Tunnel via SSH.
- **Production debug** is forbidden by definition; never attach to live customer systems without explicit auth + change window.

## References
- [JetBrains debug docs](https://www.jetbrains.com/help/idea/debugging-code.html) — Java/Kotlin
- [Microsoft .NET Debugging guide](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/)
- [Python debugpy](https://github.com/microsoft/debugpy)
- [Delve for Go](https://github.com/go-delve/delve)
- [Xdebug for PHP](https://xdebug.org/)
- See also: [[whitebox-to-exploit-methodology]], [[blind-vuln-confirmation-from-source]], [[dynamic-debugging]]

{% endraw %}
