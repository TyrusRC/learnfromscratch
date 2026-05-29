---
title: "Cloud foothold playbook"
slug: cloud-foothold-playbook
aliases: [cloud-foothold, cloud-token-now-what]
mermaid: true
---

> **TL;DR.** You have cloud credentials, a managed-identity token, a
> CI/CD secret, or a session token. This playbook picks the next
> move per provider and stops you from wasting calls on the wrong
> service.

## Step 1 — identify what you have

```mermaid
flowchart TD
    A[Hold something cloud-shaped] --> B{What kind?}
    B -- "Long-lived access key / secret (AWS_ACCESS_KEY_ID)" --> C[AWS — Step 2 AWS]
    B -- "STS temporary creds (session token)" --> D[AWS — Step 2 AWS but watch TTL]
    B -- "Azure CLI cache (msal_token_cache, accessTokens.json)" --> E[Azure / Entra — Step 2 Azure]
    B -- "GCP service-account JSON / impersonated token" --> F[GCP — Step 2 GCP]
    B -- "Kubeconfig / ServiceAccount token" --> G[Kubernetes — Step 2 K8s]
    B -- "OIDC JWT from CI (GHA / GitLab)" --> H[CI/CD — Step 2 CI]
    B -- "SSO refresh token / device-code token" --> I[Persistence-grade — see entra-device-code-prt-pivot / aws-sso-device-code-phishing]
```

## Step 2 AWS — what role am I?

```mermaid
flowchart TD
    A[AWS creds in hand] --> B[aws sts get-caller-identity]
    B --> C{Role / user?}
    C -- "User" --> D[List own policies — iam:GetUser, iam:ListAttached*]
    C -- "Role (EC2 / Lambda / federated)" --> E[List session permissions via aws iam simulate-principal-policy]
    D --> F[Open aws-iam-enum — map allowed services]
    E --> F
    F --> G{Permissions allow what?}
    G -- "Admin-equivalent (iam:*, sts:AssumeRole, etc.)" --> H[Full escalation — list roles, AssumeRole into higher tier]
    G -- "s3:*" --> I[Open aws-s3-attacks — dump buckets]
    G -- "secretsmanager:GetSecretValue" --> J[Open aws-secrets-manager]
    G -- "lambda:UpdateFunctionCode" --> K[Open aws-lambda-attacks — backdoor Lambda]
    G -- "iam:PassRole + ec2:RunInstances" --> L[Boot EC2 as higher-priv role]
    G -- "Cross-account sts:AssumeRole" --> M[Open aws-cross-account]
    G -- "Limited but persistent" --> N[Open aws-rogue-oidc-idp-persistence or aws-iam-eventual-consistency-persistence]
```

## Step 2 Azure / Entra — what tenant and identity?

```mermaid
flowchart TD
    A[Azure token in hand] --> B[Decode JWT — note tid, oid, scp, aud]
    B --> C{What kind of token?}
    C -- "User access token" --> D[Roadtools / AzureHound enum]
    C -- "Service principal" --> E[Open service-principal-abuse]
    C -- "Managed identity (instance metadata)" --> F[Open managed-identities]
    C -- "Refresh token / PRT" --> G[Open entra-device-code-prt-pivot]
    D --> H[Open entra-id-enum — map directory + role assignments]
    E --> H
    F --> H
    G --> H
    H --> I{What's reachable?}
    I -- "Global Admin / Privileged Role Admin" --> J[Full tenant — proceed to persistence]
    I -- "Application Administrator / Cloud Application Admin" --> K[Open app-registration-abuse — add credential to high-priv SP]
    I -- "Owner on enterprise app" --> K
    I -- "Key Vault data plane" --> L[Open azure-key-vault-attacks]
    I -- "Cross-tenant signals" --> M[Open entra-actor-token-cross-tenant or entra-cross-tenant-sync-abuse]
    I -- "Hybrid (Entra Connect on-prem)" --> N[Open entra-connect-exploitation-2025]
```

## Step 2 GCP — service account or human?

```mermaid
flowchart TD
    A[GCP credentials] --> B[gcloud auth list; gcloud config list]
    B --> C{Identity type?}
    C -- "Compute SA (default)" --> D[Check scope — often 'cloud-platform' = god]
    C -- "Custom SA" --> E[gcloud projects get-iam-policy — enumerate role]
    C -- "User account" --> F[gcloud organizations list — bigger picture]
    D --> G[Open gcp-service-account-enum]
    E --> G
    F --> G
    G --> H{Permissions allow what?}
    H -- "iam.serviceAccounts.actAs" --> I[Impersonate higher-priv SA — open gcp-iam-misconfig]
    H -- "storage.objects.*" --> J[Open gcs-attacks]
    H -- "compute.instances.setMetadata" --> K[Inject startup script — RCE on VM]
    H -- "Organization Admin" --> L[Full org — proceed to persistence]
```

## Step 2 Kubernetes — pod or external?

```mermaid
flowchart TD
    A[K8s creds] --> B[kubectl auth can-i --list]
    B --> C{What verbs?}
    C -- "create pods + cluster-wide" --> D[Open k8s-rbac-abuse — launch privileged pod]
    C -- "create pods (namespace) + hostPath" --> E[Open k8s-host-mount-escape]
    C -- "impersonate users / SAs" --> F[Open k8s-rbac-abuse — impersonate cluster-admin]
    C -- "get secrets" --> G[Pull cloud credentials from secrets, jump to cloud branch]
    C -- "Read kubelet creds via node metadata" --> H[Open k8s-service-account-tokens]
    C -- "Reach etcd directly" --> I[Open k8s-etcd-attacks — full cluster state]
    C -- "Admission webhook control" --> J[Open k8s-admission-controllers]
```

## Step 2 CI/CD OIDC

```mermaid
flowchart TD
    A[OIDC token from CI] --> B{Trust policy of target role}
    B -- "Wildcards in sub claim" --> C[Open gha-oidc-sub-claim-wildcards — any fork can assume]
    B -- "Tight sub claim" --> D[Find PR / branch that satisfies it]
    C --> E[STS AssumeRoleWithWebIdentity — proceed as cloud creds]
    D --> E
    E --> F[Drop into Step 2 AWS / Azure / GCP branch above]
```

## Step 3 — escalate or pivot

```mermaid
flowchart TD
    A[Initial creds mapped] --> B{Goal of engagement}
    B -- "Full admin in this account / tenant" --> C[Continue per-provider escalation tree]
    B -- "Exfil specific data" --> D[Identify data store — go direct, don't escalate unnecessarily]
    B -- "Persistence-grade access" --> E[Choose stealthy persistence — see provider-specific topic]
    C --> F[Loop: re-list permissions after each grant]
```

## Step 4 — persistence (in-scope only)

```mermaid
flowchart TD
    A[Want to stay] --> B{Provider}
    B -- AWS --> C[Open aws-rogue-oidc-idp-persistence + aws-iam-eventual-consistency-persistence + aws-cloudtrail-policy-size-evasion]
    B -- Azure --> D[Open app-registration-abuse — add cert credential; survives password reset]
    B -- GCP --> E[Create SA key on a benign-looking SA; long-lived]
    B -- K8s --> F[Create ServiceAccount + ClusterRoleBinding; rotate quietly]
```

## Detection-aware notes

- AWS CloudTrail catches almost everything by default — see
  [[aws-cloudtrail-policy-size-evasion]] for the modern evasion
  surface.
- Entra unified audit log covers most plane calls but has known
  gaps on cross-tenant; see [[entra-actor-token-cross-tenant]].
- GCP audit logs default off on data-plane reads — exfil through
  GCS / BigQuery is quieter than the equivalent on AWS.
- K8s audit log is opt-in per cluster; assume it's off.

## Anti-patterns

- Calling `iam:ListUsers` / `iam:ListRoles` on a 10k-user account
  with no rate-limit — instant detection.
- Running ScoutSuite / Pacu / Prowler full-scan against a target
  account — fine in your own lab, loud in a real engagement.
- Assuming Azure CLI tokens are short-lived — refresh tokens last
  90 days by default.

## Where to go next

- Got admin → [[cloud-red-team]] path for persistence + opsec.
- Got K8s admin → consider whether you also want host node access
  (see [[k8s-host-mount-escape]]).
- Got AD CS / Entra hybrid surface → swing back to
  [[ad-attack-path-playbook]].
