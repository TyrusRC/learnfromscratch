---
title: Ruby Deserialization Audit
slug: ruby-deserialization-audit
---

> **TL;DR:** Auditors look for `Marshal.load`, `YAML.load`/`YAML.unsafe_load`, ERB on user input, and any Rails app whose `secret_key_base` has leaked — because each gives the attacker an arbitrary Ruby object graph, and Rails ships gadget chains that turn that into RCE.

## What it is
Ruby's `Marshal` and `Psych` (YAML) deserialisers will instantiate arbitrary classes and call methods like `init_with` or `marshal_load` during reconstruction. Rails extends the blast radius: signed cookies and `ActiveSupport::MessageVerifier` payloads are `Marshal`-encoded by default, so a leaked `secret_key_base` is equivalent to RCE. ERB templates rendered from user input are another classic SSTI sink that auditors must trace from controllers and mailers.

## Preconditions / where it applies
- Ruby 3.x, Rails 5–7, Sinatra, Sidekiq, dRuby
- Sinks live in session/cookie stores, cache layers (`Rails.cache.fetch`), background job arguments, and admin reporting features
- Safe-looking patterns: `YAML.load(File.read(path))`, `Marshal.load(redis.get(key))`, `ERB.new(params[:tmpl]).result(binding)`

## Technique
```ruby
# 1. Marshal.load on attacker-controlled bytes — Universal RCE gadget
data = Base64.decode64(params[:state])
state = Marshal.load(data) # any object with marshal_load can run code

# 2. YAML.load (pre-Psych-4) instantiates arbitrary classes
require 'yaml'
YAML.load(request.body.read) # payload uses !ruby/object:Gem::Installer

# 3. Rails cookie forgery after secret_key_base leak
# Attacker re-signs a Marshal payload with the leaked key:
verifier = ActiveSupport::MessageVerifier.new(secret, serializer: Marshal)
cookie   = verifier.generate(evil_object) # paste into session cookie

# 4. ERB SSTI in a reporting endpoint
require 'erb'
ERB.new(params[:report]).result(binding)
# payload: <%= `id` %>
```

## Detection and defence
- Semgrep: `ruby.lang.security.dangerous-yaml-load`, `ruby.lang.security.marshal-load`, `ruby.rails.security.dangerous-eval`
- Brakeman warnings: `UnsafeDeserialization`, `UnsafeReflection`, `Evaluation`
- Replace with `YAML.safe_load(input, permitted_classes: [Date])`, `JSON.parse`, and signed JWTs over `Marshal` payloads
- Rotate `secret_key_base` via `bin/rails credentials:edit` if leak suspected, force-expire sessions, and configure `Rails.application.config.action_dispatch.cookies_serializer = :json`
- Never call `ERB.new` on request data — pre-render fixed templates with locals

## References
- [Rails security guide](https://guides.rubyonrails.org/security.html) — cookie + secret_key_base section
- [Psych 4 release notes](https://github.com/ruby/psych/releases) — `load` vs `unsafe_load` change
- [Brakeman documentation](https://brakemanscanner.org/docs/warning_types/) — warning catalogue

See also: [[source-sink-flow-analysis]], [[dangerous-java-sinks]], [[python-dangerous-sinks]].
