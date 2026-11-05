---
title: Ruby on Rails audit patterns
slug: ruby-rails-audit-patterns
aliases: [rails-code-audit, ruby-security-audit]
---

> **TL;DR:** Rails convention-over-configuration hides a lot of implicit behavior. Audit `permit()` for mass assignment, resource routes for IDOR, ERB/HAML for `html_safe`/`raw`, `send`/`public_send` for method injection, `YAML.load` for deserialization, and `where`/`find_by` with string interpolation for SQLi.

## What it is
Auditing a Ruby on Rails application means understanding where Rails' defaults protect you (CSRF tokens, parameterized queries, output escaping) and where developers routinely bypass those defaults. Rails' magic methods and metaprogramming make certain bug classes — method injection via `send`, mass assignment, SSTI — more common than in explicit frameworks.

## Preconditions / where it applies
- Ruby on Rails source code (typically `app/`, `config/`, `Gemfile`)
- Familiarity with MVC layout: `app/controllers/`, `app/models/`, `app/views/`
- `Gemfile.lock` for dependency versions — `brakeman` for automated first pass

## Mass assignment (Strong Parameters)

Rails 4+ requires `permit` on params. The vulnerability is in what's permitted.

```ruby
# VULNERABLE — permits admin flag
def user_params
  params.require(:user).permit(:name, :email, :password, :admin)
  # Attacker sends: { user: { name: "hax", admin: true } }
end

# ALSO VULNERABLE — permit! allows everything
def user_params
  params.require(:user).permit!
end

# SECURE — explicit allowlist without sensitive fields
def user_params
  params.require(:user).permit(:name, :email, :password)
end
```

**Grep patterns:** `\.permit!`, `.permit(.*:admin`, `.permit(.*:role`, `.permit(.*:is_`. Also check for `attr_accessible` in legacy Rails 3 apps.

## IDOR in resourceful routes

Rails' `resources` macro generates RESTful routes. The controller often trusts the `:id` parameter without scoping to the current user.

```ruby
# config/routes.rb
resources :documents  # Generates /documents/:id

# VULNERABLE controller — any user can access any document
class DocumentsController < ApplicationController
  def show
    @document = Document.find(params[:id])  # No ownership check
  end

  def destroy
    Document.find(params[:id]).destroy  # Delete anyone's document
  end
end

# SECURE — scope to current user
class DocumentsController < ApplicationController
  def show
    @document = current_user.documents.find(params[:id])
    # Raises ActiveRecord::RecordNotFound if not owned
  end
end
```

**Audit approach:** For every controller action that uses `Model.find(params[:id])`, verify it's scoped through an association (`current_user.model.find`) or has an explicit authorization check (Pundit/CanCanCan policy).

## SSTI via ERB

Server-side template injection when user input is evaluated as a template.

```ruby
# VULNERABLE — user input rendered as ERB template
def render_preview
  template = params[:template]  # User-controlled
  ERB.new(template).result(binding)
  # Payload: <%= system('id') %> → RCE
end

# VULNERABLE — render inline with user input
def show
  render inline: params[:page]  # ERB evaluation
end
```

**Grep patterns:** `ERB.new`, `render inline:`, `render template:` with dynamic paths, `Liquid::Template.parse` (Liquid is safer but has its own escapes).

## Method injection via send / public_send

Ruby's `send` calls any method by name. If the method name comes from user input, it's method injection.

```ruby
# VULNERABLE — attacker controls the method name
def perform_action
  action = params[:action_name]
  @record.send(action)
  # Payload: action_name=destroy → deletes the record
  # Payload: action_name=system&args=id → if args are passed, RCE
end

# ALSO DANGEROUS — public_send only limits to public methods, still wide
@record.public_send(params[:method], params[:value])

# SECURE — allowlist
ALLOWED = %w[activate deactivate archive].freeze
def perform_action
  action = params[:action_name]
  raise "Invalid action" unless ALLOWED.include?(action)
  @record.send(action)
end
```

**Grep patterns:** `\.send(params`, `\.public_send(params`, `\.send(.*\bparams\b`, `\.try(params`.

## YAML.load deserialization

`YAML.load` in Ruby can instantiate arbitrary objects — it's the Ruby equivalent of Java deserialization or Python pickle.

```ruby
# VULNERABLE — arbitrary object instantiation
config = YAML.load(params[:config])
# Payload crafts a YAML document that instantiates ERB and calls system()

# SECURE — safe_load only allows basic types
config = YAML.safe_load(params[:config], permitted_classes: [Date, Time])

# Psych 4.0+ (Ruby 3.1+) — YAML.load is safe by default
# But older Ruby versions are still common in production
```

**Grep patterns:** `YAML.load(` (not `safe_load`), `Psych.load(`, `Marshal.load(` (binary deserialization, equally dangerous). Known gadget chains exist for pre-Psych 4.0 via `Gem::Requirement` and related classes.

## render inline and dynamic rendering

```ruby
# VULNERABLE — dynamic template path
def show
  render params[:template]
  # Attacker: template=../../../etc/passwd → path traversal / file read
  # Attacker: template=inline:<%=system('id')%> → RCE (older Rails)
end

# VULNERABLE — render file
render file: params[:path]  # Arbitrary file read
```

**Grep patterns:** `render params`, `render file:`, `render inline:`, `render template: params`.

## SQL injection via string interpolation

Rails' ActiveRecord uses parameterized queries by default, but developers bypass this with string interpolation.

```ruby
# VULNERABLE — string interpolation in where
User.where("name = '#{params[:name]}'")
# Payload: name=' OR 1=1--

# VULNERABLE — string interpolation in order
User.order("#{params[:sort]} #{params[:direction]}")
# Payload: sort=name; DROP TABLE users--

# VULNERABLE — find_by with string
User.find_by("email = '#{params[:email]}'")

# SECURE — parameterized
User.where("name = ?", params[:name])
User.where(name: params[:name])  # Hash syntax — always safe
```

**Grep patterns:** `\.where(".*#\{`, `\.order(".*#\{`, `\.find_by(".*#\{`, `\.joins(".*#\{`, `\.select(".*#\{`.

## Session store secrets

```ruby
# config/credentials.yml.enc — encrypted, SECURE if key is protected
# config/secrets.yml — older Rails, sometimes committed in cleartext!

# DANGEROUS — weak or committed secret_key_base
Rails.application.config.secret_key_base = 'abc123'
# Attacker can forge signed cookies → session hijacking, RCE via deserialization
```

If `secret_key_base` is known, an attacker can craft a valid session cookie containing a serialized Ruby object payload — leading to RCE via the cookie deserializer. See [[session-hijacking-from-source]].

**Grep patterns:** `secret_key_base`, check `config/secrets.yml` and `.env` for committed secrets. Also `config/initializers/secret_token.rb` in Rails 3.

## Rails audit checklist
1. `permit` / `permit!` — what fields are mass-assignable?
2. `Model.find(params[:id])` — scoped to current_user?
3. `html_safe`, `raw`, `<%==` — unescaped output in views?
4. `send` / `public_send` — method name from user input?
5. `YAML.load` / `Marshal.load` — unsafe deserialization?
6. `render inline:` / `render file:` / `render params[...]` — SSTI / file read?
7. `.where("...#{}")` — string interpolation in SQL?
8. `secret_key_base` — committed or weak?
9. CSRF — `protect_from_forgery` present? `skip_before_action :verify_authenticity_token` anywhere?
10. Gems — `Gemfile.lock` versions checked against `bundler-audit`?

## References
- [[java-code-auditing]] — parallel patterns in a different framework
- [[session-hijacking-from-source]] — Rails session store weaknesses
- [[xss-from-source-review]] — `html_safe` and `raw` in ERB
- [Brakeman](https://brakemanscanner.org/) — Rails static analysis
- [Rails Security Guide](https://guides.rubyonrails.org/security.html) — official security documentation
- [bundler-audit](https://github.com/rubysec/bundler-audit) — gem vulnerability scanner
