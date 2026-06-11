---
title: Burp Suite — practitioner primer
slug: burp-suite
aliases: [burp, burpsuite, portswigger-burp]
---
{% raw %}

Burp Suite is the default interception proxy and manual web testing workbench for almost every web pentest, OSWA/OSWE lab, and bug-bounty engagement on the planet. It shows up the moment you need to see what a browser or mobile app is actually sending, rewrite a request, or fuzz a parameter without writing your own HTTP client. The Community edition is enough to learn the workflow, but Professional unlocks the scanner, Intruder without throttling, Collaborator, and Bambdas — which together pay for themselves in a single engagement. See [[http-and-web-primer]] for the protocol fundamentals this tool assumes you already know.

## Mental model

Burp sits between your browser and the target as a man-in-the-middle TLS proxy. Every request hits the **Proxy** first, gets logged to the **HTTP history**, optionally goes to **Intercept** for manual editing, then is forwarded upstream. From history you "send to" the other tools: **Repeater** for one-off request tampering, **Intruder** for fuzzing, **Sequencer** for token entropy, **Comparer** for diffing two responses, **Decoder** for quick base64/URL/hex. **Collaborator** is an out-of-band DNS/HTTP listener used for blind injection — see [[oast-out-of-band-testing]].

```
Browser --(8080)--> Burp Proxy --(TLS)--> Target
                       |
                       +--> HTTP history --> Repeater / Intruder / Scanner
                       |
                       +--> Collaborator (OAST callbacks)
```

The crucial conceptual point: Burp's **Target Scope** drives nearly everything else — passive scan, issue logging, Logger filtering, Intruder payload position highlighting. A sloppy scope means a noisy, slow, leaky test.

## Tradecraft

**Dedicated Firefox profile.** Never proxy your daily browser. You will leak cookies into the project file and you will MITM your password manager.

```bash
firefox -no-remote -CreateProfile burp
firefox -no-remote -P burp
```

In that profile install FoxyProxy Standard with two patterns: `127.0.0.1:8080` for the target host(s), and `Direct` for everything else. This keeps Google, Sentry, telemetry, and OCSP out of your project file.

**CA certificate.** Browse to `https://burpsuite` while the proxy is up, download `cacert.der`, and import it into the Firefox profile under *Authorities* with "Trust this CA to identify websites". For Android emulators, push it to the system store (Android 14+ requires a magisk module or a rooted AVD).

**Project file convention.** One `.burp` project per engagement, stored encrypted on the engagement share. Name it `CLIENT-YYYYMMDD-scope.burp`. Use a project-specific config that disables auto-update checks and sets upstream SOCKS if you tunnel through a jump box.

**Scope discipline.** Use **Advanced scope control** with regex include rules pinned to host and port. Tick "Suppress out-of-scope logging in Proxy history" — your project file will be 10x smaller and Logger++ replays will not catch noise. For sites with embedded third-party widgets (Stripe, reCAPTCHA), explicitly *exclude* those origins.

**Match and Replace.** The fastest way to test authorisation flaws across [[cross-site-scripting]], [[sql-injection]] and [[ssrf]] payloads is to swap session tokens automatically. In *Proxy > Match and Replace*, add:

- Type: Request header, Match: `Authorization: Bearer .*`, Replace: `Authorization: Bearer <victim-jwt>`
- Type: Request header, Match: `Cookie: session=[^;]+`, Replace: `Cookie: session=<low-priv-token>`

Combined with the **Autorize** extension this gives you horizontal/vertical authz coverage with almost no manual work.

**Repeater grouping.** Pin tabs by feature (`/login`, `/api/orders/{id}`, `/admin/export`). Use *Repeater > Send group in sequence (single connection)* for race conditions — this is the modern replacement for the old Turbo Intruder race recipe.

**Intruder.** Cluster bomb for two-dimensional fuzzing (username x password), pitchfork for paired wordlists (user:hash), sniper for single position. Always set *Resource pool* with a sane concurrency limit (5-10 requests) for production targets. Use *Grep - Extract* to pull values into the results table.

**Sequencer** for any token that claims to be random — session IDs, password reset tokens, CSRF tokens. 5000 samples minimum before drawing conclusions.

**Bambdas (2024+).** Java-lambda filters that run across Proxy, Logger and Intruder. A canonical one for hunting JWTs:

```java
return requestResponse.request().hasHeader("Authorization")
    && requestResponse.request().headerValue("Authorization").startsWith("Bearer ey");
```

These replaced most one-off scripts I used to write for Logger++.

**Built-in Logger** (post-2023) replaces the Logger++ extension for 90% of cases — it logs *all* tool traffic, not just Proxy. Keep Logger++ installed only if you need its colour-coded filters or CSV export.

**Day-one extensions** (BApp store):

- Autorize — authz matrix testing
- JWT Editor — sign/resign/none-algorithm JWTs
- Hackvertor — tag-based encoding chains (`<@base64><@urlencode>payload<@/urlencode><@/base64>`)
- Param Miner — finds hidden parameters and cache-key oddities
- Backslash Powered Scanner — augments the active scanner with input transformation discovery
- Burp Bounty — custom active/passive rules from YAML
- Collaborator Everywhere — auto-injects OAST payloads into common headers

**Inspector** (the panel that replaced the old Params tab) edits cookies, headers, JSON and form params inline with live re-encoding. Learn its keyboard shortcuts — it is faster than hand-editing raw requests.

**Caido** is an emerging Rust-based alternative with a project-aware UI and a much lighter footprint; worth knowing for long engagements where Burp's JVM gets sluggish. See [[caido]].

## Detection and telemetry

Defenders see Burp very clearly if you do not tune it:

- WAF/CDN logs: `User-Agent` contains nothing unusual by default, but the *Active Scanner* fires hundreds of probes per endpoint with telltale strings (`<script>alert(1)`, `' OR 1=1--`, `${jndi:`, Collaborator subdomains like `abc123.oastify.com`).
- Web server access logs: bursts of identical paths with varied query strings, 4xx spikes, and the Collaborator polling domain in response bodies that get reflected.
- EDR on the tester host: `java.exe`/`burpsuite_pro` opening many outbound TCP sessions and a listener on `127.0.0.1:8080`.
- DNS telemetry: every Collaborator interaction is a DNS query to `*.oastify.com` (or your private Collaborator server) — trivially alertable.

Hunt queries defenders run against you (Splunk-ish):

```
index=web sourcetype=access_combined
| stats count by src_ip uri_path
| where count > 500
```

```
index=dns query="*.oastify.com" OR query="*.burpcollaborator.net"
```

Run a **private Collaborator** server on a domain you control for any engagement where OAST attribution matters.

## OPSEC pitfalls

- **Never** proxy LastPass, Bitwarden, 1Password, banking, or SSO IdP flows. Add them as FoxyProxy *direct* exceptions and as Burp scope *excludes*. Project files have been subpoenaed.
- Turn off the **passive and active scanner** on bug-bounty programs that prohibit automated scanning (HackerOne and Bugcrowd flag this in policy). Use Repeater + manual Intruder instead.
- Respect concurrent-request caps in scope letters. The *Resource pool* setting is per-tool — set it once globally.
- Do not commit `.burp` project files to git. They contain credentials, JWTs, and session cookies in plaintext-equivalent form.
- Update Burp every release cycle — the *Active Scan* payloads change, and old versions have shipped vulnerable Chromium embedded browsers.

## References

- https://portswigger.net/burp/documentation/desktop
- https://portswigger.net/web-security (PortSwigger Web Security Academy)
- https://portswigger.net/burp/documentation/desktop/tools/proxy/configuring-browsers
- https://portswigger.net/bappstore
- https://portswigger.net/burp/documentation/desktop/tools/bambdas
- https://caido.io/

See also: [[http-and-web-primer]], [[oast-out-of-band-testing]], [[caido]], [[cross-site-scripting]], [[sql-injection]], [[ssrf]], [[oswa-roadmap]], [[oswe-roadmap]]
{% endraw %}
