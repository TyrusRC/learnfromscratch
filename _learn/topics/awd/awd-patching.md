---
title: AWD patching
slug: awd-patching
---

> **TL;DR:** Make the smallest possible change that kills the bug without breaking the checker — usually an input filter or a single line edit — and verify with the gamebot before declaring victory.

## What it is
A patch in Attack-with-Defence is not a clean fix; it is a damage-control change that must (a) prevent rival teams from reaching the vulnerable code path and (b) keep the scoring checker returning green. A patch that breaks the checker costs the same SLA points as a downed service, so over-patching loses the round. See [[awd-overview]] for the scoring model.

## Preconditions / where it applies
- You have the service source on your own box, root access, and the ability to restart it
- The checker exercises a defined "happy path" — your patch must not change that path's observable behaviour
- You usually have a working exploit (yours or one captured via [[awd-traffic-analysis]]) so you can regression-test

## Technique
Three patching styles, applied in order of preference:

1. **WAF-style request filter.** Drop the malicious payload before the vulnerable handler runs. Quickest to deploy, easiest to roll back. Example for an `eval()` injection in a PHP service:

   ```php
   // top of index.php
   foreach ($_REQUEST as $k => $v) {
       if (preg_match('/(system|exec|passthru|`|\$\(|<\?php)/i', (string)$v)) {
           http_response_code(400); exit;
       }
   }
   ```
2. **Surgical source edit.** Patch the bug itself — escape the SQL parameter, bound-check the buffer, sign the session cookie. Diff against your baseline copy to keep the patch minimal:

   ```bash
   diff -u baseline/app.py current/app.py
   ```
3. **Reverse proxy interception.** Drop a tiny `nginx` or `mitmproxy` in front of the service to rewrite or drop bad requests when you cannot or do not want to touch the source.

Verification loop, every patch:

```bash
# does the checker still pass?
curl -s http://localhost:PORT/healthz
# does the exploit still work?
python3 sploit.py 127.0.0.1
```

If the exploit succeeds, the patch is incomplete. If the checker fails, the patch is too aggressive — revert and try again. Keep every iteration in git so rollback is one command.

## Detection and defence
- A blocked request in the WAF filter is a "free" alert — log the source IP and payload, you may be able to replay the exploit against everyone else (see [[awd-flag-strategy]])
- Watch for rivals patching your patches — some events let teams push files to each other via the original exploit
- Sign and integrity-check your patched binaries; rivals will try to overwrite them to re-open the bug

## References
- [PortSwigger Web Security Academy](https://portswigger.net/web-security) — patterns for safe parameter handling and exploitation
- [PayloadsAllTheThings WAF bypasses](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Bypass%20Firewall) — informs how thin your regex filter can be before it is bypassed
- [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html) — defensive guidance
- [Saarsec team repos](https://github.com/saarsec) — examples of in-game patching scripts
