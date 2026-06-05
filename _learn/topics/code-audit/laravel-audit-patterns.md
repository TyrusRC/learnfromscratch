---
title: Laravel audit patterns
slug: laravel-audit-patterns
aliases: [laravel-security-audit]
---

{% raw %}

> **TL;DR:** Laravel's Eloquent ORM is mostly safe; the bugs hide in `DB::raw`/`whereRaw`, mass assignment via missing `$fillable`/`$guarded`, Blade `{!! !!}` unescaped echoes, `unserialize` on session/cache, `APP_KEY` leak, debug endpoints (Telescope/Horizon/Ignition), and SSRF via `Http::get` user input. CVE-2021-3129 (Ignition + debug = RCE) is the modern poster child.

## Common bug patterns

### 1. SQL injection via raw helpers
- `DB::raw("name = '$name'")` → SQLi.
- `User::whereRaw("name = '" . $name . "'")` → SQLi.
- `User::orderBy($request->sort)` — order-by SQLi (column name not parameterised, validated against allowlist?).
- `whereColumn`, `where` first-arg as raw expression — read carefully.
- Safe: `User::where('name', $name)`, `whereRaw('name = ?', [$name])`.

### 2. Mass assignment
- Models default to `$fillable = []` (protected). But many devs set `$guarded = []` (allow all) — that's mass-assign-anything.
- `User::create($request->all())` with `$guarded = []` → attacker sets `is_admin`. Use `$request->validated()` (with FormRequest) or explicit array.
- `Model::forceFill(...)` bypasses guards entirely; audit anywhere it's used with request data.

### 3. Blade unescaped echo
- `{{ $x }}` escapes. `{!! $x !!}` does not — XSS surface.
- `@php` blocks execute PHP — audit for user input concatenation.
- Custom Blade directives via `Blade::directive` are templates compiled to PHP — if directive logic embeds user input into compiled output, SSTI.

### 4. Session / cookie deserialization
- Default Laravel session driver `cookie` encrypts via `APP_KEY` then `unserialize`s on decrypt. If `APP_KEY` leaks (env file in repo, `.env.example` mistake, debug page), attacker crafts cookie → `unserialize` → POP chain → RCE.
- See [[php-deserialization-gadgets]].

### 5. `APP_KEY` leak chains
- `.env` file in webroot (misconfigured nginx/Apache).
- `php artisan tinker` exposed (no).
- Ignition debug error page (CVE-2021-3129) leaks env via "Make Variable Optional" feature → leak `APP_KEY` → forge session cookie → POP → RCE.
- Check `.env`/`.env.local` in `git log -- .env*` and CI logs.

### 6. Debug / admin packages
- `laravel/telescope` in prod with unauthenticated access — leaks every request, every job, every Redis command, every mail.
- `laravel/horizon` `/horizon` UI same risk.
- `barryvdh/laravel-debugbar` in prod = SQL queries + bindings on every page.
- `facade/ignition` <2.5.2 = RCE (CVE-2021-3129).

### 7. SSRF
- `Http::get($url)`, `Http::withBody(...)->post($url)` with user-controlled `$url`. No SSRF guard in stdlib.
- `Guzzle` direct use — same. Add IP allowlist via custom `Handler`.
- File preview endpoints that fetch URLs server-side are the classic SSRF surface in Laravel apps.

### 8. File upload
- `$request->file('img')->store('uploads')` keeps original extension; rename via hash + validate MIME via `mimes:jpeg,png` rule, not extension.
- `storage:link` exposes `storage/app/public` to webroot → user uploads served. If MIME is text/html or svg → stored XSS.

### 9. Authorization gaps
- Policies via `Gate::define` or `Policy` classes are opt-in per route. `$this->authorize(...)` must be called in the controller — missing = no check.
- `Route::resource` doesn't auto-call policies; FormRequest authorization (`authorize(): bool`) is per-request, not per-resource.

### 10. Eloquent IDOR
- `User::find($id)` returns any matching row regardless of ownership. Pair with policy or `where('owner_id', auth()->id())`.
- Route-model binding (`function (Post $post)`) skips ownership; add `$this->authorize('view', $post)`.

### 11. Queue serialization
- Jobs serialised to queue via `serialize()`; cookie/session same. If queue worker reads from untrusted source (cross-tenant Redis) → POP chain.

### 12. `Storage::disk('s3')->url(...)` SSRF
- AWS SDK creates presigned URL when configured; not a direct sink, but `getObject` with user-controlled key can list outside intended prefix if `prefix` not constrained.

## Grep starter
```bash
rg -n 'DB::raw|whereRaw|havingRaw|orderByRaw|selectRaw' .
rg -n '\$guarded\s*=\s*\[\]|->forceFill\(' .
rg -n '\{!!.*\$|\{!!.*\$request' resources/views
rg -n 'APP_DEBUG\s*=\s*true|debugbar|telescope|horizon|ignition' .
rg -n 'Http::(get|post|put|delete)\(\s*\$request->' .
rg -n 'unserialize\(|serialize\(.*\$request' .
```

## Tooling
- Larastan (PHPStan for Laravel).
- Enlightn Security Checker — Laravel-specific.
- `composer audit` (Composer 2.4+).
- Snyk has good Laravel CVE coverage.

## References
- [Laravel security topic](https://laravel.com/docs/security)
- [Enlightn](https://www.laravel-enlightn.com/) — opinionated security audit
- [Spatie research blog](https://spatie.be/) — Laravel package security writeups
- [CVE-2021-3129 — Ignition RCE writeup (AmbionicsLabs)](https://www.ambionics.io/blog/laravel-debug-rce)
- See also: [[php-code-auditing]], [[php-deserialization-gadgets]], [[php-magic-methods]]

{% endraw %}
