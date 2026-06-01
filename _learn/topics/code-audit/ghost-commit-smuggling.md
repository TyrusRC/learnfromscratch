---
title: GitHub ghost-commit smuggling
slug: ghost-commit-smuggling
---

> **TL;DR:** GitHub keeps unreferenced commits alive — pushed-then-deleted branches, force-pushed history, fork PRs from deleted repos — and still serves them via `/commit/<sha>` and the Events / Archive APIs. Useful for stealth-staging payloads, leaking secrets, and forging provenance.

## What it is
A "ghost commit" is a Git object that no ref points to but is still reachable via its SHA on GitHub's storage. Git's local GC would prune it; GitHub does not, because forks share the same object pool and the activity is indexed in the Events API and GH Archive. Attackers and red teams exploit this to host arbitrary files under a victim org's URL, to hide payloads, or to fake the appearance that a maintainer authored malicious code.

## Preconditions / where it applies
- GitHub.com (most behaviours also apply to public GHES instances)
- Any public repo you can push to — typically via a fork
- Need to predict / brute-force a commit SHA, or just retain it after force-push

## Technique
1. **Stage the commit.** Fork the victim repo. Commit a payload (script, leaked credentials, large file). Push the branch.
2. **Detach it.** Delete the branch (or force-push it away). The commit becomes unreachable from any ref in your fork — but `https://github.com/<victim>/<repo>/commit/<SHA>` still resolves, served from the shared object store between fork and upstream.
3. **Smuggle URLs.** `raw.githubusercontent.com/<victim>/<repo>/<SHA>/path/file` returns the file. Loader stagers can point at the victim org URL — looking like a first-party download.
4. **Provenance forgery.** Sign the commit with a key tied to a public email of a real maintainer, or simply set `user.email` to their public commit email — GitHub will show "Verified" if a GPG/SSH/SigStore signing key on that account matches. The commit then appears on `/<victim>/<repo>/commit/<sha>` as authored by them, even if no PR was opened.
5. **Discovery via Events / Archive.** `https://api.github.com/repos/<owner>/<repo>/events` and the [GH Archive](https://www.gharchive.org/) record every `PushEvent` SHA at the time of push. Attackers can mine these for secrets pushed and quickly force-removed; defenders should mine them too.
6. **Cross-fork leakage.** Even private repos forked from public ones share the object pool — pushing a sensitive file to a fork can leak via the parent if the SHA is known.

## Detection and defence
- For orgs: enable **push protection** (secret scanning) — blocks pushes containing detected secrets, including to forks of public repos
- Treat any leaked secret as compromised the moment it lands in a `PushEvent`, even if the branch is force-deleted seconds later
- Monitor GH Archive for your org names + suspicious commit messages / large blobs
- For private monorepos forked from a public ancestor: switch to a clean repo (re-init) to break the shared object pool
- Detect ghost-commit hosting in your supply chain by pinning dependencies to tags + verified signatures, not arbitrary SHAs that may be unreferenced
- Related: see [[supply-chain-attacks]] for the broader category

## References
- [Ghost commit smuggling — instatunnel.my](https://instatunnel.my/blog/github-ghost-commit-smuggling-hiding-in-the-detached-head) — original write-up of the technique
- [GH Archive](https://www.gharchive.org/) — public push event corpus
- [GitHub — about cross-fork object sharing](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks) — official docs on the shared pool model
- [Truffle Security — GitHub Archive secret hunting](https://trufflesecurity.com/blog) — research into mining historical pushes
