---
title: Dangerous Java sinks reference
slug: dangerous-java-sinks
---

> **TL;DR:** Reference list of Java APIs that produce RCE, SSRF, XXE, deserialisation, JNDI injection, expression injection or path traversal when fed tainted input. Used as the grep list when auditing servlets, Spring controllers, or decompiled JARs.

## What it is
Java's enterprise stack is wide — JDBC, JNDI, JAXP, OGNL/SpEL, reflection, scripting engines, serialization. Each ships sinks that detonate on tainted input. Cataloguing them lets a reviewer run a single pass over the codebase and shortlist exploitable callsites.

## Preconditions / where it applies
- Java/Kotlin/Scala source — or JARs decompiled with CFR, Procyon, jadx
- Servlet/Spring/JAX-RS handlers — anywhere `HttpServletRequest`, `@RequestParam`, `@PathVariable`, `@RequestBody` enters
- Pre-Java-17 classpaths still pulling Commons-Collections, Spring-AOP, BeanUtils — the classic gadget surface

## Technique
Grep, classify, trace. See [[source-sink-flow-analysis]] for the methodology.

**OS command execution:**
```
Runtime.getRuntime().exec(...)
ProcessBuilder(...).start()
new ProcessBuilder(List.of(...)).start()
```
String-arg `exec` tokenises on whitespace — argv-array form is safer but still vulnerable to arg injection.

**Deserialisation** — see [[java-deserialization-audit]]:
```
ObjectInputStream.readObject / readUnshared
XMLDecoder.readObject               // bean XML, trivially executes ctors
XStream.fromXML                     // pre-1.4.x gadgets
Jackson @JsonTypeInfo + enableDefaultTyping
SnakeYAML new Yaml().load           // !!javax.script.ScriptEngineManager gadget
Kryo, Hessian, JSON-IO              // each has known gadget sets
```

**JNDI injection** — Log4Shell-style:
```java
InitialContext.lookup(userControlled)
DirContext.lookup(...)
JndiLocatorDelegate / JndiTemplate.lookup
// any LDAP / RMI URL pulls a remote Reference + class
```

**Expression / template** — see [[expression-injection]]:
```
SpelExpressionParser.parseExpression(input).getValue()
Ognl.getValue(input, root)
MVEL.eval(input)
FreeMarker / Velocity / Thymeleaf with user-controlled templates
```

**Reflection / scripting:**
```
Class.forName(name) + newInstance()
Method.invoke(obj, args)
ScriptEngineManager().getEngineByName("nashorn"/"js").eval(input)
GroovyShell().evaluate(input)
```

**SQL** — `Statement.executeQuery(concat)`. `PreparedStatement` with concat into the SQL string is equally bad — only `?` placeholders are safe. Hibernate `Session.createQuery(hql)` is HQL-injectable.

**XXE:**
```
DocumentBuilderFactory.newInstance()        // defaults enable entities pre-Java-15
SAXParserFactory / XMLInputFactory          // same
TransformerFactory                          // XSLT-style
Unmarshaller (JAXB)                         // XXE if backing parser unhardened
```

**SSRF:**
```
new URL(input).openConnection()
HttpClient.send(...)
Apache HttpClient, OkHttpClient.newCall(...)
ImageIO.read(URL) / javax.imageio with SVG/XBM
```

**Path traversal / file:**
```
new File(parentDir, userPath)        // ../../../etc/passwd
Files.newInputStream / Paths.get     // same
ZipFile entries (Zip-Slip)
```

## Detection and defence
- Static analysis with SpotBugs + FindSecBugs, Semgrep `java.lang.security`, CodeQL `java-security-and-quality`
- Use `ObjectInputFilter` (JEP 290) or `SerialKiller` to lockdown deserialisation
- Disable Jackson default-typing; use `@JsonTypeInfo` with explicit allowlists
- Harden XML parsers: `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)`
- Network egress allowlist + SSRF guard (block link-local + private CIDRs) at the HTTP-client layer

## References
- [HackTricks — Java code audit](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/code-review-tools.html) — review patterns
- [FindSecBugs](https://find-sec-bugs.github.io/bugs.htm) — comprehensive sink list for SpotBugs
- [PortSwigger — Java deserialisation](https://portswigger.net/web-security/deserialization) — exploitation primer
- [ysoserial gadget chains](https://github.com/frohoff/ysoserial) — canonical payload generator
