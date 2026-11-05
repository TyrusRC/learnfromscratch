---
title: XSS from source review
slug: xss-from-source-review
aliases: [whitebox-xss, xss-source-audit]
---

> **TL;DR:** Grep for framework-specific unescaped output functions (`|safe`, `raw()`, `dangerouslySetInnerHTML`, `v-html`, `bypassSecurityTrustHtml`), then trace backwards to find user-controlled data reaching them. Template injection and DOM sinks are the two paths most auditors miss.

## What it is
Finding XSS from source code means inverting the blackbox approach: instead of injecting payloads and watching what reflects, you start at the dangerous output sinks in templates and JavaScript, then trace whether attacker-controlled input reaches them without encoding. Each framework has its own "escape hatch" that developers misuse.

## Preconditions / where it applies
- Access to application source code (whitebox / OSWE context)
- Knowledge of the target's template engine and frontend framework
- [[java-code-auditing]], [[ruby-rails-audit-patterns]], or equivalent for the target stack

## Per-framework unescaped output sinks

### Django (Jinja2 / DTL)
```html
<!-- Auto-escaped (safe) -->
{{ user_input }}

<!-- DANGEROUS — marks string as safe, skips escaping -->
{{ user_input|safe }}
{% autoescape off %}{{ user_input }}{% endautoescape %}
```
```python
# Python-side: marking content safe before it hits the template
from django.utils.safestring import mark_safe
return mark_safe(f"<div>{user_input}</div>")  # XSS if user_input is tainted
```
**Grep pattern:** `\|safe`, `mark_safe(`, `autoescape off`

### Ruby on Rails (ERB)
```erb
<!-- Auto-escaped -->
<%= user_input %>

<!-- DANGEROUS — bypasses escaping -->
<%= raw user_input %>
<%= user_input.html_safe %>
<%== user_input %>
```
**Grep pattern:** `\.html_safe`, `\braw\b`, `<%==`

### React (JSX)
```jsx
// Safe — React escapes by default
<div>{userInput}</div>

// DANGEROUS — injects raw HTML
<div dangerouslySetInnerHTML={{__html: userInput}} />
```
**Grep pattern:** `dangerouslySetInnerHTML`

### Vue.js
```html
<!-- Safe — text interpolation -->
{{ userInput }}

<!-- DANGEROUS — renders as HTML -->
<div v-html="userInput"></div>
```
**Grep pattern:** `v-html`

### Angular
```typescript
// Safe — Angular sanitizes by default
this.content = userInput;

// DANGEROUS — bypasses the sanitizer
import { DomSanitizer } from '@angular/platform-browser';
this.content = this.sanitizer.bypassSecurityTrustHtml(userInput);
```
Other bypass methods: `bypassSecurityTrustScript`, `bypassSecurityTrustUrl`, `bypassSecurityTrustResourceUrl`.

**Grep pattern:** `bypassSecurityTrust`

### PHP (Blade / Twig / raw)
```php
<!-- Blade: escaped -->
{{ $input }}
<!-- Blade: DANGEROUS -->
{!! $input !!}

<!-- Twig: escaped -->
{{ input }}
<!-- Twig: DANGEROUS -->
{{ input|raw }}
{% autoescape false %}{{ input }}{% endautoescape %}
```
**Grep pattern:** `{!!`, `\|raw`, `autoescape false`

## Template injection leading to XSS

When user input is concatenated into a template string before rendering, it's not just XSS — it's SSTI that can escalate to RCE. But even when sandboxed, SSTI gives XSS trivially.

```python
# Jinja2 SSTI → XSS (and potentially RCE)
template = Template("Hello " + user_input)  # user_input = {{7*7}} → "Hello 49"
# XSS payload: {{config.__class__.__init__.__globals__['os'].popen('id').read()}}
```

```ruby
# ERB SSTI
ERB.new("Hello #{user_input}").result  # user_input = <%= system('id') %>
```

**Grep pattern:** look for user input concatenated with template strings before `Template()`, `ERB.new()`, `render_template_string()`, `Mustache.render()`.

## DOM sink analysis from source

Even with server-side escaping, DOM XSS fires client-side. Audit JavaScript source for these sinks:

```javascript
// High-severity DOM sinks
element.innerHTML = userControlled;      // direct HTML injection
element.outerHTML = userControlled;
document.write(userControlled);
document.writeln(userControlled);
eval(userControlled);                     // JS execution
setTimeout(userControlled, 0);            // string form = eval
setInterval(userControlled, 0);
new Function(userControlled);
location.href = userControlled;           // javascript: protocol XSS
location.assign(userControlled);
window.open(userControlled);

// Sources to trace from
document.location.hash
document.location.search
document.referrer
window.name
postMessage event.data
```

**Audit method:** Map every DOM sink, then trace backwards to see if any source (`location.hash`, `URLSearchParams`, `postMessage`) flows into it without sanitization. Tools like `semgrep --config p/javascript` automate the first pass.

## Whitebox XSS audit checklist
1. Grep all template files for framework-specific unescaped sinks
2. For each hit, trace the variable back to the controller/route handler
3. Determine if any path from HTTP input reaches the sink without sanitization
4. Check for SSTI by looking for dynamic template construction
5. Audit all `.js` files for DOM sinks receiving data from URL or `postMessage`
6. Check for CSP headers that would block inline script execution — if absent, any reflected/stored XSS fires

## References
- [[session-hijacking-from-source]] — XSS is the #1 vector for session theft
- [[ruby-rails-audit-patterns]] — Rails-specific audit patterns including `html_safe`
- [[java-code-auditing]] — Java template engines (Thymeleaf, Freemarker) have their own sinks
- [PortSwigger — DOM-based XSS](https://portswigger.net/web-security/cross-site-scripting/dom-based) — DOM source/sink reference
- [Semgrep XSS rules](https://semgrep.dev/p/xss) — automated grep for common sinks
