---
title: Silver tickets
slug: silver-tickets
---

> **TL;DR:** Forge a service ticket directly with a service account's long-term key — the target service decrypts and accepts it without ever consulting the KDC, leaving no 4769 on the DC.

## What it is
A TGS is encrypted with the service account's key. Possess that key — for a computer account or a domain user holding the SPN — and you can mint a TGS for that service with an arbitrary PAC. The target sees a valid ticket, decrypts it, and trusts the embedded SIDs. No TGS-REQ ever hits a DC, so 4769 doesn't fire; the trail (if any) lives in the target host's 4624/4634. This is the per-service equivalent of [[golden-tickets|golden tickets]] — narrower scope but quieter.

## Preconditions / where it applies
- The service account's NT hash, AES128, or AES256 key. Obtained from:
  - [[dcsync]] / NTDS dump for any account.
  - LSA secrets / SAM dump of a member server (machine account hash).
  - Mimikatz `sekurlsa::logonpasswords` on the host.
- Knowledge of the SPN you want to forge for (e.g. `cifs/srv01.corp.lab`, `HTTP/srv01.corp.lab`, `MSSQLSvc/sql.corp.lab:1433`).
- Domain SID and the target service account's RID (or just the SPN owner).

## Technique
Pick the service and key, embed groups in the PAC.

```powershell
# Mimikatz — silver ticket as Administrator for CIFS on srv01
kerberos::golden /user:Administrator /domain:corp.lab /sid:S-1-5-21-... `
  /target:srv01.corp.lab /service:cifs /rc4:<srv01$ NT hash> `
  /groups:512 /ptt
# Then
dir \\srv01.corp.lab\C$
```

```bash
# Impacket
ticketer.py -nthash <srv$NT> -domain-sid S-1-5-21-... \
  -domain corp.lab -spn cifs/srv01.corp.lab Administrator
export KRB5CCNAME=Administrator.ccache
smbexec.py -k -no-pass Administrator@srv01.corp.lab
```

Service-class implications when you forge against a computer account:
- `cifs` → SMB → file shares + admin ops.
- `host` → broad — historically gave SCM, scheduled tasks, WMI.
- `HTTP` → IIS, WinRM (sort of), AD CS Web Enrollment.
- `MSSQLSvc` → SQL, then [[mssql-trusted-links]] hops.
- `LDAP` → DC LDAP queries / writes if forged against a DC computer.

**PAC validation gotcha:** since the 2021 PrintNightmare-era patches, KDCs/services validate the PAC signature with the KDC key for some services. Pure-offline silver tickets work where PAC validation is local-only (most member servers, SMB, MSSQL). Forging silver tickets against DCs is more constrained.

Useful enctype hygiene: forge AES256 when the account's `msDS-SupportedEncryptionTypes` advertises AES; RC4 forgeries on AES-only accounts pop "encryption type downgrade" alerts.

The `/target` value must be the exact FQDN the client will request (mimikatz binds the ticket to that string); requesting `\\srv01\C$` via NetBIOS while the ticket carries `srv01.corp.lab` causes `KRB_AP_ERR_MODIFIED` on the target. Likewise, `/service` choices like `host` cover SCM/scheduled tasks/WMI in one forge but exclude `cifs` — for full SMB + remote-exec coverage on a single host you typically mint two tickets (`cifs` and `host`) under the same `KRB5CCNAME` rather than one. Stick to `klist purge` between forges to avoid stale-ticket confusion in interactive sessions.

## Detection and defence
- Native logs are sparse: no 4769 on the DC. Watch target host 4624 with Logon Type 3 + Kerberos package + impossible source / time.
- Defender for Identity has limited silver-ticket detection; some XDRs catch PAC signature anomalies (`PAC_ATTRIBUTES_INFO` missing in older forgers).
- Rotate machine account passwords — by default they auto-rotate every 30 days, but DCs sometimes have it disabled (`DisablePasswordChange=1`). Force `Reset-ComputerMachinePassword`.
- Add high-value services to Protected Users / AES-only.
- Keep DCs patched so PAC validation enforcement (`PacRequestorEnforcement=2`) blocks tampered SIDs.
- Pair detection with [[ad-persistence]] hunting — silver tickets are often a persistence layer.

## References
- [the.hacker.recipes — Silver ticket](https://www.thehacker.recipes/ad/movement/kerberos/forged-tickets/silver) — primitive reference
- [HackTricks — Silver ticket](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/silver-ticket.html) — tool examples
- [Microsoft — KB5020805 PAC validation](https://support.microsoft.com/topic/kb5020805-how-to-manage-kerberos-protocol-changes-related-to-cve-2022-37967-997e9acc-67c5-48e1-8d0d-190269bf4d5b) — PAC enforcement modes
- [SpecterOps — Kerberos forgeries detection](https://posts.specterops.io/) — telemetry hunting
- [ired.team — Kerberos Silver Tickets](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/kerberos-silver-tickets) — /target /service flag walkthrough and klist verification
