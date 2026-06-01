---
title: NoSQL injection
slug: nosql-injection
---

> **TL;DR:** A document database query (Mongo, Couch, Redis-search) is built from JSON the client controls — passing operator objects like `{"$ne": null}` or `{"$regex": "^a"}` breaks auth and exfiltrates documents one char at a time.

## What it is
Document/keyvalue stores accept query expressions as structured data, not strings. If a web framework passes the request body directly into the query (Mongoose `User.findOne(req.body)`, ExpressJS `qs` parser turning `user[$ne]=x` into a nested object), the attacker turns a scalar comparison into an operator comparison and changes the semantic.

## Preconditions / where it applies
- Backend stores: MongoDB, CouchDB, Cassandra (CQL has its own injection), Redis (`EVAL`), Elastic (`query_string`), Firestore (rules-based).
- The endpoint accepts JSON or URL-encoded nested params (`a[b]=c` → `{a:{b:'c'}}`), or the dev built a raw Mongo filter from a string.
- Most prevalent in Node/Express + Mongoose stacks; PHP MongoDB drivers were the original vector (`$ne` operator).

## Technique

**Authentication bypass (operator injection).**

Request body:

```json
{"username": "admin", "password": {"$ne": ""}}
```

`User.findOne(req.body)` returns the admin record because `password != ""`. Same trick over query string in Express where `qs` is enabled:

```
GET /login?username=admin&password[$ne]=x
```

**Blind boolean exfil via `$regex`.**

```json
{"username": "admin", "password": {"$regex": "^a"}}
```

If the response says "login OK" / sets a session, the first char is `a`. Iterate the alphabet, then `^aa`, `^ab`. PortSwigger and `nosqli-scanner` automate this.

**Mongo `$where` and JS injection.**

When the app builds a `$where` clause from input, attacker JS runs inside the DB:

```json
{"$where": "this.username == 'admin' && sleep(5000)"}
```

Useful for timing exfil even when boolean signal is missing.

**Aggregation pipeline injection.** `$lookup`, `$expr`, `$function` (Mongo 4.4+) let you cross-collection-read.

**CouchDB / view injection.** `_temp_view` POST with attacker map-reduce; CVE-2017-12635 added admin via duplicate JSON keys.

**Redis EVAL / Lua sandbox escape** when an app passes user input into `EVAL` scripts (CVE-2022-0543 sandbox escape on Debian package).

**Elastic `query_string`** — Lucene operators (`AND`, `OR`, `*`) plus `_index:*` to bleed cross-index.

## Detection and defence
- Validate body with a schema (Joi / Zod / class-validator). Reject objects where strings are expected — `typeof password !== 'string'` ⇒ 400.
- Use parameterised builders (`User.findOne({ username: String(username), password: String(password) })`).
- Disable nested query parsing where not needed (`app.set('query parser', 'simple')` in Express).
- Hash passwords with a slow KDF (`argon2`, `bcrypt`); never store plaintext that could be regex-leaked.
- Disable Mongo `$where` and server-side JS (`security.javascriptEnabled: false`).
- Monitoring: high cardinality of distinct regex patterns from one client, or aggregation pipelines from web tier.

See also [[sql-injection]], [[graphql-attacks]], [[mongodb-exposed]].

## References
- [PortSwigger – NoSQL injection](https://portswigger.net/web-security/nosql-injection) — primer + labs
- [HackTricks – NoSQL injection](https://book.hacktricks.wiki/en/pentesting-web/nosql-injection.html) — operator catalogue
- [PayloadsAllTheThings – NoSQL injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/NoSQL%20Injection) — payloads
