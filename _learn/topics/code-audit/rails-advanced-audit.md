---
title: Rails advanced audit
slug: rails-advanced-audit
aliases: [rails-deep-audit, ruby-on-rails-advanced]
---

> **TL;DR:** Beyond the basics of [[rails-audit-patterns]], advanced Rails audit looks at: mass-assignment via deep nested attributes, Strong Parameters bypass via type confusion, ActiveRecord SQL injection via array / hash arguments, view helper XSS via `html_safe`, `instance_variable_get` reflection abuse, ActiveJob deserialisation via GlobalID, Rack middleware bypass, and Rails-specific framework CVEs (e.g., CVE-2024-41128 reset-password class). Companion to [[rails-audit-patterns]] and [[ruby-deserialization-audit]].

## Why advanced

Rails core CVE history is long and recurring. Modern Rails apps continue to ship deserialisation issues, mass-assignment, and ActiveRecord SQL injection in real codebases.

## Class 1 — Nested attributes mass-assignment

```ruby
class User < ApplicationRecord
  has_many :roles
  accepts_nested_attributes_for :roles
end

# Controller
params.require(:user).permit(:name, roles_attributes: [:name, :id])
```

Strong Parameters permits `roles_attributes`. Attacker:
```json
{"user": {"name": "X", "roles_attributes": [{"id": 5, "name": "admin"}]}}
```

If Role has an `admin` boolean attribute also permitted, attacker becomes admin.

Subtler: deep nesting (`comments_attributes` → `replies_attributes` → ...) where the developer didn't anticipate.

Audit: every `permit` clause; every `accepts_nested_attributes_for`.

## Class 2 — Strong Parameters bypass via type confusion

`permit` returns parameters that match expected shape. If developer does:
```ruby
params.permit!  # permit everything
params[:user].permit!  # permit all user fields
```

Or:
```ruby
params.require(:user).permit(:name, :role => [:name, :level])
# Hash with key :role permitted; but attacker sends Array
```

Type-confusion bypass.

## Class 3 — ActiveRecord SQL injection

Strings to `where`, `order`, `having`, `joins` parameters:

```ruby
User.where("name = '#{params[:name]}'")          # classic
User.order(params[:sort])                          # ORDER BY injection
User.joins("INNER JOIN orgs ON #{params[:cond]}")  # JOIN injection
```

Also array arguments to scope:
```ruby
User.where(role: params[:role])  # if params[:role] is Hash, exposes attribute filter abuse
```

Or `find_by_sql` directly.

## Class 4 — View XSS via html_safe / raw

```erb
<%= @user.bio.html_safe %>
<%= raw @user.bio %>
<%== @user.bio %>
```

All three bypass auto-escaping. If `bio` is attacker-supplied, XSS.

Common audit pattern: grep `html_safe`, `raw`, `<%==`.

## Class 5 — instance_variable_get reflection abuse

```ruby
def show
  obj = controller.instance_variable_get("@#{params[:var]}")
end
```

If params[:var] is user-controlled and matches an instance variable, attacker reads arbitrary controller state.

## Class 6 — ActiveJob / GlobalID deserialisation

GlobalID locates ActiveRecord objects by URI. If a job is enqueued with `GlobalID::Locator.locate(user_input)`:

```ruby
GlobalID::Locator.locate("gid://app/User/1")
```

attacker can locate arbitrary records. Worse, malformed GlobalID can trigger model methods (`find` doing dangerous things, callbacks).

ActiveJob arguments serialised via JSON or Marshal — Marshal is RCE if user controls.

## Class 7 — Marshal / YAML deserialisation

Ruby `Marshal.load(user_input)` = RCE.
`YAML.load(user_input)` historically dangerous; modern `YAML.safe_load` is safe but many older codebases use `YAML.load`.

See [[ruby-deserialization-audit]].

## Class 8 — Rack middleware bypass

Custom middleware before authentication. If middleware processes raw env / path:
- Path normalisation differs from later middleware.
- Auth applied based on path mismatch.

Same class as [[nextjs-middleware-cve-2025-29927]] but Rails-side.

## Class 9 — Rails-internal CVEs (recent)

- **CVE-2024-41128** — Rack reset-password timing class.
- **CVE-2024-26143 / 26144** — Action Controller flaws.
- **CVE-2023-22796** — regex DoS in ActiveSupport.
- **CVE-2022-44566** — Active Record column-type confusion.

Subscribe to Rails security mailing list.

## Class 10 — Active Storage signed URL bypass

Active Storage uses signed URLs for direct uploads. Bypass:
- Signature truncation.
- Algorithm confusion (HS256 vs RS256-style; Rails uses HMAC but version matters).

## Class 11 — ActiveRecord callback abuse via mass-assignment

If a model has `before_save :do_thing` and `do_thing` checks a flag, and the flag is mass-assignable:

```ruby
class Post
  before_save :publish_immediately, if: :force_publish

  def publish_immediately
    self.published_at = Time.now
    self.notify_subscribers
  end
end

# Controller permits :force_publish
```

Attacker forces publish via mass-assignment.

## Class 12 — Helper methods reaching ActiveRecord

```erb
<%= image_tag @user.avatar_url %>
```

If `avatar_url` triggers a database query via `ActiveStorage::Service::DiskService` and user-controlled, SSRF possible.

## Audit shape

For a Rails app:
1. List all controllers + actions.
2. For each action, identify all `permit` clauses.
3. List all `accepts_nested_attributes_for`.
4. Grep for `raw`, `html_safe`, `<%==`, `<%=='`.
5. Grep for SQL-passing methods: `find_by_sql`, `where("...")`, `order(...)`, `having(...)`, `joins(...)`.
6. Grep for `Marshal.load`, `YAML.load`, `JSON.load`.
7. List middleware order; identify auth boundary.
8. Check Rails version against CVE history.

## Defensive baseline

- **Strong Parameters** with explicit permit.
- **Symbol vs String** keys care.
- **`safe_load` for YAML**.
- **No `Marshal.load`** of user data.
- **Parametrised SQL** everywhere; no string interpolation.
- **No `raw` or `html_safe`** on user content.
- **Rails version current**.
- **brakeman** in CI.
- **bundler-audit** in CI.

## Workflow to study

1. Install brakeman; scan a sample Rails app.
2. Read recent Rails CVE writeups.
3. Audit a real open-source Rails project (Mastodon, Discourse — large codebases).
4. Read Justin Searls / Hack Education etc. — Rails security commentary.

## Real-world incidents

- **Rails serialisation / RCE** historic mass-exploitation.
- **GitHub** has reported and fixed Rails class issues (they're a major Rails user).
- **Various startups** — recurring Strong Parameters mistakes.

## Related

- [[rails-audit-patterns]]
- [[ruby-code-auditing]]
- [[ruby-deserialization-audit]]
- [[mass-assignment]]
- [[broken-access-control]]
- [[sql-injection]]
- [[cross-site-scripting]]
- [[django-advanced-audit]]

## References
- [Rails security mailing list](https://groups.google.com/g/rubyonrails-security)
- [Brakeman](https://brakemanscanner.org/)
- [bundler-audit](https://github.com/rubysec/bundler-audit)
- [Rails CVE history](https://www.cvedetails.com/vendor/12043/Rubyonrails.html)
- [Justin Searls — Rails security talks](https://twitter.com/searls)
- See also: [[rails-audit-patterns]], [[ruby-code-auditing]], [[mass-assignment]], [[django-advanced-audit]]
