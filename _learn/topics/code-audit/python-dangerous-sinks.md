---
title: Python Dangerous Sinks Audit
slug: python-dangerous-sinks
---

> **TL;DR:** Auditors grep for `eval`, `exec`, `pickle.loads`, `yaml.load`, `subprocess(..., shell=True)`, `os.system`, and Jinja2 templates with `autoescape=False`, because each is a one-line jump from user input to RCE or XSS.

## What it is
Python ships several stdlib and ecosystem APIs that interpret their argument as code, a serialised object graph, or a shell command. When any of these consume data derived from HTTP requests, message queues, or untrusted files, the result is typically remote code execution or template injection. These sinks slip through review because they look idiomatic — `yaml.load` was the default for years, and `shell=True` is the quickest way to glue commands together.

## Preconditions / where it applies
- CPython 3.x, plus PyYAML <6.0, Jinja2, Flask, Django, FastAPI, Celery
- Sinks usually live in deserialisation layers (caches, session stores, task brokers), CLI wrappers, and reporting/templating endpoints
- Safe-looking patterns: `yaml.load(stream, Loader=yaml.Loader)`, `subprocess.run(f"convert {name}", shell=True)`, `pickle.loads(redis.get(key))`

## Technique
{% raw %}
```python
# RCE via pickle deserialisation of a cache value
import pickle, base64
payload = base64.b64decode(request.cookies["session"])
user = pickle.loads(payload)  # arbitrary __reduce__ runs here

# Command injection via shell=True
import subprocess
subprocess.run(f"ffmpeg -i {request.args['file']} out.mp4", shell=True)

# YAML tag executes Python objects
import yaml
yaml.load(request.data, Loader=yaml.Loader)
# Payload: !!python/object/apply:os.system ["id > /tmp/p"]

# Jinja2 SSTI when autoescape is off and template is user-controlled
from jinja2 import Environment
Environment(autoescape=False).from_string(request.args["t"]).render()
# Payload: {{ ''.__class__.__mro__[1].__subclasses__() }}
```
{% endraw %}

## Detection and defence
- Semgrep: `python.lang.security.audit.dangerous-subprocess-use`, `python.lang.security.deserialization.pickle`, `python.flask.security.audit.render-template-string`
- CodeQL: `py/code-injection`, `py/unsafe-deserialization`, `py/command-line-injection`
- Replacements: `ast.literal_eval` for `eval`, `yaml.safe_load`, `pickle` → `json`/`msgpack` with HMAC, `subprocess.run([...], shell=False)`
- Force `autoescape=True` (or use `select_autoescape`) and never `render_template_string` on user input

## References
- [Python pickle security](https://docs.python.org/3/library/pickle.html) — official warning on untrusted data
- [PyYAML 6.0 changelog](https://github.com/yaml/pyyaml/releases) — `yaml.load` default loader change
- [Semgrep Python security rules](https://semgrep.dev/p/python) — curated ruleset

See also: [[source-sink-flow-analysis]], [[dangerous-java-sinks]], [[dangerous-php-sinks]].
