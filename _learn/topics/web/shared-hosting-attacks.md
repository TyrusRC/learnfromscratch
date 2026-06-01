---
title: Shared-hosting attacks
slug: shared-hosting-attacks
---

> **TL;DR:** Co-tenant on same vhost / app pool / DB instance pivots into target's session, files, or DB. Multi-tenant SaaS variant.

## What it is
Shared-hosting environments — classic cPanel boxes, Plesk, IIS shared application pools, single-database multi-tenant SaaS — squeeze many tenants onto one OS, one web server, one database. Isolation depends on file permissions, virtual-host routing, and per-tenant DB users. Any gap in those boundaries gives one tenant access to others.

## Preconditions / where it applies
- One web server instance hosting multiple customer sites (Apache mod_php, IIS w3wp shared pool, nginx + php-fpm pool shared)
- World-readable home directories, weak `open_basedir`, no chroot/jail
- Shared DB instance where tenant credentials are not least-privileged
- Multi-tenant SaaS keying rows by `tenant_id` enforced only in application code

## Technique
1. **Buy a cheap account on the same host** as the target — same `/etc/passwd` UID space, often same web user (`www-data`, `apache`).
2. **File-system pivot** — `/home/target/public_html/wp-config.php` readable if perms slack; harvest DB creds, secret keys.
   ```bash
   ls -la /home/*/public_html/ 2>/dev/null
   find / -name 'wp-config.php' -readable 2>/dev/null
   ```
3. **PHP `open_basedir` bypass** — symlink, `glob://`, `/proc/self/root/`, FFI; classic cPanel symlink race exploited for years.
4. **Apache `Symlink Race`** — replace a file with a symlink between `stat()` and `open()` to read victim's files as `www-data`.
5. **Session file theft** — default PHP sessions in `/tmp` world-readable; grab cookies, hijack admin sessions.
6. **Cross-vhost via `Host:`** — request `Host: victim.tld` against your own vhost's IP; if app reads files by `Host`, you may serve their content with your code injection.
7. **DB pivot** — same MySQL/Postgres instance; if the tenant user has `FILE` or unintended cross-db SELECT, dump other tenants. `information_schema.tables` is the recon target.
8. **Multi-tenant SaaS row leak** — IDOR/[[idor]] on `tenant_id`, or SQL injection that drops the implicit `WHERE tenant_id = X` filter, or report endpoint with hand-picked SQL.
9. **Shared cache** — Redis/Memcached used across tenants without key prefixes; read/write neighbour keys; poison sessions ([[cache-poisoning]]).
10. **Shared queue / pub-sub** — events leak across tenants via wildcard subscriptions.

## Detection and defence
- Per-tenant OS user + chroot/container; do not share `www-data`.
- Apache `SymLinksIfOwnerMatch`, mod_ruid2/mpm-itk for per-vhost UID; nginx + per-tenant php-fpm pool with `user=` and `chroot=`.
- DB: one role per tenant, schema isolation, row-level security (Postgres `RLS`).
- SaaS: enforce `tenant_id` filter in a single ORM layer, not per-query; add CI tests for cross-tenant access.
- Cache/queue: namespaced keys (`tenant:{id}:…`), per-tenant ACLs.
- Audit `/tmp`, `/var/www`, `/home/*` permissions; harden umask to 027.
- Related: [[idor]], [[broken-access-control]], [[information-disclosure]], [[cache-poisoning]].

## References
- [Cloudlinux — CageFS](https://docs.cloudlinux.com/cagefs/) — shared-hosting isolation
- [HackTricks — escape jails](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/escaping-from-limited-bash.html) — chroot/jail breakouts
- [Postgres — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html) — per-tenant DB isolation
