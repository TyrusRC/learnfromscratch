---
title: Java code auditing
slug: java-code-auditing
---

> **TL;DR:** Map every HTTP route to a handler, then trace request fields to dangerous sinks — `Runtime.exec`, `ObjectInputStream`, JNDI, SpEL/OGNL, JDBC. Decompile JARs with CFR / Procyon / jadx when source is unavailable.

## What it is
Auditing a Java web app means understanding the framework's routing + binding layer, then running a source-to-sink hunt. The same primitives appear across Spring, Struts, JAX-RS, Vert.x, Micronaut — only the annotations change. The interesting bug classes are RCE-via-deserialisation, expression injection, JNDI lookup, SQL/HQL, XXE, SSRF and path traversal.

## Preconditions / where it applies
- Java source (Maven/Gradle) or JAR/WAR archives
- Decompilers — CFR (`cfr-0.152.jar`), Procyon, jadx for Android/Kotlin, Recaf for live IL editing
- Familiarity with `web.xml`, Spring `@Controller` / `@RestController`, JAX-RS `@Path`, OSGi bundles for application servers

## Technique
1. **Map routes.** For Spring: grep `@RequestMapping|@GetMapping|@PostMapping|@PutMapping|@DeleteMapping|@RequestParam|@PathVariable|@RequestBody`. For Struts: `struts.xml` action mappings. For JAX-RS: `@Path` on resource classes. For raw servlets: `web.xml` `<servlet-mapping>` + `HttpServlet.doGet/doPost`. Build a route → method table.
2. **Identify binders / DTOs.** `@RequestBody Foo dto` is a Jackson/Gson sink — type confusion lives here. `@ModelAttribute` binds query/form into POJOs (Spring4Shell pattern). Hidden fields like `class.classLoader.URLs[0]` may be writable.
3. **Decompile if no source.**
```
java -jar cfr.jar app.war --outputdir out/
jadx -d out app.jar
```
Triage `WEB-INF/lib/*.jar` for vulnerable versions (Log4j 2.x, Commons-Collections 3.x, Spring < 5.3.x).
4. **Hunt sinks.** Use the catalogue in [[dangerous-java-sinks]]. Top priorities:
   - `ObjectInputStream.readObject` — see [[java-deserialization-audit]]
   - `InitialContext.lookup(userControlled)` — JNDI / Log4Shell-class bugs
   - `parser.parseExpression(input).getValue()` — see [[expression-injection]]
   - `Statement.executeQuery("..." + input)` — SQLi
   - `Runtime.exec` / `ProcessBuilder` with concat
   - `DocumentBuilderFactory` without `disallow-doctype-decl` — XXE
5. **Auth + filter analysis.** Walk every `Filter` chain and Spring Security `SecurityFilterChain` config. Look for `permitAll()` on dangerous routes, wildcard antMatchers, missing CSRF for state-changing endpoints, and `authorizeRequests().anyRequest().permitAll()` left over from scaffolding.
6. **Trust deserialisers.** Jackson with `enableDefaultTyping()` or `@JsonTypeInfo(use=Id.CLASS)` + no allowlist is a known sink. XStream pre-1.4.18 is gadget-laden. SnakeYAML `new Yaml().load` defaults to unsafe constructor.
7. **Static analysis.** Run SpotBugs + FindSecBugs, Semgrep `java.lang.security`, CodeQL `java-security-and-quality`. Treat results as starting points — confirm reachability manually.

```bash
# decompile + grep
unzip app.war -d app/
find app/WEB-INF/lib -name '*.jar' -exec sh -c 'mkdir -p src/${1##*/}; cd src/${1##*/}; jar xf "$0"; java -jar ~/tools/cfr.jar . > out.java 2>/dev/null' {} \;
grep -RnE 'readObject|InitialContext\.lookup|parseExpression|Runtime\.exec|ProcessBuilder' src/
```

## Detection and defence
- Apply JEP 290 `ObjectInputFilter` globally; deny `org.apache.commons.collections.*` etc.
- Disable Jackson default-typing or use `PolymorphicTypeValidator` with allowlist
- Spring Security — explicit `denyAll` default and per-route grants
- Use parameterised JDBC / Criteria / JPA Named Queries; ban string-concat HQL
- Centralise SSRF guard at the HTTP-client factory level

## References
- [HackTricks — Java audit checklist](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/code-review-tools.html) — review patterns
- [Spring Security reference](https://docs.spring.io/spring-security/reference/) — filter-chain semantics
- [FindSecBugs sink catalogue](https://find-sec-bugs.github.io/bugs.htm) — sink → bug-class map
- [ysoserial](https://github.com/frohoff/ysoserial) — gadget chains for deserialisation testing
