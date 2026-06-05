---
title: Django advanced audit
slug: django-advanced-audit
aliases: [django-deep-audit, django-advanced]
---

> **TL;DR:** Beyond the basics in [[django-audit-patterns]]: advanced Django audit covers SSRF in URLValidator / `requests` patterns, RCE via `eval`/`exec`/`os.system` chains, classic deserialisation in pickled sessions/cache, Django Admin sub-path bypasses, Q objects / `extra()` / `raw()` SQL injection, GIS / file-storage misconfig, channels websocket auth gaps, and Django REST Framework permission-class fallthrough. Companion to [[django-audit-patterns]] and [[python-deserialization]].

## Why advanced

Most Django apps audit cleanly for the standard OWASP top 10 because of safe defaults. The advanced class lives in:
- Patterns developers write to "escape" the safe defaults.
- DRF (Django REST Framework) misconfiguration.
- Custom serialiser / form / view code.

## Class 1 — SSRF via fetched URLs

```python
import requests

def fetch(request):
    url = request.GET['url']
    response = requests.get(url)
    return HttpResponse(response.content)
```

Standard SSRF. See [[ssrf]] and [[ssrf-to-cloud-advanced-chains]].

URLValidator doesn't help — it validates URL syntax, not target IP.

## Class 2 — `eval` / `exec` / `subprocess`

Less common in Django than in scripted Python projects, but appears in admin tools, data-pipeline code:

```python
result = eval(request.POST['expr'])
subprocess.call(f"convert {filename}", shell=True)
```

Same as [[command-injection]] and Python eval anti-pattern.

## Class 3 — Pickle deserialisation

Django used to support pickle session serializer (now JSON by default). Some codebases:
- Use `signed_cookies` with pickle for "convenience".
- Use cache backend that pickles values; if cache key is attacker-influenced, payload-controlled cache write → pickle-deserialise on read.

Pickle = RCE.

See [[python-deserialization]].

## Class 4 — `Q` objects / `extra()` / `raw()` SQL

`.raw(string)` and `.extra(where=string)` accept raw SQL — interpolation = SQLi:

```python
User.objects.extra(where=[f"role = '{role}'"])  # injection!
User.objects.raw(f"SELECT * FROM auth_user WHERE role = '{role}'")
```

`Q` objects are safer but constructed via `**kwargs` with user-controlled keys reach attribute lookup paths that may surprise.

## Class 5 — Template engine SSTI

Django templates are safer than Jinja2 by default (limited expression set). But:
- Custom template tags can execute arbitrary code.
- Jinja2 used alongside Django (via `django.template.backends.jinja2`) → SSTI.

If user input becomes a template string:
```python
from django.template import Template, Context
t = Template(user_input)
t.render(Context({...}))
```

— rare but devastating.

## Class 6 — Admin interface exposure

Django Admin at `/admin/`:
- Default URL.
- Often exposed publicly.
- If staff users have weak passwords or social engineering target, full database access.

Audit: is admin behind VPN / IP allowlist?

## Class 7 — Admin model-with-property privilege escalation

Custom admin actions or callable fields can be called by any staff user. If a callable mutates state:

```python
class UserAdmin(admin.ModelAdmin):
    list_display = ['name', 'become_admin']

    def become_admin(self, obj):
        obj.is_superuser = True
        obj.save()
```

A staff user clicking the "become_admin" column triggers escalation.

## Class 8 — DRF permission_classes fallthrough

```python
class MyView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        # ...

class AdminView(MyView):
    # forgot permission_classes; inherits IsAuthenticated only
    pass
```

Subclasses don't always inherit tightening; check carefully.

Common DRF mistake: `DEFAULT_PERMISSION_CLASSES = []` empty default + per-view explicit. One view missing the explicit = open.

## Class 9 — DRF serialiser create / update bypass

```python
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = '__all__'
```

`fields = '__all__'` includes `is_superuser`. POST with `is_superuser=true` = admin.

Audit: every `Meta` for `fields = '__all__'` or missing exclusions.

## Class 10 — File storage / `MEDIA_URL` traversal

Custom file storage code that derives paths from user input:

```python
def upload_path(instance, filename):
    return f"uploads/{instance.user.username}/{filename}"
```

If `filename` is attacker-controlled and contains `..`, path-traversal.

`FileField` and `ImageField` sanitise by default; custom storage may not.

## Class 11 — Django Channels (WebSocket) auth

`channels` adds WebSocket support. Authentication middleware order matters. Common mistake:
- HTTP routes require authentication.
- WebSocket consumer accepts without auth, processes messages.

Audit `routing.py` and consumer initialisation.

## Class 12 — Signed-cookie / token reuse

Django's `signing` framework signs but doesn't encrypt. Tokens visible to user. If sensitive data leaked in token, information disclosure.

Tokens also don't rotate; revocation requires re-key.

## Class 13 — Static-files served by Django in production

`runserver` serves static; `DEBUG=True` enables. Production with `DEBUG=True`:
- Stack traces with environment leak.
- SQL queries shown.
- `static()` URL pattern handles arbitrary path.

Most catastrophic mistake. Audit: `DEBUG=False` in production unequivocally.

## Audit shape

For a Django app:
1. **Settings**: `DEBUG`, `ALLOWED_HOSTS`, `SESSION_SERIALIZER`, `CACHES`.
2. **URLs**: list all routes; identify auth class per.
3. **Views**: grep for `eval`, `exec`, `subprocess`, `requests`, `Template(`.
4. **ORM**: grep for `.extra(`, `.raw(`, string interpolation in `.where(`.
5. **Serializers**: grep `fields = '__all__'`; explicit `exclude` for sensitive.
6. **Admin**: actions, callable methods.
7. **Channels**: consumer auth.
8. **Middleware**: order, custom logic.
9. **Django version** against CVE history.

## Defensive baseline

- **DEBUG=False** in production.
- **JSON session serializer** (Django default; verify).
- **Explicit serializer fields** — no `__all__`.
- **Whitelist URL patterns** — no catch-all when avoidable.
- **DRF default permissions** explicit and strict.
- **Admin** behind VPN / strong MFA.
- **Static / media** served by web server, not Django, in production.
- **`bandit`** + **`semgrep`** in CI.
- **`safety` / `pip-audit`** for dependency CVEs.

## Workflow to study

1. Use `django-DefectDojo` or Django docs vulnerable-app examples.
2. Run `bandit` on a real Django project.
3. Read Django security advisories.
4. Audit a real open-source Django project (Wagtail, Mezzanine).

## Related

- [[django-audit-patterns]]
- [[python-code-auditing]]
- [[python-dangerous-sinks]]
- [[python-deserialization]]
- [[mass-assignment]]
- [[broken-access-control]]
- [[ssrf]]
- [[ssti]]
- [[rails-advanced-audit]]

## References
- [Django security mailing list](https://www.djangoproject.com/community/mailing-lists/)
- [Django security overview](https://docs.djangoproject.com/en/stable/topics/security/)
- [`bandit`](https://github.com/PyCQA/bandit)
- [`semgrep` Django rules](https://semgrep.dev/)
- See also: [[django-audit-patterns]], [[python-dangerous-sinks]], [[rails-advanced-audit]], [[python-deserialization]]
