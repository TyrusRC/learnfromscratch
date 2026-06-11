---
title: Snaffler — share & file-content mining
slug: snaffler-share-mining
aliases: [snaffler, share-mining, secret-hunting]
---

> **TL;DR:** Snaffler is a .NET file-share crawler that walks every SMB share you can reach, classifies files by name + content rules, and prints the high-value hits (creds, KeePass, conn-strings, private keys, scripts with passwords). Run it once with any low-privilege domain account on a mid-size network and you almost always find something — the technique is *too cheap not to try*.

## Mental model

A domain user can list `\\<DC>\SYSVOL`, `\\<server>\NETLOGON`, every `\\<host>\C$` they're admin on, and any explicitly-shared folder that didn't have its ACLs tightened. Most of those shares are decades old. Snaffler:

1. Discovers shares (LDAP query for computer accounts → enumerate shares per host).
2. **Classifies** at three levels:
   - **Share rules** — skip `NETLOGON`/`SYSVOL` patterns, keep `Backup`, `IT`, `HR$`.
   - **File-name rules** — flag `*.kdbx`, `*unattend.xml`, `web.config`, `id_rsa`, `*.ps1` containing the word `password`.
   - **File-content rules** — regex-match inside the file for `password=`, `pass:`, AWS keys, `apikey`, JWT prefixes.
3. Emits a colour-coded report to console and `.snaffler.log`.

Severity levels: **Black** (junk) → **Green** (interesting) → **Yellow** (likely secret) → **Red** (probable credential). Tune for the engagement.

## Tradecraft

```powershell
# Compile or grab a release — .NET Framework 4.7.2+ required
Snaffler.exe -s -d corp.lab -o snaffler.log

# Tighter run — only "Red" and "Yellow", no console spam
Snaffler.exe -s -d corp.lab -v Data -o snaffler.log

# Custom share list (skip LDAP discovery)
Snaffler.exe -i \\fileserver\share01,\\fileserver\share02 -o out.log

# In-memory only (no disk log)
Snaffler.exe -s -d corp.lab -j 8 -y                  # JSON to stdout
```

From Linux via [[netexec-nxc-workflow]] equivalent (spider_plus module + grep) — Snaffler itself is .NET-only. Use [[manspider]] or `nxc smb hosts -M spider_plus` for cross-platform.

### Rules file

Snaffler ships `Snaffler.exe -z` to dump the embedded rules; edit `default.toml` to add tenant-specific keywords (project codenames, internal product names, vendor prefixes). A focused rules file beats the defaults for any real engagement:

```toml
[[ClassifierRules]]
RuleName = "Custom-ProjectCodename"
EnumerationScope = "FileContentsEnumeration"
MatchLocation = "FileContentAsString"
WordListType = "Contains"
MatchAction = "Snaffle"
Triage = "Red"
WordList = ["BlueDolphin", "Internal-OAuth-Secret"]
```

### What you actually find

| Class | Typical hit |
|---|---|
| Scripts in SYSVOL | `GroupPolicy/Preferences/Groups.xml` with `cpassword` ([[gpo-abuse]]) |
| Backups shares | `*.bak`, full SQL backups with sa creds, NTDS snapshots |
| Dev shares | `web.config` with conn strings, `appsettings.json`, `.env` |
| User home dirs | `id_rsa`, `*.kdbx`, browser cookies, Outlook PST |
| IT/helpdesk shares | `Build/unattend.xml` with local admin pw, KeePass DBs |
| Software install | `PSAppDeployToolkit` scripts with hard-coded service-account pw |

## Detection / Telemetry

- **SMB read storm**: thousands of `SMB:TreeConnect` + `SMB:Read` from one principal across many hosts in minutes. Sysmon EID 5145 (`File share access`) is the canonical signal but volumes are huge — sample.
- **Defender for Identity**: "Suspicious SMB file enumeration" / "Reconnaissance using SMB session enumeration".
- **EDR**: Snaffler is a single .NET assembly named `Snaffler.exe` by default — rename, sign, or use the BOF port (`SnafflerBOF`) to bypass naming signatures.
- File-content matches happen **on the attacker host** (Snaffler downloads → regexes locally), so server-side content classification sees only bulk read patterns, not the matches themselves.

## OPSEC pitfalls

- Default Snaffler reads every file under threshold (~10 MB). On a slow network or a share with a few hundred GB, the run hangs for hours. Set `-w` (max file size in bytes) and `-q` (skip extensions) aggressively.
- Snaffler authenticates with the running token. If you launch from a session as `corp\me` it reads as `me`. Use `runas /netonly` or PsExec to swap identity before launching.
- The console output reveals creds in plaintext — clear scroll buffer, log only to encrypted disk.
- Old "cpassword" hits in `Groups.xml` (CVE-2014-1812) are an instant DA on legacy estates but trigger a forensic flag — capture and validate offline.
- Snaffler doesn't fingerprint share owners — you can crawl right into HR / finance / legal data. Define a scope-allowed regex and run with `-X` to exclude before pulling content.

## References

- https://github.com/SnaffCon/Snaffler
- https://github.com/snovvcrash/snaffler-parser   (`.log` → searchable HTML)
- https://github.com/jfmaes/SharpSnaffler         (in-memory port)
- https://github.com/SnaffCon/SnafflerBOF
- https://attack.mitre.org/techniques/T1083/

See also: [[gpo-abuse]], [[ldap-enumeration]], [[netexec-nxc-workflow]], [[sharphound]], [[bloodhound-ce-deployment]], [[impacket-toolkit-overview]], [[acl-abuse]]
