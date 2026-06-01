---
title: Gatekeeper bypasses
slug: gatekeeper-bypasses
---

> **TL;DR:** Bypasses fall into three buckets: (1) prevent the `com.apple.quarantine` xattr from being set, (2) trick `syspolicyd` into accepting a malformed/edge-case bundle, or (3) ride a legitimately signed Apple wrapper into running attacker content.

## What it is
Recurring research patterns against Gatekeeper. Apple patches specific bugs (each gets a CVE), but the underlying classes have repeated for years: archive formats that do not propagate quarantine, bundle-parsing inconsistencies between Finder/`LaunchServices` and `syspolicyd`, and signed-but-loose wrappers (script runners, interpreters) that execute untrusted code under their own trust.

## Preconditions / where it applies
- Local exec on a fully patched macOS — most published bypasses are fixed quickly, but research keeps finding more in the same families.
- Relevant for initial-access tradecraft and for evaluating how a phishing payload would behave end-to-end.
- See [[gatekeeper-and-notarisation]] for the baseline policy this is dodging.

## Technique
Categories with representative bugs:

1. **Quarantine non-propagation**
   - Some archive utilities historically did not set `com.apple.quarantine` on extracted files. CVE-2021-1810 (archive utility, "Shrootless"-adjacent) and the family later abused by macOS shortcut-based delivery show this pattern.
   - AppleDouble (`._foo`) metadata files can carry attributes that conflict with the main file; mismatches have allowed bundles to escape the xattr check.

2. **Bundle parsing inconsistencies**
   - CVE-2022-22616 / CVE-2022-22617 / similar: `syspolicyd` parsed `Info.plist` or `_CodeSignature` differently from `LaunchServices`, so the policy daemon evaluated a different binary than the one Finder launched.
   - CVE-2022-32910 ("Archive Utility"): nested archive structure caused quarantine xattr to be missed on the inner bundle.

3. **Signed wrapper abuse**
   - **Script execution**: shell scripts launched via Terminal or `open` historically did not trigger Gatekeeper for the interpreter, only the script. Embedding payload in a `.command` file or PKG postinstall script has been used repeatedly.
   - **Library validation off**: a signed app with `disable-library-validation` is a free dylib host — drop a dylib next to it, launch it normally, your code runs under the wrapper's signature. See [[entitlements-and-codesigning]].

Quick triage of a suspect bundle:

```bash
xattr -lr /Volumes/Mounted.dmg/Some.app | head
codesign -dvvv --requirements - /Volumes/Mounted.dmg/Some.app
spctl -a -vv -t exec /Volumes/Mounted.dmg/Some.app
```

If `spctl` says "accepted" but the bundle came from a quarantined download path with no notarisation ticket, something in the chain stripped or skipped quarantine.

## Detection and defence
- Watch unified logs from `com.apple.syspolicy` for `assessment denied`/`accepted` decisions and correlate with the source URL stored in the quarantine xattr.
- Endpoint security: alert on first-launch of binaries from `~/Downloads`, `/tmp`, or unsigned bundles regardless of Gatekeeper verdict.
- Keep macOS current; bypasses are patched per CVE but new ones emerge in the same classes.
- For high-risk users, enable Lockdown Mode and restrict installer types via MDM.

## References
- [Objective-See — Gatekeeper Exposed series](https://objective-see.org/blog.html) — multiple bypass writeups across versions.
- [Microsoft — Achilles (CVE-2022-42821)](https://www.microsoft.com/en-us/security/blog/2022/12/19/gatekeepers-achilles-heel-unearthing-a-macos-vulnerability/) — ACL-based bypass.
- [HackTricks — macOS Gatekeeper](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-gatekeeper.html) — categorised techniques.
