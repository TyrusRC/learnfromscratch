---
title: Second-order injection chains
slug: second-order-injection-chains
aliases: [stored-injection-chain, persisted-taint]
---

{% raw %}

> **TL;DR:** First-order bugs trigger on the request that supplies the input. Second-order bugs trigger when the *stored* value is later read, concatenated, deserialized, or rendered by code that trusts the storage. Source review is where second-order shines — the read sink looks safe, but the write was unvalidated. Audit for the storage→read pair, not the sink in isolation.

## What it is
A "second-order" or "persisted" injection is a chain in two requests:
1. **Write**: attacker stores tainted data via a path that doesn't validate it (e.g., a profile field, an audit log, an API key label).
2. **Read**: a different code path reads that storage and reaches a sink (SQL, shell, eval, template, HTTP, file path) on an implicit trust assumption.

The vulnerability lives in the gap between trust zones. Scanners miss them because trigger and sink are in separate requests; whitebox finds them because both ends live in the same repo.

## Shapes

### Second-order SQLi
- Attacker registers username `' OR '1`. Profile page later constructs query as `"... WHERE display_name = '" + username + "'"` in an admin report.
- Stored `email` field used as raw bind in a migration script.
- ORM `find_by_email` safe but a cron job's `pg.query("INSERT INTO audit ('" + email + "', ...)")` is not.

### Second-order command injection
- User uploads a file; original name stored. Later, a backup job runs `tar czf backup.tar.gz user-uploads/${filename}`. Filename `; rm -rf /; #` is RCE on backup run.
- Profile photo URL stored unvalidated; thumbnail worker shells out to `convert ${url}` → RCE.

### Second-order SSRF
- Stored webhook URL on org settings. Later, an internal worker fetches it without scheme/IP allowlist → SSRF to metadata service.
- OAuth client `redirect_uri` stored on registration; admin audit dashboard fetches a preview of each → SSRF from admin host.

### Second-order deserialization
- API stores serialized session in a queue. Worker `unserialize`s on dequeue. Attacker who controls the serialization step (via mass-assignment or via a different storage path that lands in the same queue) gets RCE.
- Cached `to_yaml` representation of a record stored in Redis; cache warmer `YAML.load`s it.

### Second-order SSTI
- Email template body stored in DB by admin; rendered by mailer with full SpEL/Jinja context including request user. Admin-level XSS via stored template → privilege escalation via template-side eval.
- Slack/Discord message templates with `{{user.tokens}}` style — attacker stores template, victim's render leaks their tokens.

### Second-order XSS via stored HTML
- "Stored XSS" is the canonical second-order. Audit every read-side that bypasses escaping (`mark_safe`, `{!!  !!}`, `Html.Raw`, `dangerouslySetInnerHTML`) and trace storage back to user-writable source.

### Second-order log injection / log4shell shape
- Attacker stores `${jndi:ldap://x}` in a profile field that's eventually logged with `log.info(profile)`. Log4j 1.x and Log4j2 <2.17 are RCE on the read.

## Audit workflow
1. **Map storage.** Every DB table, queue, cache, file dir, external service that holds user-writable data.
2. **Map reads.** Every code path that reads from those storages. Each read is a candidate sink.
3. **Tag the trust boundary.** When the write happens via an authenticated route with validation, that's a trust boundary. The read side may treat the data as trusted just because it's stored — that's the bug.
4. **Trace read → sink.** For each read, follow into the function. If it concats into SQL/shell/URL/template/code → second-order pair found.
5. **Check the write side**. Validate that the write actually validates the field shape. Many fields are stored without normalisation (length cap, charset, scheme) — that's the entry point.

## Grep starter
```bash
# Find reads from storage that reach raw queries
rg -n 'pg\.query\(.*\$|connection\.query\(.*\$|cursor\.execute\(.*\$' -B2

# Find shell-out using stored fields
rg -n 'exec\(.*user|exec\(.*record|exec\(.*model' .

# Find unserialize/deserialize from queues
rg -n 'unserialize\(.*queue|Marshal\.load.*redis|pickle\.loads.*celery' .

# Find log injection candidates (log lines containing model fields)
rg -n 'log\.(info|warn|error)\(.*user|logger\.info\(.*record' .
```

## Defence
- **Validate on write *and* re-validate on read.** Storage is not a trust boundary.
- **Parameterise reads.** Stored values flow through `?` placeholders, never concat.
- **Constrain storage shape.** Email field is RFC 5322 — strip everything else.
- **Re-encode at sink.** A field read into HTML escapes; into SQL parameterises; into shell quotes/whitelists.
- **Tag storage by source.** Schema/typing where a column is "from user input" vs "from system" — code can then assert on read.

## References
- [PortSwigger — Second-order SQL injection](https://portswigger.net/kb/issues/00100210_sql-injection-second-order)
- [OWASP Code Review Guide — Persisted tainted data](https://owasp.org/www-project-code-review-guide/)
- [GitHub Security Lab — CodeQL queries on second-order](https://securitylab.github.com/)
- See also: [[source-sink-flow-analysis]], [[ssrf-source-sink-flow]], [[whitebox-to-exploit-methodology]]

{% endraw %}
