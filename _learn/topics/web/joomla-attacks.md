---
title: Joomla attacks
slug: joomla-attacks
---

> **TL;DR:** Old `com_users` and SQLi-history bugs on core, weak `/administrator` auth, file-write via the template manager once admin, and the long tail of third-party component CVEs.

## What it is
Joomla is a PHP/MySQL CMS with a core and an extension model (components `com_*`, modules `mod_*`, plugins `plg_*`, templates). Like other big-ecosystem CMS, most real-world compromise comes from outdated components or weak admin credentials rather than core 0-day — but core history (Joomla 3.7 com_fields SQLi, 4.2.8 unauth API access) is worth knowing.

## Preconditions / where it applies
- Joomla 3.x, 4.x, or 5.x. Fingerprint via `/administrator/manifests/files/joomla.xml`, `Generator: Joomla!` meta, `/media/system/js/`.
- For admin-side abuse: a Super User credential, often via password reuse, weak password, or one of the CVE bypasses.
- For component CVEs: any anonymous reachable component endpoint (`index.php?option=com_<name>&...`).

## Technique
1. **Fingerprint.** `joomscan -u https://target/`, or manually fetch `/administrator/manifests/files/joomla.xml` (version), `/language/en-GB/en-GB.xml`, `/README.txt`. List extensions via `?option=com_X` brute.
2. **CVE-2017-8917 (com_fields SQLi, 3.7.0).** Pre-auth blind SQLi on the `list[fullordering]` parameter.

   ```http
   GET /index.php?option=com_fields&view=fields&layout=modal&list[fullordering]=updatexml(0x23,concat(1,user()),1) HTTP/1.1
   ```

3. **CVE-2023-23752 (Joomla 4.0–4.2.7).** Unauthenticated API access leaks config including MySQL credentials and the configured user.

   ```http
   GET /api/index.php/v1/config/application?public=true HTTP/1.1
   ```

4. **Admin brute / password reuse.** `/administrator/` accepts username + password; rate limit is per-user only on default config. Combine with leaked credentials.
5. **Template manager → web shell.** Once admin: Extensions → Templates → edit `error.php` of the active template, paste a PHP web shell, browse it. Same trick via the Module manager with the "Custom HTML" module if `iframe`/PHP via plugin is allowed.
6. **JCE / RokDownloads / com_media history.** Many file-upload bypass CVEs in third-party components — always check the installed list against https://vel.joomla.org/.
7. **Object injection.** Joomla session handler historically deserialises session data; pre-PHP 7.2 sessions were the canonical PHP object injection vector. See [[deserialisation]].

## Detection and defence
- Keep core and every component patched; subscribe to the Joomla VEL feed.
- Move `/administrator/` behind IP allowlist, VPN, or HTTP basic auth in front of PHP.
- Disable two-factor backup codes you do not need; enforce 2FA for Super Users.
- Detection: WAF rules for `list[fullordering]=` and `/api/index.php/v1/config/application?public=true`; file-integrity monitoring on template directories; alerts on new PHP files under `templates/`.

## References
- [Joomla! Security Centre](https://developer.joomla.org/security-centre.html) — advisory feed.
- [Joomla VEL (Vulnerable Extensions List)](https://vel.joomla.org/) — extension CVE tracker.
- [Sonar — CVE-2023-23752 write-up](https://www.sonarsource.com/blog/joomla-improper-acl-leads-to-private-data-access/) — root-cause walkthrough.
