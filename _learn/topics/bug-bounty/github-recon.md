---
title: GitHub recon
slug: github-recon
---

> **TL;DR:** Search the target's GitHub org, employee accounts, and the global code index for leaked tokens, internal hostnames, and abandoned repos that ship the company's own secrets. Often the highest-value 30 minutes in a recon pass.

## What it is
GitHub hosts both intentional company code (`github.com/companyorg`) and accidental personal pushes by employees (test branches, dotfiles, side projects with prod creds). The code-search API indexes all public files. Targeted searches across both org and global scope surface secrets, hostnames, and architecture clues that no DNS scan would.

## Preconditions / where it applies
- Target has any presence on GitHub (almost universal)
- Program scope permits use of leaked credentials *only for proof, not for action* — read the policy
- You have a GitHub account with API tokens (rate-limit, search access)

## Technique
1. Map the org and people. Find the official org from the company website footer or README. Pull the public member list (visible members only); enrich with LinkedIn cross-reference for hidden members:

```
gh api /orgs/companyorg/members --paginate | jq -r '.[].login'
```

2. Org-scoped code search. The web UI's code search across `org:companyorg` is the bread and butter. Useful query patterns:

```
org:companyorg "BEGIN RSA PRIVATE KEY"
org:companyorg filename:.env
org:companyorg "Authorization: Bearer"
org:companyorg "aws_access_key_id"
org:companyorg "password" extension:yml
org:companyorg jenkins.target.tld
org:companyorg "internal.target.tld"
```

3. Employee-scoped search. Pivot to each employee's personal repos (`user:alice`) and run the same patterns — dotfiles often contain real tokens.
4. Global search by target hostname / internal naming convention. If the company uses `corp-internal-*` codenames, those leak in unrelated developers' repos:

```
"jdbc:postgresql://prod-db.corp.target.tld"
"@target-internal.tld"
```

5. Automate with `gitleaks`, `trufflehog`, `gitrob`, `gitGraber`. These re-scan known repos for newly-committed secrets, ideal for the [[continuous-recon-automation]] layer.
6. Forks and abandoned repos. A repo deleted from the org may live on as a fork — `github.com/exfork/companyorg-internal-tool`. Use `https://github.com/<user>/<repo>/network` and Google `site:github.com "companyorg" forked`.
7. Validate before reporting. A leaked token must be confirmed live (call the API; don't post on behalf of the account). For AWS keys, `aws sts get-caller-identity` — read-only, signals nothing.

## Detection and defence
- GitHub Secret Scanning / push-protection enabled at the org level rejects pushes containing known credential formats; turn it on org-wide
- Use `git-secrets` / pre-commit hooks; rotate any credential that ever touched a public commit
- Audit org member visibility; default to "private" for organisation membership to limit pivot
- For hunters: never use a leaked credential to access live infrastructure unless the program explicitly allows it — proof of live = a request returning a sensitive-but-self-evident response, not data exfiltration

## References
- [GitHub Code Search syntax](https://docs.github.com/en/search-github/searching-on-github/searching-code) — operators and filters
- [Bug Bounty Hunter — GitHub recon guides](https://www.bugbountyhunter.com/) — methodology writeups
- [trufflehog](https://github.com/trufflesecurity/trufflehog) — credential scanner with live-verification
- [HackTricks — GitHub recon](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/github-leaked-secrets.html) — workflow + dorks
