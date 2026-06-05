---
title: Python code auditing
slug: python-code-auditing
aliases: [python-source-review, django-flask-audit]
---

{% raw %}

> **TL;DR:** Python audits cluster around dynamic execution (`eval`/`exec`/`compile`), deserialization (`pickle`/`yaml.load`/`shelve`), template SSTI (Jinja2 `Template(x).render`), ORM raw queries, and Werkzeug/Django middleware bugs. Cross-link [[python-dangerous-sinks]] for the sink catalogue; this note is the methodology.

## What it is
Python web apps span Flask (small, explicit), Django (batteries-included), FastAPI (Pydantic-first), and Tornado/aiohttp/Starlette (ASGI). Each routes differently but shares the same underlying sinks. ML / data-science codebases add another tier of risk: `pickle` loads from "trusted" storage that wasn't, Jupyter kernels with `--allow-root`, and notebook `papermill` parameterisation.

## Preconditions / where it applies
- Source (.py, requirements.txt / pyproject.toml)
- Framework knowledge — Django URL routing differs from Flask blueprints
- Python version — `ast.literal_eval` safe, `eval` not; `pickle5` extends 3.8+; `asyncio` race surface

## Technique
1. **Map entry points.**
   - Flask: `@app.route`, `Blueprint.add_url_rule`, `@app.before_request`.
   - Django: `urls.py` `path()` / `re_path()`, class-based views (`View.dispatch`), DRF `@action`.
   - FastAPI: `@app.get/post`, `APIRouter`, dependency-injection chains.
   - Starlette: `Route(path, endpoint)`.
   - Celery tasks (`@shared_task`) — also accept user data via task args; audit pickle serializer config.
2. **Trace sources.** `request.form`, `request.args`, `request.json`, `request.files`, `request.headers`, `request.cookies`, `request.GET/POST` (Django), `request.body` (raw). FastAPI Pydantic models — check for `extra = "allow"` permitting extra fields → mass-assignment.
3. **Sink catalogue** — see [[python-dangerous-sinks]]:
```bash
rg -n '\beval\(|\bexec\(|\bcompile\(' .
rg -n 'pickle\.(loads?|Unpickler)|cPickle\.' .
rg -n 'yaml\.load\([^,)]*\)|yaml\.unsafe_load' .                # safe: yaml.safe_load
rg -n 'subprocess\.(call|run|Popen|check_output)\(.*shell\s*=\s*True' .
rg -n 'os\.(system|popen|exec[lv]p?e?)\(' .
rg -n 'Jinja2.*Template\(|Environment\(.*autoescape\s*=\s*False' .
rg -n '\.raw\(\s*[fr]?["\x27].*\{|cursor\.execute\(\s*[fr]?["\x27].*\{' .   # f-string SQL
rg -n 'requests\.(get|post)\(\s*request\.|urllib\.request\.urlopen\(' .
rg -n 'send_file\(\s*request\.|safe_join\(' .
rg -n 'marshal\.loads?|shelve\.open' .
```
4. **Pickle.** `pickle.loads(x)` on attacker bytes is RCE — `__reduce__` runs arbitrary code on deserialize. Audit Redis/memcached/queue payloads, session cookies (`itsdangerous` signs but doesn't prevent if key leaks), Celery `pickle` serializer.
5. **YAML.** `yaml.load(x)` (PyYAML <6.0 default loader) deserialises arbitrary Python objects. `yaml.safe_load` is required. `ruamel.yaml` also has `unsafe` modes.
6. **SSTI.** Jinja2 `Environment().from_string(user_template).render(context)` — RCE via `{{ ''.__class__.__mro__[1].__subclasses__() }}` chain. Django templates are more sandboxed but `{% raw %}{% include name %}{% endraw %}` with user-controlled `name` is still LFI. See [[ssti]], [[python-ssti-jinja]].
7. **SQL injection.** Django ORM `.filter(name=x)` is safe; `.raw("SELECT * FROM users WHERE name='%s'" % x)` is not. SQLAlchemy `text(f"...")` interpolation = SQLi. f-strings in `cursor.execute` are SQLi.
8. **SSRF.** `requests.get(request.json["url"])` with no allowlist. Django's `URLValidator` is regex-only, doesn't prevent DNS rebinding ([[dns-rebinding]]).
9. **Mass assignment / Pydantic.** `class Foo(BaseModel): name: str` with `model_config = ConfigDict(extra='allow')` lets attacker add `is_admin` and a downstream `Object.assign`-style update propagates it. Use `extra='forbid'`.
10. **Path traversal.** `send_file(request.args.get('f'))` doesn't sanitise. `safe_join` in Flask/Werkzeug returns None on traversal — must check return.
11. **Format string.** `"Hello {user.email}".format_map(request.args)` lets `{user.password}` leak attribute access — see [[python-format-string]].
12. **Sandbox escape.** Anything claiming "safe eval" (`asteval`, `simpleeval`, `RestrictedPython`) has had escapes. Treat as RCE-equivalent unless run in a strict OS sandbox.
13. **`sys.audit` bypass.** Hardening via audit hooks can be bypassed — see [[python-sys-audit-bypass]].

## Detection and defence
- Bandit + Semgrep `python.lang.security`; both have low-FP RCE/SSRF rules.
- Move all `pickle` to `msgpack`/`json` where the format allows.
- Force `yaml.safe_load` via `import yaml; yaml.load = yaml.safe_load` in a sitecustomize hook (defence in depth, not a fix).
- Pydantic `extra='forbid'` org-wide; type-check binders.
- For Django: `SECURE_*` settings audit, `ALLOWED_HOSTS` non-wildcard, CSP middleware.

## References
- [Bandit](https://bandit.readthedocs.io/) — Python AST-based linter
- [PyYAML loader matrix](https://github.com/yaml/pyyaml/wiki/PyYAML-yaml.load(input)-Deprecation)
- [OWASP Python Security Project](https://owasp.org/www-project-python-security/)
- [Doyensec — Python deserialization](https://blog.doyensec.com/)
- See also: [[python-dangerous-sinks]], [[python-deserialization]], [[django-audit-patterns]]

{% endraw %}
