---
title: Drupal attacks
slug: drupal-attacks
---

{% raw %}

> **TL;DR:** Drupalgeddon-class form-API injection, REST/JSON:API surface, Twig SSTI in custom modules, and the long tail of contrib-module CVEs.

## What it is
Drupal is a modular PHP CMS. Attack surface splits across the core form API (where most "Drupalgeddon" bugs lived), the REST/JSON:API/GraphQL modules now standard in 9/10, the Twig templating engine, and a huge ecosystem of contributed modules that ship their own bugs.

## Preconditions / where it applies
- Drupal 7, 8, 9, or 10 instance — fingerprint via `/CHANGELOG.txt` (older), `/core/CHANGELOG.txt`, `X-Generator: Drupal N`, `/sites/default/files`, `Drupal.settings` JS blob.
- Sometimes anonymous access to the REST/JSON:API endpoints; sometimes an authenticated low-priv role.
- Outdated core or any contributed module with a published advisory at https://www.drupal.org/security.

## Technique
1. **Fingerprint and enumerate.** `droopescan scan drupal -u https://target/` lists core + module versions; manual checks at `/core/CHANGELOG.txt`, `/modules/<name>/<name>.info.yml`.
2. **CVE-2018-7600 (Drupalgeddon2).** Core form API on 7.x/8.x — `#post_render`/`#markup` properties injected via form fields render attacker PHP. Mass-exploited in the wild.

   ```http
   POST /user/register?element_parents=account/mail/%23value&ajax_form=1 HTTP/1.1
   form_id=user_register_form&_drupal_ajax=1&mail[#post_render][]=exec&mail[#type]=markup&mail[#markup]=id
   ```

3. **CVE-2019-6340 (REST module).** Unsafe deserialisation in field normalisation via REST PATCH on 8.5–8.6 — see [[deserialisation]].
4. **CVE-2018-7602.** Drupalgeddon3 — same family as 7600, requires an authenticated user.
5. **JSON:API enumeration.** `/jsonapi/node/article` and `/jsonapi/user/user` often expose data without auth; filter with `?filter[uid]=1` and similar.
6. **Twig SSTI in custom templates.** When a developer echoes user data into `{{ }}` without `|e`, you get an [[ssti]] sink — `{{ _self.env.registerUndefinedFilterCallback("exec") }}`.
7. **PHP filter / files module misuse.** If anonymous file upload is allowed and `.htaccess` is missing or weak in `sites/default/files/`, drop a `.php` (older Drupal) or chain with an LFI to evaluate it.
8. **Admin takeover via stolen session.** Drupal session cookies have the pattern `SESS<hash>`; combine with [[cross-site-scripting]] in a custom block.

## Detection and defence
- Stay on the latest minor; subscribe to security advisories and patch within the published window.
- Disable REST/JSON:API endpoints you do not use; lock those you do behind auth and per-role permissions.
- Run Drupal behind a WAF rule set that catches the Drupalgeddon `#post_render` shape; alert on `?element_parents=` and similar form-API parameter names from anon users.
- Detection: web logs with POST to `/user/register?element_parents=`; PHP error logs referencing `Drupal\Component\Render\MarkupInterface`; new PHP files appearing under `sites/default/files`.

## References
- [Drupal Security Advisories](https://www.drupal.org/security) — canonical advisory feed.
- [Drupalgeddon2 (SA-CORE-2018-002) write-up](https://research.checkpoint.com/2018/uncovering-drupalgeddon-2/) — root cause and PoC.
- [Drupal REST/JSON:API docs](https://www.drupal.org/docs/core-modules-and-themes/core-modules/jsonapi-module) — endpoints and auth.
{% endraw %}
