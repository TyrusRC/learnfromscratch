---
title: PHP code auditing
slug: php-code-auditing
---

{% raw %}

> **TL;DR:** Map routes → controllers, grep for the dangerous-sink catalogue, then check sanitisation. Pay attention to PHP-specific quirks: loose comparison, type juggling, magic methods, phar streams, and framework-level deserialisation.

## What it is
PHP code reviews are dominated by a small set of bug patterns — RCE via `eval` / `include` / `unserialize`, command exec via `system`-family, SQLi via concatenated queries, and auth bypass via type juggling. Modern frameworks (Laravel, Symfony, WordPress) layer their own helpers on top, each with its own sink subset.

## Preconditions / where it applies
- PHP source (preferred) or a packed phar — `php -d phar.readonly=0 -r 'extract phar'` or `phar extract -f`
- Knowledge of framework routing — Laravel `routes/web.php`, Symfony `config/routes.yaml`, WordPress `add_action('wp_ajax_*')` and `admin_ajax.php`
- PHP version — many sinks behave differently across 5.x → 7.x → 8.x (e.g. `preg_replace /e` removed in 7.0; `assert` no longer evaluates strings in 8.0)

## Technique
1. **Locate entry points.** WordPress: `*_ajax_*`, `rest_api_init` callbacks, shortcodes. Laravel: `routes/*.php`, controller actions, middleware. Symfony: `#[Route]` attributes. Raw apps: front controller `index.php` + `.htaccess` rewrites.
2. **Trace sources.** `$_GET`, `$_POST`, `$_COOKIE`, `$_REQUEST`, `$_SERVER` (especially `HTTP_*` headers), `php://input` (raw body), uploaded file paths/names. Framework wrappers — `Request::input`, `request()->all()`, `$_REQUEST` mirrors.
3. **Grep the sink catalogue** in [[dangerous-php-sinks]]. Quick top-priority list:
```bash
grep -RnE 'eval\(|assert\(|preg_replace\(.*"/.*e[^"]*"|create_function\(' .
grep -RnE 'system\(|exec\(|passthru\(|shell_exec\(|popen\(|proc_open\(|`[^`]*\$' .
grep -RnE '(include|require)(_once)?\s*\(\s*\$' .
grep -RnE 'unserialize\(' .
grep -RnE 'extract\(|parse_str\(' .
grep -RnE 'file_get_contents\(\s*\$|file_put_contents\(\s*\$|fopen\(\s*\$' .
```
4. **Check sanitisers.** `htmlspecialchars` is XSS-only; `addslashes` is SQLi-incomplete (DB charset matters); `escapeshellcmd` does *not* prevent arg injection; `realpath` returns false on non-existent paths (often used as bypass). `intval` is the safest cast.
5. **Type-juggling bugs.** `==` compares with juggling: `"0e123" == "0e456"` is true (both parse as 0), `"abc" == 0` true on PHP < 8.0. Look at password and token comparisons:
```php
if ($_GET['token'] == $real_token) { ... }   // bypass with token=0
if (strcmp($pw, $stored) == 0) { ... }       // strcmp(array, str) returns null
```
6. **Magic methods.** `__wakeup`, `__destruct`, `__toString`, `__call`, `__get` execute during deserialisation — see [[php-magic-methods]] and [[php-deserialization-gadgets]].
7. **Phar streams.** Pre-PHP 8.0, any filesystem call on `phar://x.phar/foo` (incl. `file_exists`, `filesize`, `stat`, `is_file`) triggers metadata deserialisation. Audit anywhere a user-supplied path reaches stream functions.
8. **Framework specifics.**
   - **WordPress:** missing capability check after `check_ajax_referer`; `wp_unslash` ≠ sanitiser; option name passed to `update_option` from request.
   - **Laravel:** `DB::raw`, `whereRaw` with concat; `Blade::raw`, `{!! !!}` unescaped echo; mass-assignment via `$fillable` missing.
   - **Symfony:** Twig `{{ user_input|raw }}`; `Process` with shell-style string.
9. **Static analysers.** Psalm, PHPStan + `phpstan-strict-rules`, RIPS / Phortify (commercial), Semgrep `php.lang.security`, Snuffleupagus for runtime mitigation.

## Detection and defence
- `disable_functions` for unused dangerous APIs; `allow_url_include=Off`, `allow_url_fopen=Off`
- Switch all queries to PDO with `?` placeholders; reject string concat in PRs via Semgrep
- Use `hash_equals($a,$b)` and `password_verify` instead of `==` for secret comparison
- On PHP 8+: phar stream wrapper no longer auto-deserialises; backport via `Phar::interceptFileFuncs` removed — upgrade to 8.x
- Run Snuffleupagus or Suhosin in production to catch unknown sinks at runtime

## References
- [HackTricks — PHP tricks](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/php-tricks-esp/index.html) — bypass and audit notes
- [PHP manual — security](https://www.php.net/manual/en/security.php) — official guidance
- [Psalm](https://psalm.dev/) and [PHPStan](https://phpstan.org/) — static analysis
- [PayloadsAllTheThings — PHP](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/PHP%20Juggling) — payload corpus
{% endraw %}
