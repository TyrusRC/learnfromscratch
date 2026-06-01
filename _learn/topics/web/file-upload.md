---
title: File upload abuse
slug: file-upload
---

> **TL;DR:** Upload handlers that decide trust by extension or `Content-Type` are wrong; the win comes from extension parsing differentials, magic-byte/polyglot tricks, and the file being executed where it lands.

## What it is
A file upload endpoint accepts user-controlled content and writes it to disk, a CDN, or an object store. Exploits land along three axes: (1) the parser disagrees with the storage layer about file type, (2) the file is written to a path the attacker chose, (3) the content itself triggers execution on the receiving system (web shell, SSRF/XXE-capable doc, deserialiser).

## Preconditions / where it applies
- Any endpoint accepting user files: avatars, ticket attachments, importer endpoints, signed-URL uploads to S3/GCS.
- Server-side processing (image thumbnailer, AV scan, OCR) or web-served upload root.
- Trust decisions based on `Content-Type` header, file extension only, or client-side validation.

## Technique

**Extension and parser tricks (executes as code where it lands):**

```
shell.php.jpg            # Apache mod_mime: executes as PHP if AddHandler set on .php
shell.phtml / .phar      # PHP alt extensions
shell.asp;.jpg           # IIS legacy ;-trick
shell%00.jpg             # null-byte truncation on older PHP/Java
shell.aspx::$DATA        # NTFS ADS bypass
shell.jsp/                # path with trailing slash hits Tomcat differently
```

**Magic-byte polyglots** — start with a valid header for the allowed type and append payload:

```
GIF89a;<?php system($_GET['c']); ?>
```

Many image validators (`getimagesize`, `exif_read_data`) accept this. Same trick with PDF (`%PDF-1.4\n...<?php...`) and ZIP (a polyglot APK/JAR).

**Content-side wins:**

- **SVG → XSS / XXE / SSRF** — SVG is XML with `<script>`, and external entities work in some parsers. See [[xxe]], [[cross-site-scripting]].
- **HTML / SVG / XML → stored XSS** on the upload-serving subdomain (same-origin to cookies if the CDN domain is shared).
- **ImageMagick / Ghostscript** — `MVG` / `MSL` / PostScript payloads (`ImageTragick`, GhostButt) hit thumbnail pipelines.
- **Office / PDF macros** — Word/Excel can call SSRF via remote templates and image fetches.
- **`.htaccess` / `web.config`** — upload one alongside other files to enable handler mapping for the previously-inert payload.

**Path-side wins:**

- Filename traversal `../../etc/cron.d/x` if the server uses the client filename verbatim.
- Zip-slip on archive importers — entries named `../../etc/passwd` overwrite system files.
- S3 pre-signed URL with no key prefix lets you overwrite other users' objects.

**Race conditions** — upload a file, request execution in a tight loop; some scanners delete malicious files but only after a small window during which the file is web-reachable. See [[race-conditions]].

## Detection and defence
- Server generates the filename and extension; never trust client values. Store outside the webroot, serve via a controller.
- Validate by magic bytes + re-encode (imagemagick `convert` round-trip strips polyglots and EXIF payloads).
- Disallow execution on the upload directory (`AddHandler` off; nginx `location ~* \.php$ { return 403; }`).
- For SVG/HTML/XML uploads, force `Content-Disposition: attachment` and serve from a sandbox subdomain with no cookies and CSP `default-src 'none'`.
- Scan archives for traversal entries; cap archive expansion ratio.
- AV/yara on the storage tier; alert on `.php`, `.phtml`, `.jsp`, `.aspx`, `.htaccess`, `web.config` filenames.

See also [[webdav-attacks]], [[path-traversal]], [[deserialisation]].

## References
- [PortSwigger – File upload vulnerabilities](https://portswigger.net/web-security/file-upload) — primer + labs
- [OWASP – Unrestricted File Upload](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload) — control list
- [HackTricks – File upload](https://book.hacktricks.wiki/en/pentesting-web/file-upload/index.html) — extension/parser tricks catalogue
