---
title: Pass the hash (PtH)
slug: pass-the-hash
---

> **TL;DR:** NTLM authenticates with the NT hash directly — capture the hash once and authenticate to every SMB/WMI/WinRM/HTTP endpoint that still accepts NTLM, without ever cracking the password.

## What it is
NTLM challenge-response uses the NT hash as the long-term secret to compute the response to the server's challenge. Knowledge of the password is irrelevant — the hash is the credential. PtH replays a stolen NT hash to any service whose SSP negotiates NTLM, granting authenticated access as that user. It is the foundational AD lateral-movement primitive and the reason "NTLM hash = password" is a hard truth in Windows pentesting.

## Preconditions / where it applies
- Possession of a user's NT hash (LSASS dump, SAM, NTDS.dit, responder relay, DPAPI secondaries).
- Target service still accepting NTLM (SMB without "require signing + reject NTLM", WinRM with `Negotiate`, MSSQL with Windows auth, HTTP with `WWW-Authenticate: NTLM`).
- For local accounts: target must not have `LocalAccountTokenFilterPolicy=0` blocking remote admin (default for non-RID-500 local accounts).
- Network path to the service ports (445, 5985, 1433, etc.).

## Technique
Impacket is the go-to from Linux:

```
psexec.py -hashes :<NThash> ADMIN@target.corp.local
wmiexec.py -hashes :<NThash> corp/Administrator@10.0.0.5
smbclient.py -hashes :<NThash> corp/alice@fs01
```

`crackmapexec`/`netexec` sprays a hash across a subnet to find where the account is admin:

```
nxc smb 10.0.0.0/24 -u alice -H <NThash> --local-auth
nxc winrm 10.0.0.0/24 -u alice -H <NThash>
```

From Windows, Mimikatz `sekurlsa::pth` plants the hash in a new logon session (see [[overpass-the-hash]] for the Kerberos variant). RID 500 (built-in Administrator) bypasses UAC remote restrictions even on workgroup-mode hosts — high-value reuse target after local SAM dumps.

PowerShell-only operators can use `Invoke-WMIExec -target <host> -hash <NThash> -username administrator -command <cmd>` to PtH without dropping Impacket — useful on EDR-instrumented jump hosts where Python is missing. Edge case: non-RID-500 local admin hashes silently fail with `access denied` from token filtering unless `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\LocalAccountTokenFilterPolicy = 0x1` is set on the target — query that key first via reg.py over a SOCKS pivot before burning attempts.

## Detection and defence
- 4624 logon type 3 with `AuthenticationPackageName=NTLM` for a domain account that normally uses Kerberos — classic anomaly.
- 4776 (NTLM authentication) on a DC from unusual source workstations.
- Disable NTLM where possible (`RestrictNTLM` GPOs), enforce SMB signing, enable Credential Guard, set `LocalAccountTokenFilterPolicy=0` and unique local-admin passwords (LAPS).
- Tier-0 accounts must never log on interactively to Tier-1/2 boxes — that is what seeds the hash for theft.

## References
- [Pass the Hash — the.hacker.recipes](https://www.thehacker.recipes/ad/movement/ntlm/pth) — protocol explainer.
- [Mitigating Pass-the-Hash — Microsoft (whitepaper)](https://www.microsoft.com/en-us/download/details.aspx?id=36036) — the canonical defender doc.
- [PtH with Impacket — HackTricks](https://book.hacktricks.wiki/en/windows-hardening/ntlm/index.html) — tool matrix.
- [ired.team — PtH privilege escalation with Invoke-WMIExec](https://www.ired.team/offensive-security/privilege-escalation/pass-the-hash-privilege-escalation-with-invoke-wmiexec) — RID 500 vs `LocalAccountTokenFilterPolicy` edge case walkthrough.
