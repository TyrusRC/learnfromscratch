---
title: Remote code execution (RCE) — class
slug: rce-class
---

{% raw %}

> **TL;DR:** End state of many chains: command injection, deserialisation, SSTI, file upload, dependency RCE. Track as a bug class to reason about impact.

## What it is
Rather than a single technique, RCE is a *terminal* — the point where attacker bytes become executed instructions on the target host. It is reached from many starting primitives. Treating RCE as a class helps in triage (what does the bug actually grant?), in scoping (which other primitives could lead here?), and in defence (what controls survive once RCE is reached?).

## Preconditions / where it applies
- A primitive that controls bytes interpreted by an executor: shell, language eval, deserialiser, template engine, native loader, query engine
- A way to deliver the primitive (HTTP, queue message, file upload, scheduled job, supply chain)
- An executor with reachable side effects (network, filesystem, secrets, cluster API)

## Technique — common paths to RCE
1. **Direct command injection** — user input concatenated into `system()`/`exec()`. Inject `; id`, backticks, `$(…)`, newline. See [[command-injection]].
2. **Deserialisation** — language-native object stream lets attacker pick gadget chains: Java `ObjectInputStream` + ysoserial, .NET `BinaryFormatter`, PHP `unserialize`, Python `pickle.loads`, Ruby Marshal. See [[deserialisation]].
3. **Server-side template injection** — `{{7*7}}` returns 49 → Jinja/Twig/Velocity engine eval → `{{ self.__class__.__mro__[1].__subclasses__() }}` to RCE. See [[ssti]].
4. **File upload to executable path** — upload `.php`/`.jsp`/`.aspx`/`.phtml` to a directory the web server interprets; or upload `.htaccess` to redefine handlers. See [[file-upload]].
5. **SQL → RCE** — `xp_cmdshell` (MSSQL), `COPY ... PROGRAM` (Postgres), `INTO OUTFILE` + PHP webshell (MySQL), UDF loading. See [[sql-injection]].
6. **SSRF → metadata → cloud RCE** — IMDS credentials → assume role → cluster API → workload exec. See [[ssrf-to-cloud]].
7. **XXE → file read → key reuse → RCE** — read `id_rsa`, reuse against SSH. See [[xxe]].
8. **Prototype pollution → gadget** — pollute `Object.prototype.shell` then a downstream library uses `opts.shell` in `child_process.spawn`. See [[prototype-pollution]].
9. **Dependency / supply chain** — vulnerable lib (Log4j JNDI, Spring4Shell, ImageMagick coder), typosquat, malicious post-install.
10. **Native loader** — DLL/SO sideload via a writable plugin dir; admin panel that allows arbitrary plugin install.
11. **Eval-based features** — admin-only "scripting" endpoints exposed to lower roles via auth bug.

## Detection and defence
- Defence-in-depth: even granted code exec, limit blast radius — seccomp/AppArmor, read-only FS, non-root, egress allowlist, dropped capabilities, no creds on disk.
- Patch the obvious chains (Log4j, ImageMagick, struts, spring, jackson, fastjson) within hours of advisories.
- EDR signals: child processes from web/app workers, outbound to unusual destinations, suid/setuid spawn, in-memory loader artifacts.
- Honeytokens in `/etc/passwd`, AWS creds, JNDI strings to trip attackers exploring after RCE.
- Treat any RCE as a full-host compromise; rotate every secret reachable from the workload.
- Related: [[command-injection]], [[deserialisation]], [[ssti]], [[file-upload]], [[sql-injection]], [[ssrf-to-cloud]], [[xxe]], [[prototype-pollution]].

## References
- [OWASP Top 10 — A03 Injection](https://owasp.org/Top10/A03_2021-Injection/) — class umbrella
- [HackTricks — methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/index.html) — chain patterns
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) — payload corpus across every primitive
{% endraw %}
