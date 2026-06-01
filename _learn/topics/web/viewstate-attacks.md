---
title: ASP.NET ViewState attacks
slug: viewstate-attacks
---

> **TL;DR:** Unencrypted or weak-key ViewState — deserialise to RCE, or tamper to alter server-side state.

## What it is
ASP.NET Web Forms persists per-control state across postbacks in a hidden `__VIEWSTATE` field. The server serialises a `LosFormatter` graph, base64-encodes it, and sends it to the client. The client returns it on the next request and the server deserialises. The `machineKey` controls how the field is signed (and optionally encrypted). If you know or guess the key, or the field is unsigned, you author a serialized payload whose deserialisation triggers RCE — this is the classic `ysoserial.net` use case.

## Preconditions / where it applies
- Target uses ASP.NET Web Forms (`.aspx`, hidden `__VIEWSTATE` field present)
- `EnableViewStateMac` disabled (CVE-2014-4078 era — explicit `false` in config) *or*
- Default / leaked / weak `machineKey` (decryption key, validation key, algorithm)
- Older .NET targets where `LosFormatter` / `ObjectStateFormatter` were not constrained

## Technique
**Identify.** Fetch the page; if response contains `<input type="hidden" name="__VIEWSTATE" value="…">`, this is a Web Forms app. The query string `__VIEWSTATEGENERATOR` reveals the page-specific generator (combined with `MachineKey` to compute the MAC).

**Unkeyed ViewState (no MAC).** Pre-2014 apps and apps with `enableViewStateMac=false`. Generate a payload with ysoserial.net:

```
ysoserial.exe -p ViewState -g TextFormattingRunProperties \
   -c "powershell -e SQBFAFgAIA..." --isdebug
```

POST it as `__VIEWSTATE`; the server deserialises, gadget runs, you have RCE as the AppPool identity.

**Known machineKey.** Sources include leaked `web.config`, default keys in misconfigured stacks, keys recovered from public source dumps (Telerik UI for ASP.NET AJAX leaked keys list). Supply the key and the page-specific generator:

```
ysoserial.exe -p ViewState -g TypeConfuseDelegate -c "cmd.exe /c calc" \
   --path="/page.aspx" \
   --apppath="/" \
   --decryptionalg="AES" --decryptionkey="…" \
   --validationalg="HMACSHA256" --validationkey="…" --generator="<gen>"
```

Encode and send. Successful execution typically returns `500` with a deserialisation error mentioning your gadget chain — that's the canonical signal.

**Telerik UI for ASP.NET AJAX (CVE-2019-18935 and related).** RadAsyncUpload encrypted upload handler used a hardcoded fallback key list — ysoserial.net + the Telerik exploit chains give straightforward RCE on thousands of public targets.

Related: [[deserialisation]] for the broader gadget concept, [[rce-class]] for downstream privilege framing.

## Detection and defence
- Keep `enableViewStateMac="true"` (cannot be set false on supported .NET versions)
- Rotate `machineKey` per environment; never commit to source; never copy between apps
- Use AES `validation`/`decryption` algorithms; long random keys
- Encrypt ViewState (`viewStateEncryptionMode="Always"`) on pages handling sensitive state
- Patch Telerik UI to current; rotate ASP.NET keys immediately if old Telerik was ever deployed
- IDS/WAF on absurdly large `__VIEWSTATE` (gadget chains are large), and on `__VIEWSTATEGENERATOR` mismatches

## References
- [Soroush Dalili — Exploiting deserialisation in ASP.NET via ViewState](https://soroush.me/blog/2019/04/exploiting-deserialisation-in-asp-net-via-viewstate/) — comprehensive walk-through
- [ysoserial.net](https://github.com/pwntester/ysoserial.net) — payload generator
- [Microsoft — ASP.NET ViewState overview](https://learn.microsoft.com/en-us/aspnet/web-forms/overview/older-versions-getting-started/master-pages/) — defensive context
