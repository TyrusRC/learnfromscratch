---
title: Blind vuln confirmation from source
slug: blind-vuln-confirmation-from-source
aliases: [confirming-blind-bugs, blind-bug-source-confirmation]
---

{% raw %}

> **TL;DR:** Blackbox testing finds blind bugs — out-of-band SSRF, blind SQLi, blind XXE, blind RCE via DNS exfil. Source review confirms them in seconds: read the code path from the input to the sink, see what's actually happening, and design a precise PoC that doesn't rely on observable side-channels. Source is the lever that turns "probably blind" into "confirmed and exploitable."

## What it is
Blackbox testing often surfaces "something is happening server-side" without proving it. A 200 OK with no body, a 5-second response on certain payloads, a DNS lookup on a [Collaborator](https://portswigger.net/burp/documentation/collaborator) endpoint — all signal but not proof. When you have source, the confirmation step is reading the relevant 30 lines of code. This note is the methodology for using source to lift a blind signal to a precise exploit.

## Common blind shapes and how source closes them

### Blind SSRF
- Blackbox signal: out-of-band DNS hit, no in-band response.
- Source check: find the fetch sink. Does it follow redirects? Does it expose response body? Does it error-out on protocol mismatch?
- If body is fetched but not returned → exfil via error-based ("HTTP 500: {body}"). Source tells you whether the error message includes body.
- If `file://`, `gopher://`, `dict://` schemes are allowed → escalation from SSRF to file read or unauth proto interaction.
- Source code reveals what to send and what to look for in the response.

### Blind SQLi
- Blackbox signal: time-based delays correlate with payload.
- Source check: confirm the query, find the column types, find downstream uses.
- A blind SQLi in `SELECT ... WHERE id = $userid` might be readable via a side-channel column shown elsewhere — source shows that column name and where it's later rendered.
- Source reveals DBMS, useful for `pg_sleep`/`sleep`/`WAITFOR`/`benchmark` selection.

### Blind XXE
- Blackbox signal: OOB DNS resolution from XML parsing.
- Source check: find the parser, check for `DOCTYPE` allowed, check if response includes parsed data or just status.
- Source confirms whether `xinclude` or external param entities are enabled — different exfil techniques.

### Blind RCE
- Blackbox signal: DNS callback on payload, no stdout in response.
- Source check: find the sink (`exec`, `eval`, deserialization). Stage the exploit precisely instead of trial-and-error.
- Source shows the user the worker runs as (process owner) and which env vars/files are reachable.
- If the worker is a long-running daemon, source confirms how to inject without breaking state.

### Blind XSS (stored)
- Blackbox signal: triggered in admin context, fires on Collaborator.
- Source check: find the admin view, see exactly what context the user-controlled field renders into (HTML body? attribute? JS string? URL?).
- Source reveals which sanitiser ran (if any) so you can craft the bypass payload precisely.

### Blind path traversal
- Blackbox signal: error responses differ between `../` and harmless input; or no observable difference.
- Source check: find the file open, see if errors propagate, see what's done with the file content.
- Source confirms which read function (`fs.readFileSync`, `File.read`, `open()`) and what the response shape is for success vs failure.

## Workflow

1. **Get a signal blackbox.** Burp Collaborator, dnslog.cn, or a netcat catcher. Don't waste time blindly fuzzing source without a signal — source is huge.
2. **Bisect to the route.** Reproduce the signal, identify the URL + body that triggers it.
3. **Find the route in source.** Framework route table; grep for the path.
4. **Read the handler.** Top to bottom. Build a mental model of the data flow.
5. **Find the sink.** Where does the trigger reach?
6. **Read the sink's call site.** What does it do with the input? What does it return? What does it log?
7. **Engineer a precise PoC.** Use what you learned to produce a deterministic exploit — no blind iteration on payload variants.

## Source as confirmation in absence of OOB
Sometimes you don't have a confirmed signal, just a suspicion based on framework behaviour. Source review *creates* the signal:
- Find the sink, set a breakpoint, trigger the route, observe the breakpoint hit. That's confirmation.
- See [[debugger-driven-source-review]] for the debugger half.

## Avoiding overconfident reads
- Source-only confirmation has false positives — middleware, framework defaults, deployment config can save you. Always pair source with a live test.
- A "looks vulnerable" finding without a working PoC isn't a finding. Write the exploit.

## References
- [PortSwigger — Blind SQL injection](https://portswigger.net/web-security/sql-injection/blind)
- [PortSwigger Collaborator](https://portswigger.net/burp/documentation/collaborator)
- [Intruder — OOB techniques](https://www.intruder.io/research)
- See also: [[oast-out-of-band-testing]], [[debugger-driven-source-review]], [[whitebox-to-exploit-methodology]]

{% endraw %}
