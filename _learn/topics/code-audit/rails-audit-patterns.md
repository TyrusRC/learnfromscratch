---
title: Rails audit patterns
slug: rails-audit-patterns
aliases: [ruby-on-rails-security-audit]
---

{% raw %}

> **TL;DR:** Rails defaults handle CSRF, XSS escaping, and parameterised AR queries — bugs cluster around `find_by_sql`/string `where` interpolation, `permit!` (wildcard mass-assign), `render file:`/`inline:` with params, `Marshal`/`YAML.load` on session/cache, `send`/`constantize` with attacker input, and exposed admin endpoints. Brakeman is the canonical tool.

## Common bug patterns

### 1. SQL injection via string conditions
```ruby
User.where("name = '#{params[:name]}'")        # SQLi
User.find_by_sql("SELECT * FROM users WHERE name='#{params[:name]}'")  # SQLi
User.order(params[:sort])                       # SQLi if value used raw as column expression
User.where("name = ?", params[:name])           # SAFE
User.where(name: params[:name])                 # SAFE
```
Rails 7+ `sanitize_sql_array` helps but doesn't auto-apply to user code; audit every `find_by_sql`, every string-form `where`, every `order(params[...])`.

### 2. Mass assignment / strong params
- `User.create(params[:user])` without `permit` → blocked by `ActionController::Parameters` default (raises ForbiddenAttributesError).
- `params.require(:user).permit!` — wildcard permit; mass-assign all attributes (including `admin`, `password_digest`).
- `params.require(:user).permit(:name, attributes: {})` empty-hash trick allows everything inside `attributes`.
- Audit every `permit` call; flag `permit!` and bare `permit(:nested => {})` patterns.

### 3. Render abuse
- `render file: params[:f]` → LFI ("../" allowed).
- `render inline: params[:t]` → ERB on attacker input → RCE.
- `redirect_to params[:url]` → open redirect (`url_for` + allowlist required).

### 4. `send`/`public_send` with params
- `obj.send(params[:m])` — arbitrary method on `obj`. Even constrained models reach `:eval`, `:system`, `:exec` via Object base methods.
- `params[:type].constantize.new(params[:user])` — arbitrary class instantiation + mass-assign. Common in admin panels.

### 5. Marshal / YAML deserialization
- `Marshal.load(cookies[:session])` (old Rails or custom session) → RCE on attacker cookie.
- `YAML.load(params[:config])` instantiates Ruby objects → RCE via Psych gadgets (`Gem::Specification`, etc.). On Ruby 3.1+ Psych 4 default `load` calls `safe_load`; flag explicit `YAML.unsafe_load`.
- `secret_key_base` leak → session forgery (cookie signed). Rotate immediately on suspected leak.

### 6. `Rails console`/`web-console` in prod
- `web-console` gem in `development` group only — but check `Gemfile.lock` resolution and Rails environment. `RAILS_ENV=production` with web-console mounted = unauthenticated console.
- `/rails/info/routes` exposes all routes if not gated.

### 7. CSRF gaps
- `protect_from_forgery with: :exception` is default. API controllers often `skip_before_action :verify_authenticity_token` — fine only if token auth is used (no cookies), risky if mixed.
- `protect_from_forgery with: :null_session` returns empty session on failure; the route still executes.

### 8. Active Storage / file upload
- `params[:image]` direct upload — no MIME validation unless added.
- `serve` action serves file at user-provided path → traversal.
- Content-Disposition default `inline` → stored XSS via SVG/HTML upload.

### 9. JSON / API
- `JSON.load(body)` instantiates objects → use `JSON.parse`.
- Active Model Serializers / Jbuilder typically safe; flag any `as_json(only: params[:fields])` where user picks fields they shouldn't see.

### 10. Devise / Doorkeeper / authentication
- `devise_for :users` ships login/reset/registration routes; audit `password_reset_token` lifetime, `confirmable` callback chain.
- `Doorkeeper.configure` — check PKCE required, `force_pkce`, allowed scopes; missing PKCE on public clients = OAuth code injection ([[oauth-authorization-code-injection]]).

### 11. ActiveRecord callback side-effects
- `after_save :send_email` runs synchronously; if mailer hits external URL with user-controlled fields → SSRF chain.
- `before_destroy` with `dependent: :destroy` cascade — audit for orphan removal of resources outside ownership scope.

### 12. CVE history to look for
- CVE-2019-5418 (file disclosure via render with Accept header) — Rails ≤5.2.
- CVE-2020-8163 (RCE in dev with `web-console`).
- CVE-2022-23633 (race in Action Pack session).
- Rails Doorkeeper CVEs (OAuth flow bugs).

## Grep starter
```bash
rg -n 'find_by_sql|where\("[^"]*#\{|order\(\s*params|select\("[^"]*#\{' .
rg -n 'permit!|attributes: \{\}|merge\(params' app/controllers
rg -n 'render\s+(file|inline):\s*params|redirect_to\s+params' .
rg -n 'send\(\s*params|public_send\(\s*params|constantize' .
rg -n 'Marshal\.load|YAML\.(load|unsafe_load)' .
rg -n 'mount\s+\w+::Engine.*=>\s*[\x27"]/' config/routes.rb   # mounted apps
```

## Tooling
- **Brakeman** — Rails-specific SAST. Run in CI; treat warnings as P2 minimum.
- `bundle audit` (or `bundler-audit`) — CVE deps.
- `rubocop-rails` + `rubocop-rails-omakase` — style + some security lints.
- Semgrep `ruby.rails.security` ruleset.

## References
- [Brakeman](https://brakemanscanner.org/)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [OWASP — Rails cheatsheet](https://cheatsheetseries.owasp.org/cheatsheets/Ruby_on_Rails_Cheat_Sheet.html)
- See also: [[ruby-code-auditing]], [[ruby-deserialization-audit]]

{% endraw %}
