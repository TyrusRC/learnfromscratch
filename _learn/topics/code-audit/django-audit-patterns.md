---
title: Django audit patterns
slug: django-audit-patterns
aliases: [django-security-audit, drf-audit]
---

{% raw %}

> **TL;DR:** Django's defaults eliminate most classic bugs (ORM is parameterised, CSRF baked in, templates auto-escape). Audits target: `Raw`/`extra` ORM use, `SafeString` / `mark_safe` reaching templates, missing object-level permission in DRF, `pickle` in sessions/cache, `eval`/`exec` in admin, `ALLOWED_HOSTS=*`, and Debug Toolbar in prod.

## Common bug patterns

### 1. ORM raw queries
- `User.objects.raw("SELECT * FROM users WHERE name='%s'" % name)` → SQLi.
- `.extra(where=["name='" + name + "'"])` → SQLi.
- `connection.cursor()` then `cursor.execute(f"... {x}")` → SQLi.
- Safe: `.filter(name=x)`, `.raw("SELECT * FROM users WHERE name=%s", [name])` (parameterised).

### 2. Template injection / `mark_safe`
- Django templates auto-escape, but `{{ x|safe }}`, `mark_safe(x)`, `format_html("{}", x)` (without sub-escaping) bypass.
- `render_to_string(template_name)` with `template_name` from user input = LFI/RCE if app has writable template dirs.
- Jinja2 backend if configured (`django.template.backends.jinja2`) — different sandbox; see [[python-ssti-jinja]].

### 3. DRF object-level permissions
- `DEFAULT_PERMISSION_CLASSES` covers presence (auth, role), not object ownership.
- ViewSets need explicit `get_queryset(self)` filter to `request.user` OR `has_object_permission` on `BasePermission`. Without either, any authenticated user can fetch any object — IDOR.
- ModelViewSet `update`/`destroy` actions call `has_object_permission` only on `get_object()`; if a custom action bypasses `get_object`, no check fires.

### 4. Mass assignment in serializers
- `ModelSerializer` with `fields = '__all__'` exposes every field including `is_staff`, `is_superuser`.
- Use `fields = (...)` explicit list and `read_only_fields = (...)` for privileged ones.

### 5. Settings leaks / debug
- `DEBUG = True` in prod renders error page with full source, settings, request — leaks secret key.
- `ALLOWED_HOSTS = ['*']` allows host header attacks ([[host-header-injection]]).
- `SECRET_KEY` in `settings.py` committed to git → session forgery, password reset poisoning.
- `django-debug-toolbar` in `INSTALLED_APPS` for prod = SQL/template internals reachable if `INTERNAL_IPS` misconfigured.

### 6. Session / cache deserialization
- `SESSION_SERIALIZER = 'django.contrib.sessions.serializers.PickleSerializer'` + `SESSION_ENGINE` writable storage = RCE if session signing key leaks.
- `CACHES['default']['BACKEND'] = 'django_redis.serializers.pickle.PickleSerializer'` — same.
- Default since 1.6 is `JSONSerializer`; flag any pickle override.

### 7. Open redirect via `next`
- `LOGIN_REDIRECT_URL` overridable via `next` param; `is_safe_url`/`url_has_allowed_host_and_scheme` is the gate. Custom flows often skip it.

### 8. SSRF
- `requests.get(model.url)` with user-controlled `url`. Combine with `URLValidator` weakness — DNS rebinding ([[dns-rebinding]]).
- `django-storages` with user-controlled bucket name → SSRF via S3 SDK.

### 9. File upload
- `FileField` + `MEDIA_ROOT` served by web server can render `.html`/`.svg` → stored XSS.
- `default_storage.save(name, content)` does not sanitise `name`; path traversal possible.
- See [[file-upload]].

### 10. CSRF / CORS
- `CSRF_TRUSTED_ORIGINS` wildcard or overly broad = same-site CSRF still works.
- `django-cors-headers` `CORS_ALLOW_ALL_ORIGINS = True` + `CORS_ALLOW_CREDENTIALS = True` = wildcard credentialed CORS (browser blocks, but old clients / non-browser tools don't).

### 11. Admin exec surface
- Custom admin actions that call `eval`/`exec`/`os.system` with model field data = RCE for any staff user.
- `django-admin shell` is dev-only; flag if exposed via a custom view.

## Grep starter
```bash
rg -n '\.raw\(|\.extra\(' .
rg -n 'mark_safe|\|safe' --type=html
rg -n 'fields\s*=\s*[\x27"]__all__[\x27"]' -g 'serializers.py'
rg -n 'DEBUG\s*=\s*True|ALLOWED_HOSTS\s*=\s*\[\x27\*' settings*.py
rg -n 'SESSION_SERIALIZER|PickleSerializer'
rg -n 'requests\.(get|post)\(.*\.url|urllib\.request\.urlopen\(' .
rg -n 'SECRET_KEY\s*=\s*[\x27"]' settings*.py
```

## Tooling
- `bandit` — generic Python SAST.
- `semgrep` `python.django.security` ruleset.
- `django-check-deploy` (built-in: `python manage.py check --deploy`).
- `safety` / `pip-audit` for dep CVEs.

## References
- [Django security topic](https://docs.djangoproject.com/en/stable/topics/security/)
- [Django check --deploy](https://docs.djangoproject.com/en/stable/ref/checks/#security)
- [DRF permissions guide](https://www.django-rest-framework.org/api-guide/permissions/)
- See also: [[python-code-auditing]], [[python-dangerous-sinks]]

{% endraw %}
