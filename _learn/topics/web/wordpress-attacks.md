---
title: WordPress attacks
slug: wordpress-attacks
---

> **TL;DR:** Core is hardened; the plugin and theme ecosystem is not. wpscan + user enumeration + plugin/theme CVEs + xmlrpc abuse + weak admin creds covers most real-world compromise.

## What it is
WordPress runs ~40% of the web. Core auth and security have improved over years, but the average install ships dozens of third-party plugins and a theme, any of which can introduce SQLi, auth bypass, file upload, or SSRF. Most live compromises trace to one of: outdated plugin, weak admin password, xmlrpc.php abuse, or compromised admin credential reuse.

## Preconditions / where it applies
- A WordPress site — fingerprint via `/wp-login.php`, `/wp-content/`, `Generator` meta, `/readme.html`, `/wp-json/wp/v2/`.
- For the lowest-effort path: anonymous access to `/wp-json/wp/v2/users` (user enumeration) and `/wp-login.php` or `/xmlrpc.php` (brute-force).
- For plugin CVE chains: knowing the installed plugins and their versions.

## Technique
1. **Enumerate.** `wpscan --url https://target/ --enumerate u,vp,vt,cb` — users, vulnerable plugins, themes, config backups.
2. **User enumeration.**
   - `/?author=1`, `/?author=2`, ... redirects to `/author/<login>/`.
   - `/wp-json/wp/v2/users` returns the list as JSON (when REST API is open).
   - Login error oracle: "invalid username" vs "invalid password" (default behaviour).
3. **Brute-force.**
   - `/wp-login.php` — slow, captcha-able. `wpscan --passwords list.txt --usernames admin`.
   - `/xmlrpc.php` `system.multicall` — pack hundreds of `wp.getUsersBlogs` auth attempts per request, bypasses naive per-request rate-limiting.
4. **Plugin / theme CVE.** Check wpscan DB / wpvulndb / patchstack. Common patterns:
   - **File-upload bypass** — author/contributor user can upload PHP via plugin that uses `wp_handle_upload` without mime check.
   - **Authenticated SQLi** — `?action=...` AJAX endpoints with `esc_sql` missing.
   - **Unauth file read** — option export plugins, backup plugins.
5. **Admin → RCE.** Once admin: edit `wp-content/themes/<active>/404.php` via Appearance → Theme File Editor, drop a webshell. Or install a malicious plugin (`Upload Plugin` accepts a zip). If the editor is disabled (`DISALLOW_FILE_EDIT`), use a plugin upload or the media library + a path-traversal/LFI chain.
6. **xmlrpc DDoS / SSRF (pingback).** `pingback.ping` with `<value><string>http://internal/</string></value>` causes the site to request a URL — internal scanning oracle, DoS amplifier.
7. **wp-config.php disclosure.** Backup files (`wp-config.php.bak`, `~`, swap), exposed `.git`, or LFI chains read the DB creds, AUTH_KEYs, and secrets.

   ```bash
   wpscan --url https://target --api-token <key> \
          --enumerate u,vp,vt,ap,at,cb,dbe \
          --plugins-detection aggressive
   ```

## Detection and defence
- Auto-update minor versions; patch plugins within 24-48h of advisory. Remove unused plugins/themes.
- Disable XML-RPC (`disable-xml-rpc` plugin, or `.htaccess` deny) unless you actually need pingback. Require 2FA for all admins.
- Lock `/wp-admin/` and `/wp-login.php` behind IP allowlist or HTTP basic; set `DISALLOW_FILE_EDIT = true` in `wp-config.php`.
- File-integrity monitoring on `wp-content/`; periodic comparison to known-good hashes.
- Detection: login bursts on `/wp-login.php` and `/xmlrpc.php`, new PHP files under `uploads/`, REST `users` enumeration hits.

## References
- [WPScan vulnerability database](https://wpscan.com/) — canonical plugin/theme CVE feed.
- [Patchstack — WordPress security](https://patchstack.com/database/) — additional advisory tracker.
- [HackTricks — WordPress pentesting](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/wordpress.html) — enumeration commands.
