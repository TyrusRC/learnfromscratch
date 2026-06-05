---
title: Spring deserialisation / SpEL / RCE deep dive
slug: spring-deserialisation-deep
aliases: [spring-attacks-deep, spel-injection, spring4shell-class]
---

> **TL;DR:** Spring (Spring Framework, Spring Boot, Spring Cloud) is the dominant Java web framework. The RCE-class bug surface clusters into: (1) Spring Expression Language (SpEL) injection in routes / Thymeleaf / SpEL-binding, (2) data-binding bypass enabling write to arbitrary properties (Spring4Shell, CVE-2022-22965), (3) Spring Cloud Function / Gateway / Cloud Config injection (CVE-2022-22963, CVE-2022-22947), and (4) classic Java deserialisation via accepted endpoints. Companion to [[java-deserialization-audit]] and [[spring-boot-audit-patterns]].

## Why Spring deeper

- **Most-deployed Java enterprise stack**.
- **Spring4Shell (2022)** demonstrated data-binding RCE with limited prereqs but huge install base.
- **SpEL** is rich — string-as-expression evaluates to arbitrary code.
- **Spring Cloud** subsystems each have their own injection classes.

## Class 1 — SpEL injection

Spring Expression Language is a runtime expression evaluator. Used in:
- `@Value("#{...}")` annotation.
- `T(...)` static-type access.
- Thymeleaf `th:utext="${...}"` and similar.
- Some configuration paths.

If user input becomes part of a SpEL expression evaluated by Spring:

```java
ExpressionParser parser = new SpelExpressionParser();
Expression exp = parser.parseExpression(userInput);
exp.getValue();   // arbitrary code execution
```

Payloads like `T(java.lang.Runtime).getRuntime().exec("calc")` give RCE.

Historical CVE: many. Spring Boot Actuator endpoints that exposed SpEL evaluation (multiple CVEs).

## Class 2 — Data-binding (Spring4Shell)

CVE-2022-22965. JDK 9+ removed reflection restriction. Spring's `WebRequest` data binding allowed setting any property of the model bean via request parameter `name`.

With JDK 9+, the chain `class.module.classLoader.resources.context.parent.pipeline.first.{...}` reached Tomcat's `AccessLogValve`. Setting the log file location + log pattern wrote attacker-controlled file (with arbitrary content) — JSP file in webroot. Visit JSP → RCE.

Prereqs were specific but matched many Tomcat-based Spring deployments.

Patch: blocked the `class` traversal.

## Class 3 — Spring Cloud Function (CVE-2022-22963)

Spring Cloud Function's HTTP dispatcher used a header `spring.cloud.function.routing-expression`. Value parsed as SpEL → RCE.

Single HTTP request to a Function-exposed endpoint with crafted header.

## Class 4 — Spring Cloud Gateway (CVE-2022-22947)

Gateway's Actuator endpoint, if exposed, accepted creating new routes with predicate / filter definitions including SpEL. Attacker creates route with SpEL filter → triggers route → RCE.

## Class 5 — Spring Cloud Config (CVE-2019-3799, CVE-2020-5410)

Spring Cloud Config server had path-traversal bugs.

## Class 6 — Thymeleaf SpEL injection

Thymeleaf templates use SpEL for dynamic content:

```html
<div th:text="${user.name}"></div>
```

If user input becomes part of `th:text` value or attribute:

```html
<div th:text="${T(java.lang.Runtime).getRuntime().exec('whoami')}"></div>
```

RCE via template injection. See [[ssti]].

## Class 7 — Reflection-based property setting

`PropertyUtils.setProperty` and similar in some Spring data-binding chains accept attacker-supplied property paths. Without filter, can reach beans not intended to be mutable.

## Class 8 — Classic Java deserialisation

Spring endpoints accepting `application/x-java-serialized-object`:
- Direct ObjectInputStream.
- Gadget chains via included libraries (Commons Collections, etc.).

See [[java-deserialization-audit]].

## Class 9 — XStream / Jackson misconfig

Spring projects often use XStream (XML) or Jackson polymorphic deserialisation:
- Polymorphic without type allowlist = RCE.
- XStream pre-2017 default = RCE.

## Class 10 — Actuator endpoint exposure

Spring Boot Actuator exposes management endpoints:
- `/env` — environment variables (often secrets).
- `/heapdump` — heap dump (potentially with credentials).
- `/jolokia` — JMX over HTTP; class-loading abuse.

In production with public-facing Actuator, multiple paths to compromise.

## Audit shape

For a Spring application:
1. **Endpoints**: list `@RestController`, `@Controller`, `@RequestMapping` patterns.
2. **SpEL usage**: grep for `parseExpression`, `getValue`.
3. **Data binding**: identify `@ModelAttribute`, `@RequestParam`, beans bound to.
4. **Actuator**: check enabled endpoints, exposure.
5. **Cloud subsystems**: which Spring Cloud projects are used.
6. **Deserialisation**: identify Jackson / XStream / Java-serialised endpoints.
7. **Template engine**: Thymeleaf, Freemarker — SSTI surface.
8. **Spring version** + patch level.

## Defensive baseline

- **Update Spring** promptly; CVEs published quarterly.
- **Avoid SpEL on user input** without strict allowlist.
- **Disable Actuator** in production; or restrict access.
- **Spring Boot 2.7+ / 3.x** — defaults are safer.
- **Java serialization filter** for ObjectInputStream.
- **Polymorphic Jackson** with allowlist.
- **Thymeleaf**: use `th:text` (escapes), avoid `th:utext` on user input.
- **Static analysis** — Snyk, Sonar, Semgrep rules for Spring.

## Workflow to study

1. Reproduce Spring4Shell in a controlled Docker.
2. Practice SpEL injection in a deliberately vulnerable app.
3. Audit Spring Cloud Function exposure.
4. Read CVE writeups for Spring4Shell + Cloud-Function-RCE.

## Tools

- **Burp** + Spring-specific extensions.
- **Semgrep** Spring rules.
- **GitHub Code Search** for `parseExpression`.
- **Trivy** for known-CVE scanning.
- **Snyk**, **Sonatype** — SCA.

## Real-world incidents

- **Spring4Shell** (2022) — mass exploitation; Volexity / NSFOCUS / others reported active campaigns.
- **Spring Cloud Function** (CVE-2022-22963) — adjacent mass exploitation.
- **Spring Cloud Gateway** (CVE-2022-22947) — similar.

## Related

- [[java-code-auditing]]
- [[java-deserialization-audit]]
- [[spring-boot-audit-patterns]]
- [[ssti]]
- [[expression-injection]]
- [[dotnet-deserialisation-deep]]

## References
- [Spring Framework security advisories](https://spring.io/security)
- [VMware Tanzu Spring CVE history](https://tanzu.vmware.com/security/)
- [JFrog — Spring4Shell analysis](https://jfrog.com/blog/)
- [Snyk Security Labs — Spring](https://labs.snyk.io/)
- See also: [[java-deserialization-audit]], [[spring-boot-audit-patterns]], [[ssti]], [[expression-injection]]
