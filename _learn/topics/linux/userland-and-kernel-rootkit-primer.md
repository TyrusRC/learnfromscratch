---
title: Linux userland and kernel rootkit primer
slug: linux-userland-and-kernel-rootkit-primer
aliases: [linux-rootkit-primer, ld-preload-rootkit]
---

{% raw %}

> **TL;DR:** A rootkit hides things from a user with root. Two layers: **userland** (LD_PRELOAD or `/etc/ld.so.preload` swapping out libc functions, or replacing binaries like `ps`, `ls`, `netstat`) and **kernel** (loadable kernel module that hooks syscalls or VFS structures). Userland is fragile but easy; kernel is durable but obvious if you don't sign it. This is the floor for OSEP-flavoured Linux post-ex; companion to [[linux-post-exploitation-tradecraft]].

## Why this exists

Once an admin notices "something runs after reboot", the next step is `ls /etc/cron*`, `systemctl list-units`, `ps aux`, `ss -tlnp`. A rootkit makes those commands lie. Good defence sees through it; bad defence trusts the output.

## Layer 1 — LD_PRELOAD (process scope)

```bash
gcc -shared -fPIC -o /tmp/hook.so hook.c -ldl
LD_PRELOAD=/tmp/hook.so target_command
```

Sample hook that wraps `readdir` to hide files starting with `.hidden`:

```c
#define _GNU_SOURCE
#include <dirent.h>
#include <string.h>
#include <dlfcn.h>

static struct dirent *(*real_readdir)(DIR *) = NULL;

struct dirent *readdir(DIR *dirp) {
    if (!real_readdir) real_readdir = dlsym(RTLD_NEXT, "readdir");
    struct dirent *e;
    while ((e = real_readdir(dirp))) {
        if (strncmp(e->d_name, ".hidden", 7) != 0) return e;
    }
    return NULL;
}
```

Now `LD_PRELOAD=/tmp/hook.so ls /tmp` skips the hidden entries.

Limitations:
- Only affects processes that honour `LD_PRELOAD` (dynamically linked, not setuid binaries unless you also set `/etc/ld.so.preload`).
- A statically-linked busybox doesn't care.
- Per-process — not system-wide.

## Layer 2 — /etc/ld.so.preload (system scope)

```bash
echo "/usr/local/lib/.preload.so" >> /etc/ld.so.preload
```

Every dynamically linked program system-wide now loads your `.so` before libc. Hooks `readdir`, `open`, `connect`, etc. globally.

Hooks worth implementing (the classic rootkit shopping list):
- `readdir` / `readdir64` — hide your files.
- `read` on `/proc/<pid>/...` — hide your PID from `ps`, `top`.
- `getdents` / `getdents64` — same purpose at a lower level.
- `accept` / `recvfrom` — hide your inbound connections.
- `open`, `stat`, `lstat`, `access` — return ENOENT for your files.
- `pam_authenticate` — accept a magic password (the rootkit-as-backdoor pattern).

## Layer 3 — binary replacement

Replace `/bin/ps`, `/bin/ls`, `/bin/netstat`, `/usr/bin/who`, `/usr/bin/top` with wrappers that filter your processes/files/connections. Crude — file integrity monitors (AIDE, Tripwire, Wazuh FIM) catch these — but plenty of unmonitored servers exist.

## Layer 4 — Loadable Kernel Module (LKM)

```c
// minimal LKM skeleton
#include <linux/module.h>
#include <linux/kernel.h>

static int __init init_fn(void) { printk("hi\n"); return 0; }
static void __exit exit_fn(void) { printk("bye\n"); }

module_init(init_fn);
module_exit(exit_fn);
MODULE_LICENSE("GPL");
```

```text
KDIR=/lib/modules/$(uname -r)/build
make -C $KDIR M=$PWD modules
insmod rk.ko
```

What an LKM rootkit can do:
- Hook syscalls (modify the sys_call_table — historically; modern kernels make this read-only, requiring CR0 WP-bit toggle or BPF).
- Hook VFS — modify `iterate_shared` on directory inodes to filter entries.
- Hide itself from `lsmod` by unlinking from the module list.
- Hide PIDs by removing them from `/proc`.
- Add a backdoor: a magic packet handler that, on receipt, spawns a root shell.

Pain points:
- **Kernel version coupling** — an LKM compiled for 5.15.0-86 may not load on 5.15.0-91.
- **Secure Boot / kernel lockdown** — refuses unsigned modules.
- **kpatch / livepatch** — defenders use the same mechanism; you may collide.

## Detection (so you know what works)

Userland LD_PRELOAD detection:
- `ldd /bin/ls` shows your `.so`.
- `cat /etc/ld.so.preload` shows it.
- `strings /etc/ld.so.preload` from a recovery boot bypasses your hook.
- A statically-linked busybox `ls` bypasses you.

LKM detection:
- `lsmod` (if you didn't hide).
- `cat /proc/modules`.
- `dmesg` taint flags (`P`, `O`).
- `/sys/module/<name>`.
- Volatility or LiME memory captures.

Rootkit hunters: `chkrootkit`, `rkhunter`, `lynis`, `unhide`. Modern EDRs (Falco, CrowdStrike) are far stricter than these.

## OSEP relevance

OSEP doesn't ask you to write a production rootkit. It does ask you to:
- Understand how rootkits hide things (so you can detect them on a competitor's box).
- Drop a *simple* LD_PRELOAD or PAM-module backdoor for persistence.
- Recognise auditd / Falco / EDR rules that would catch each layer.

A solid practice goal: ship a 100-line LD_PRELOAD that hides a file, a PID, and a network connection, then verify which forensic tools see it and which don't.

## Defensive notes (what your client should be doing)

- Mount `/etc` read-only after bake.
- Sign LKMs and enable Secure Boot.
- Monitor `/etc/ld.so.preload` with file integrity.
- eBPF-based EDR (Falco) sees through most userland hooks.
- Live-response with a known-good statically-linked toolchain (BusyBox).

## References
- [Symantec — Adore-NG and the LKM history](https://docs.broadcom.com/) (research papers)
- [Phrack — LKM HACKING](http://phrack.org/issues/61/14.html)
- [x-c3ll — PAM backdoor write-up](https://x-c3ll.github.io/posts/PAM-backdoor/)
- [Bedrock Linux rootkit detector](https://github.com/) (search)
- See also: [[linux-post-exploitation-tradecraft]], [[ld-preload-abuse]], [[kernel-exploits-linux]], [[osep-roadmap]]

{% endraw %}
