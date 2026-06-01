---
title: TCC bypasses
slug: tcc-bypasses
---

> **TL;DR:** TCC bypasses cluster into four families — inheriting a grant by injecting into an already-allowed binary, mounting/overwriting the TCC DB out from under `tccd`, abusing privileged TCC-management helpers, and identity-spoofing where `tccd` mis-attributes the caller.

## What it is
TCC stores grants keyed to a code-signing identity in SQLite databases. Each bypass class abuses a different link in the chain: who can write the DB, who `tccd` thinks is asking, and which binaries already hold the grant you want. New variants ship per macOS release because the underlying control points (SQLite file, audit token, signature checks, env-controlled loading) repeat.

## Preconditions / where it applies
- You usually have user shell or root.
- Target macOS has the grant you want assigned to *some* binary or you can manipulate one of the chain links.
- See [[macos-tcc]] for the model, [[entitlements-and-codesigning]] for the identity primitives, [[sip]] for why root alone is not enough.

## Technique
Representative bypass families (each has several public CVEs):

1. **Inherit a grant by injection**
   - Binary with `com.apple.security.cs.disable-library-validation` already holds Full Disk Access. Plant a dylib, get it loaded (DYLD_INSERT_LIBRARIES still works for non-hardened, library-validation-disabled binaries), now you run inside a Full-Disk-Access-granted process.
   - Variant: launch agent that hijacks an app's plugin bundle path.

2. **TCC DB mount / overwrite**
   - User TCC.db is *not* SIP-protected (only system DB is). With user-context code, you can directly modify `~/Library/Application Support/com.apple.TCC/TCC.db` — though `tccd` watches for changes and may reject hand-edited rows.
   - Mount your own DMG over the directory containing `TCC.db` so `tccd` loads attacker-controlled rows on next start. CVE-2020-9934 and family. The system DB version of this trick requires SIP off, or a SIP-bypass entitled binary — see [[sip-bypasses]].

3. **Privileged proxy DB writes**
   - Apple binaries with `com.apple.private.tcc.manager.*` entitlements can mutate the system DB. Find one with argument or XPC misuse; have it write the grant for you. Microsoft's "powerdir" (CVE-2021-30970) is in this family.

4. **Audit-token / identity confusion**
   - `tccd` identifies callers by `xpc_connection_get_audit_token` and resolves to code signature. If a daemon forwards XPC requests on behalf of a less-trusted client and reuses its own audit token, `tccd` attributes the grant to the daemon. Public examples in MDM agents and several third-party helpers.

5. **Environment- and path-mediated**
   - `DYLD_INSERT_LIBRARIES` against non-hardened apps with grants; `HOME` redirection against tools that read TCC-adjacent state; `tccutil reset` race windows.

Recon snippets:

```bash
# What does each system app have, identity-wise?
codesign -d --entitlements - /Applications/SomeApp.app/Contents/MacOS/SomeApp 2>&1 \
  | grep -E "disable-library-validation|get-task-allow|tcc"

# Hunt for binaries holding interesting TCC management entitlements
sudo find /System /usr/libexec -type f -perm -u+x -exec sh -c \
  'codesign -d --entitlements - "$1" 2>/dev/null | grep -q tcc && echo "$1"' _ {} \;
```

## Detection and defence
- Unified log `com.apple.TCC` records every decision and the resolved client identity — defenders correlate process trees with unexpected grant inheritance.
- File-integrity monitoring on `~/Library/Application Support/com.apple.TCC/` catches mount-swap and direct-write attacks.
- Hardening: remove `disable-library-validation` from internal apps that hold sensitive TCC grants; restrict TCC grants to specific signed binaries via MDM PPPCP profiles; avoid third-party tools that ship privileged helpers with broad entitlements.
- Keep current — Apple patches per CVE; classes recur.

## References
- [Wojciech Reguła — TCC bypass series](https://wojciechregula.blog/) — multiple writeups across macOS versions.
- [Microsoft — powerdir (CVE-2021-30970)](https://www.microsoft.com/en-us/security/blog/2022/01/10/new-macos-vulnerability-powerdir-could-lead-to-unauthorized-user-data-access/) — privileged-proxy class.
- [HackTricks — macOS TCC bypasses](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-tcc/macos-tcc-bypasses/index.html) — categorised techniques.
