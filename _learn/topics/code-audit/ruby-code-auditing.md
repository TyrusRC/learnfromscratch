---
title: Ruby code auditing
slug: ruby-code-auditing
aliases: [rails-audit, ruby-source-review]
---

{% raw %}

> **TL;DR:** Ruby audits in 2026 are 95% Rails. The bug families: mass assignment, unsafe deserialization (Marshal/YAML/JSON with class instantiation), Rails-specific `ActiveSupport::MessageVerifier` key leaks, `render` with user input, SQLi via `find_by_sql`/`where` strings, command injection via backticks/`Kernel.system`. Cross-link [[ruby-deserialization-audit]] for the heavy chain detail.

## What it is
Rails ergonomics are the audit's both ally and enemy. Strong defaults (parameterised AR queries, CSRF baked in, escaping by default) eliminate whole bug classes. But the convenience methods (`find_by_sql`, `where("name = '#{x}'")`, `render file: x`) sit one keystroke away from RCE/SQLi/LFI. Non-Rails Ruby (Sinatra, Hanami, plain Rack) lacks the defaults entirely.

## Preconditions / where it applies
- Source (Gemfile, app/, config/routes.rb)
- Rails major version — secret_key_base handling, `Marshal` in cookies (<5.2), `ActiveSupport::MessageVerifier` shape
- Knowledge of metaprogramming (`send`, `public_send`, `eval`-family, `instance_eval`, `class_eval`, `define_method`)

## Technique
1. **Map entry points.**
   - Rails: `config/routes.rb` — `resources`, `get/post/match`, mounted engines.
   - Sinatra: `get '/path' do ... end`.
   - Grape API: `class API < Grape::API; resource :foo; get :bar`.
2. **Trace sources.** Rails `params`, `cookies`, `session`, `request.headers`. Strong parameters (`params.require(:user).permit(:name)`) is the mass-assignment guard — any controller using `params[:user]` directly or `permit!` is suspect.
3. **Sink catalogue.**
```bash
rg -n '\beval\(|instance_eval\(|class_eval\(|module_eval\(|binding\.eval' .
rg -n 'Marshal\.(load|restore)\(' .
rg -n 'YAML\.(load|unsafe_load|load_stream)\(' .                  # safe: YAML.safe_load
rg -n 'JSON\.load\(' .                                            # JSON.load can instantiate; use JSON.parse
rg -n 'send\(\s*params|public_send\(\s*params' .                  # method-name from input
rg -n '`[^`]*#\{|system\(.*#\{|exec\(.*#\{|spawn\(.*#\{|IO\.popen\(.*#\{' .
rg -n 'find_by_sql|where\([^)]*#\{|order\([^)]*#\{|group\([^)]*#\{' .  # SQLi
rg -n 'render\s*(?:file|inline|template):\s*params|redirect_to\s+params' .
rg -n 'constantize|safe_constantize' .                            # arbitrary class lookup
rg -n 'open\(\s*params|URI\.open|Net::HTTP\.get\(\s*params' .     # SSRF / open() shell-pipe
```
4. **Mass assignment.** Strong params is opt-in. Any controller calling `User.create(params)` or `update_attributes!(params[:user])` without `.permit(...)` is mass-assignment. Look for `permit!` (wildcard permit) — common in admin controllers, often shipped to users by accident.
5. **Marshal.** `Marshal.load` on any byte string under attacker control is RCE — gadget chains include AR, Rake, Gem::Requirement. Rails <5.2 stored session as Marshal-encoded cookie; if `secret_key_base` leaks (heroku misconfig, env in repo), full RCE via cookie forgery.
6. **YAML.** `YAML.load` on attacker input instantiates Ruby objects → RCE via Psych gadgets (`Gem::Specification`, `ERB`, `ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy`). Use `YAML.safe_load`. Note: Psych 4 changed default — `YAML.load` now calls `safe_load` on Ruby 3.1+. Audit version.
7. **`send` abuse.** `obj.send(params[:method])` = arbitrary method call including `:eval`, `:system`. Even `public_send` reaches private methods via `__send__` re-exposure in some patterns.
8. **SQLi.** AR is safe with hash conditions: `User.where(name: x)`. String conditions with interpolation are not: `User.where("name = '#{x}'")` or `User.find_by_sql("... #{x}")`. `order(params[:sort])` is SQLi if value used as raw SQL (no whitelist of column names).
9. **Open redirect / SSRF.** `redirect_to params[:next]` → open redirect. `open(params[:url])` in Ruby <2.7 invoked subprocess on URL starting with `|` — RCE. Use `URI.parse` + scheme allowlist.
10. **Render confusion.** `render file: params[:f]` reads any file (LFI). `render inline: params[:t]` is ERB → RCE. `render template: ...` looks up by name but `..` segments traverse.
11. **constantize.** `params[:type].constantize` returns the class — combined with `.new(params)` is mass-assign-anything + arbitrary-class-instantiation. Use a hash whitelist.
12. **CSRF.** Default ON for non-API; `protect_from_forgery` per-controller. APIs often `skip_before_action :verify_authenticity_token` — verify they use token auth not cookies.
13. **Sessions and cookies.** Check `config/initializers/session_store.rb` and Rails secrets: `Rails.application.secrets.secret_key_base` exposure = full session forgery. Cookie serializer should be `:json`, not `:marshal`.

## Detection and defence
- Brakeman — Rails-specific SAST, the de-facto audit tool. Run in CI; treat warnings as blockers.
- `bundle audit` (or `bundler-audit`) for CVE deps.
- Semgrep `ruby.rails.security`.
- For SQLi: forbid string-form `where` via a Rubocop rule; require hash form.
- Rotate `secret_key_base` on any suspicion of leak; old sessions/cookies become invalid (intended).

## References
- [Brakeman](https://brakemanscanner.org/) — primary tool
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [HackTricks — Ruby on Rails](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/ruby-on-rails.html)
- [Universal Deserialization Gadget for Ruby (Trail of Bits)](https://blog.trailofbits.com/2024/02/27/the-life-and-death-of-the-universal-deserialization-gadget-for-ruby/)
- See also: [[ruby-deserialization-audit]], [[rails-audit-patterns]], [[parser-differential-saml-ruby]]

{% endraw %}
