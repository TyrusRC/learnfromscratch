---
title: PHP magic methods as sinks
slug: php-magic-methods
---

> **TL;DR:** PHP's `__wakeup`, `__destruct`, `__toString`, `__call`, `__get`, `__set`, `__invoke` are auto-invoked by the runtime — they're the entry hooks every POP chain uses to transform a deserialised object graph into method calls and eventually RCE.

## What it is
Magic methods are special class methods that PHP calls implicitly on certain events — object construction from a stream, casting to string, method/property access on unknown names, invocation of an object like a function. When attackers control object data via `unserialize`, the first instruction they get to run is whichever magic method PHP fires automatically. Identifying these in app + dependency code is the start of every PHP POP-chain hunt.

## Preconditions / where it applies
- PHP source / Composer dependencies — including vendored frameworks (Laravel, Symfony, Guzzle, Monolog)
- A reachable `unserialize`, phar metadata sink, or `__unserialize` consumer — see [[php-deserialization-gadgets]]
- PHP 5.4+ (most magic methods); `__unserialize` and `__serialize` added in 7.4

## Technique
The lifecycle and the magic that fires:

| Trigger | Magic method called |
| --- | --- |
| `unserialize($data)` end-of-object | `__wakeup()` (always); `__unserialize($arr)` if defined (PHP 7.4+, takes precedence over wakeup) |
| Object destruction / script end | `__destruct()` |
| `(string)$obj`, `echo $obj`, string concat, `strlen($obj)` | `__toString()` |
| `$obj->unknownProp` (read) | `__get('unknownProp')` |
| `$obj->unknownProp = x` (write) | `__set` |
| `$obj->unknownMethod($args)` | `__call('unknownMethod', $args)` |
| `Klass::unknownStatic($args)` | `__callStatic` |
| `$obj($args)` (call object) | `__invoke` |
| `isset($obj->p)` / `empty(...)` | `__isset` / `__unset` |
| `clone $obj` | `__clone` |
| `var_export($obj)` | `__set_state` |

**Why each matters for chains:**
- `__wakeup` / `__destruct` — guaranteed-to-fire entry points. Almost every published gadget starts here.
- `__toString` — fires whenever the object reaches a string context. If a `__destruct` calls `error_log($this->msg)` and `$this->msg` is an object you control, you've pivoted to `__toString`.
- `__call` — used to pivot from a wrapper class (e.g. `Symfony\...\LazyChoiceList::__call`) to an arbitrary method on an embedded object.
- `__get` — read-side property dispatch; used in chains where the controlled object's property is read into a sink (e.g. `Twig\Template::displayBlock`).
- `__invoke` — turns a property that is "called" later into arbitrary code; pairs well with `array_map($cb, $arr)` if `$cb` is a controlled object.

**Concrete chain pattern:**
```php
class Pwn {
  public $cmd;
  public function __destruct() { system($this->cmd); }
}
// payload: unserialize('O:3:"Pwn":1:{s:3:"cmd";s:2:"id";}');
```
Real chains do not have such convenient classes; they bridge through `__toString` → `__call` → `__invoke` to reach a `call_user_func` or `eval` in a framework class.

**Tools:** PHPGGC (PHP Generic Gadget Chains) implements published chains for Laravel, Symfony, Guzzle, Monolog, Slim, Doctrine, CodeIgniter etc.:
```bash
phpggc Laravel/RCE9 system id | base64 -w0
phpggc Monolog/RCE1 'system' 'id'
```

## Detection and defence
- Never `unserialize` untrusted input — use `json_decode` or `igbinary`; if you must, set the `allowed_classes` option to a strict allowlist (`unserialize($s, ['allowed_classes' => [SafeDTO::class]])`)
- `__wakeup` / `__destruct` should not call methods on instance properties whose type is not enforced via `declare(strict_types=1)` + typed properties
- Run Psalm/PHPStan with `unserializeForbiddenType` rules
- Snuffleupagus' `sp.unserialize_hmac.enable=1` ties serialized blobs to an HMAC so attacker-crafted strings won't deserialise
- See [[php-deserialization-gadgets]] for chain construction, [[dangerous-php-sinks]] for sinks reachable from magic methods

## References
- [PHP manual — magic methods](https://www.php.net/manual/en/language.oop5.magic.php) — official list and semantics
- [PHPGGC](https://github.com/ambionics/phpggc) — gadget chain collection
- [HackTricks — PHP deserialization](https://book.hacktricks.wiki/en/pentesting-web/deserialization/php-deserialization-and-autoload-classes.html) — magic-method-driven chains
- [Ambionics — PHP unserialize research](https://www.ambionics.io/blog/) — modern gadget research blog
