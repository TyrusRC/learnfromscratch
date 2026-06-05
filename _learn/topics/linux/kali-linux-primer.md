---
title: Kali Linux primer
slug: kali-linux-primer
aliases: [kali-primer, kali-basics]
---

{% raw %}

> **TL;DR:** Kali is a Debian-based offensive distro. Boot it (VM, WSL, or live), update once, learn five command groups (file/process/network/package/shell), and accept that 90% of your time is in a terminal. This is the zero-knowledge on-ramp for [[oscp-roadmap]] and [[osep-roadmap]].

## What it is
Kali Linux ships pre-configured with offensive tooling (nmap, burp, metasploit, gobuster, ffuf, hashcat, john, etc.). On OSCP/OSEP you'll spend the entire engagement in a Kali VM, so the first hour is just learning to live in it.

## Install paths (pick one)
- **VMware/VirtualBox VM** (recommended for OSCP) — download the prebuilt OVA from kali.org, snapshot before each exam.
- **WSL2** — fine for note-taking, not for tools that need raw sockets/promiscuous mode (nmap SYN scan, responder).
- **Live USB** — useful when you need to attack from someone else's hardware (not exam-relevant).

```bash
# First boot, every time:
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y seclists exploitdb gobuster ffuf chisel ligolo-ng impacket-scripts bloodhound.py
```

## Five command groups you will reuse forever

### 1. Files
```bash
pwd                       # where am I
ls -la                    # list with hidden + perms
cd /tmp; cd -             # jump and back
find / -name '*.kdbx' 2>/dev/null   # find by name, swallow errors
grep -rni 'password' .              # recursive grep, no-case, line numbers
cat /etc/passwd | head -20          # peek
wc -l file                # count lines
```

### 2. Processes
```bash
ps auxf                   # tree of all processes
top                       # live (q to quit)
kill -9 <pid>             # nuke
jobs; bg; fg              # shell job control
nohup ./loot &            # detach
```

### 3. Network
```bash
ip a                      # interfaces
ss -tlnp                  # listening tcp + owning pid
ip route                  # routing table
curl -sk https://x/       # ignore TLS, silent
wget http://x/file        # fetch
nc -lvnp 4444             # listener (catch reverse shells)
nc -nv 10.0.0.1 80        # connect
```

### 4. Packages
```bash
sudo apt install <pkg>
sudo apt search <pkg>
sudo apt show <pkg>
dpkg -L <pkg>             # what files did this install
```

### 5. Shell / quality of life
```bash
history | grep nmap       # find that command from yesterday
!1234                     # rerun history entry 1234
Ctrl-R                    # search history interactively
tmux                      # session that survives SSH drop
tmux a -t 0               # reattach
```

## Directory layout you need to know
- `/usr/share/wordlists/` — symlinks to `/usr/share/seclists/` and `rockyou.txt.gz` (gunzip it first time)
- `/usr/share/exploitdb/` — local exploit-db copy, paired with `searchsploit`
- `/opt` — drop pip/git tools here (`/opt/impacket`, `/opt/bloodhound`)
- `~/.msf4/` — metasploit workspace; loot lands in `~/.msf4/loot/`

## VPN to the lab
- OSCP/OSEP labs hand you an OVPN config. `sudo openvpn user.ovpn` in a tmux pane and leave it.
- `ip a` should now show a `tun0` interface with a 10.x.x.x address — that's your sourcing IP for all reverse shells.

## Snapshot discipline
Before each lab session and **before the exam**:
1. Snapshot the VM clean.
2. Snapshot again at "tools installed and updated."
3. Roll back if anything wedges (display server crashes, network stack drops).

## Common first-day stumbles
- `rockyou.txt` doesn't exist until you `gunzip /usr/share/wordlists/rockyou.txt.gz`.
- `nc` on Kali is `nc.openbsd` — `-e` flag is missing; use `mkfifo` pattern or `rlwrap nc`.
- `python` may not exist — it's `python3`. Symlink with `sudo apt install python-is-python3`.
- Firefox containers will eat your Burp CA — install the CA into Burp's own browser (`burpsuite` → embedded browser).

## References
- [Kali official docs](https://www.kali.org/docs/)
- [Kali tools index](https://www.kali.org/tools/)
- See also: [[bash-and-shell-primer]], [[oscp-roadmap]], [[osep-roadmap]], [[metasploit-fundamentals]]

{% endraw %}
