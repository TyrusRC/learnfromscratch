---
title: Secrets-in-code detection patterns
slug: secrets-in-code-detection-patterns
aliases: [secret-scanning, hardcoded-credentials]
---

{% raw %}

> **TL;DR:** Hardcoded secrets in source are still the most-exploited finding in bug-bounty and red-team work. Audit covers active branches, history, build artefacts, CI logs, and external storage (S3, Docker images). High-precision regex catches the obvious ones; entropy + context catches the subtle ones. Real protection: pre-commit hooks + CI scanning + secret manager + rotation policy.

## What it is
A "secret" is any credential, token, or key whose disclosure breaks an authorization boundary: API keys, OAuth client secrets, database passwords, SSH private keys, JWT signing secrets, encryption keys, cookie signing keys, webhook secrets.

## Where they hide
1. **Source files** — config files (`.env`, `application.yml`, `secrets.toml`), code constants, tests with real creds.
2. **Git history** — committed once, removed in HEAD, still in history.
3. **Build artefacts** — Docker images (layered FS), JS bundles (env vars baked in by Vite/webpack), compiled binaries (string literals).
4. **CI logs** — `echo $SECRET` in a script that prints to logs; CI artifact uploads.
5. **External docs** — README example, Postman exports, Slack messages, support tickets.
6. **Backup files** — `.bak`, `.swp`, `.orig`, Vim undo files.

## Detection by shape

### High-signal regex (low false-positive)
- AWS Access Key: `AKIA[0-9A-Z]{16}`
- AWS Secret Access Key (when paired): `[A-Za-z0-9/+=]{40}` after `aws_secret_access_key` token.
- GitHub PAT: `ghp_[A-Za-z0-9]{36}`, `gho_`, `ghu_`, `ghr_`, `ghs_`.
- Slack bot token: `xoxb-[0-9]+-[0-9]+-[A-Za-z0-9]+`.
- Stripe key: `sk_live_[0-9a-zA-Z]{24,}`.
- Twilio: `AC[0-9a-f]{32}`.
- Google API key: `AIza[0-9A-Za-z\-_]{35}`.
- SendGrid: `SG\.[0-9A-Za-z\-_]{22}\.[0-9A-Za-z\-_]{43}`.
- JWT: `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`.
- Private keys: `-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----`.

### Lower-signal entropy
- Base64 strings >32 chars with high Shannon entropy in non-binary file types.
- Hex strings ≥40 chars in code.
- These produce FP; combine with context (variable name contains `secret`/`token`/`key`/`pass`).

### Context indicators
- Variable names: `*_SECRET`, `*_KEY`, `*_TOKEN`, `*_PASSWORD`, `apikey`, `client_secret`.
- File names: `secrets.*`, `*.pem`, `*.key`, `id_rsa*`, `.env*`, `credentials`, `kubeconfig`.
- Function names: `decrypt`, `signWith`, `authenticate`.

## Audit workflow

### Repo + history
```bash
# Trivy / gitleaks / detect-secrets — the workhorses
gitleaks detect --no-banner

# Find every .env-ish file in history
git rev-list --all | xargs -I{} git ls-tree -r {} | grep -E '\.env|secret|credential|\.key$|\.pem$' | sort -u

# Find blobs above an entropy threshold (proxy: file size + filename)
git rev-list --all --objects | sort -u

# truffleHog
trufflehog git file://. --no-update
```

### Build artefacts
- Docker: `docker history --no-trunc <image>` shows each layer's command. `dive` interactively walks the FS — find `.env` files committed into early layers and removed in later ones.
- JS bundles: `grep -rE 'sk_live_|ghp_|AKIA' dist/`.
- Java/.NET: decompile (Procyon, ILSpy) and grep — string literals survive.

### CI logs
- Search public CI providers (GitHub Actions, GitLab, CircleCI) for accidentally-public logs.
- `printenv` / `env` in scripts is a common slip.
- Self-hosted runner artefact uploads.

### External
- Postman public workspaces (`https://www.postman.com/<workspace>`).
- npm published packages — `npm view <pkg> dist`, then inspect.
- Public S3 buckets / GCS / Azure blob: passive recon via `s3scanner`, `cloud_enum`.

## Tools

### Pre-commit / dev-machine
- **`gitleaks`** — fast, low FP, integrates as pre-commit.
- **`detect-secrets`** (Yelp) — baseline-driven, good for monorepos.
- **`talisman`** — pre-push hook variant.
- **`trufflehog`** — high recall, more FP.

### CI
- `gitleaks --redact` in PR builds — fail PR on new secrets.
- GitHub Secret Scanning (built-in, free, scans public repos and private if enabled).
- GitLab Secret Detection.
- Snyk Code / Semgrep have secret rules.

### Production scanning
- Periodic full-history scan on every repo.
- Built artefact scan in container registry.

## Hardening

### Prevention
- Pre-commit `gitleaks` hook org-wide.
- Strict `.gitignore` for `.env*`, `secrets/*`, `*.pem`, IDE config.
- Template files only: `.env.example` with `KEY=replace-me`.
- Secret manager (Vault, AWS Secrets Manager, Doppler, 1Password) for runtime values.

### When you find one
1. **Assume compromised.** Rotate immediately. Do NOT wait to investigate first.
2. **Audit logs** for use of the credential.
3. **Purge from history** is irrelevant if the secret was public for any window. Rotation + audit are the only mitigations.
4. **For internal secrets**: still rotate; insider risk + future leak risk.

### Detection beyond text matching
- Honeytokens — fake AWS keys committed deliberately that page on any use. CanaryTokens / Thinkst Canary.
- Cloud-provider deception (AWS Detective, GCP Recommender) — alerts on key use from unusual IP.

## References
- [gitleaks](https://github.com/gitleaks/gitleaks)
- [trufflehog](https://github.com/trufflesecurity/trufflehog)
- [GitHub secret scanning patterns](https://docs.github.com/en/code-security/secret-scanning/secret-scanning-patterns)
- [OWASP secrets management cheatsheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [CanaryTokens](https://canarytokens.org/)
- See also: [[github-recon]], [[git-source-leakage]], [[backup-and-config-leakage]]

{% endraw %}
