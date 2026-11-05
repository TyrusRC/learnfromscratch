---
title: AD deception and honeypot evasion
slug: ad-deception-and-honeypot-evasion
aliases: [honeypot evasion, decoy accounts, AD honey tokens, canary evasion]
---

> **TL;DR:** Mature AD environments deploy deception: decoy accounts with SPNs (kerberoasting traps), honeytoken files on shares, canary tokens in documents, and fake admin accounts. BloodHound will happily path through decoys. Identifying and filtering them before attacking is critical for CRTP and any engagement against MDI/ATA-monitored domains.

## Types of AD deception

| Type | Purpose | Common tells |
|---|---|---|
| **Decoy user accounts** | Trigger alert on authentication attempt | Never-logged-on, SPN set, attractive name |
| **Honey credentials** | Cached creds that alert on use | Stored in LSASS/credential stores on endpoints |
| **Honeytoken files** | Alert on file open/read | Documents on shares with monitoring via audit policies |
| **Canary tokens** | Alert on DNS/HTTP callback | Embedded in docs, URLs, AWS keys |
| **Honey shares** | Alert on enumeration or access | Shares with attractive names, auditing enabled |
| **Decoy computer accounts** | Trigger on lateral movement attempts | Machine accounts with no real host behind them |
| **Azure AD honey accounts** | Cloud identity traps | Cloud-only accounts with conditional-access monitoring |

## Identifying decoy accounts

Decoys have telltale LDAP attributes. Query before attacking:

```powershell
# Accounts that have NEVER logged on (logonCount = 0)
Get-ADUser -Filter {logonCount -eq 0} -Properties logonCount, lastLogonTimestamp,
    servicePrincipalName, whenCreated, adminCount |
    Where-Object { $_.servicePrincipalName -ne $null } |
    Select-Object Name, logonCount, lastLogonTimestamp, whenCreated

# Accounts with SPN set but zero logon — classic kerberoast trap
Get-ADUser -Filter {servicePrincipalName -like "*" -and logonCount -eq 0} `
    -Properties servicePrincipalName, lastLogonTimestamp
```

**Red flags for decoy accounts:**
- `logonCount` is 0 or very low
- `lastLogonTimestamp` is null or equals `whenCreated`
- `pwdLastSet` is very old or equals `whenCreated` exactly
- Account name is unusually attractive: `svc_backup_admin`, `sql_sa`, `adm-legacy`
- Has SPN but no matching host in DNS
- `adminCount=1` but not in any real admin group (orphaned `adminCount`)
- Description says "do not delete" or "legacy" — lure language
- `userAccountControl` has "password never expires" but account has no logon history

```powershell
# Check if SPN target host actually exists
$spnUsers = Get-ADUser -Filter {servicePrincipalName -like "*"} -Properties servicePrincipalName
foreach ($u in $spnUsers) {
    foreach ($spn in $u.servicePrincipalName) {
        $host = ($spn -split '/')[1] -split ':' | Select-Object -First 1
        if (-not (Resolve-DnsName $host -ErrorAction SilentlyContinue)) {
            Write-Warning "POSSIBLE DECOY: $($u.Name) has SPN $spn — host not in DNS"
        }
    }
}
```

## BloodHound edge filtering for decoys

BloodHound collects everything. Before pathing to a target, filter:

```cypher
// Find kerberoastable users with zero logons — likely decoys
MATCH (u:User)
WHERE u.hasspn = true AND u.logoncount = 0
RETURN u.name, u.serviceprincipalnames, u.lastlogontimestamp

// Exclude suspected decoys from shortest-path queries
MATCH p = shortestPath((attacker:User {name:"YOURUSER@DOMAIN"})-[*1..]->(target:Group {name:"DOMAIN ADMINS@DOMAIN"}))
WHERE NONE(n IN nodes(p) WHERE n.logoncount = 0 AND n.hasspn = true)
RETURN p
```

Mark suspected decoys in BloodHound CE with tags or notes to avoid them in future queries.

## Honeytoken files and canary tokens

**Honeytoken files** are planted on file shares with audit policies (SACL) that trigger on read:

```powershell
# Detect honeytoken-style auditing on a share
Get-Acl "\\server\share\passwords.xlsx" -Audit | Format-List
# If SACL includes "Everyone / ReadData / Success" — it's a trap
```

**Canary tokens** (canarytokens.org, Thinkst) embed callbacks:
- Word/Excel docs with external template URLs — opening phones home
- DNS canaries — `nslookup UNIQUEID.canarytokens.com`
- AWS key canaries — using the key triggers an alert
- URL shortener canaries in internal wikis

**Evasion:**
- Don't open documents from shares blindly; inspect with `oletools` / `exiftool` first
- Check for external template links: `oleobj -e suspicious.docx`
- Don't use found AWS keys without checking if they're real (`sts get-caller-identity` from a burner)
- Proxy DNS through your own resolver to catch canary DNS patterns

## Azure AD honey accounts

Cloud-only accounts configured with:
- Conditional Access policies that alert on any sign-in
- Microsoft Sentinel analytics rule on the specific `ObjectId`
- No MFA configured (lure) but sign-in triggers immediate alert

**Detection indicators:**
- Account has no Azure AD sign-in logs ever (check via Graph API if you have access)
- Licensed but no mailbox, no Teams presence, no device registrations
- Created by security team OU/admin account

## MDI (Microsoft Defender for Identity) honeytoken detection

MDI has a built-in honeytoken feature:

```
# MDI portal → Settings → Entity tags → Honeytoken
# Any authentication / enumeration touching tagged accounts → alert
```

MDI detects:
- LDAP queries enumerating the honeytoken account
- Authentication attempts (kerberos, NTLM) against it
- SPN requests (kerberoasting) targeting it

**Bypass:** MDI honeytokens are tagged server-side — you can't query the tag via LDAP. Use the heuristic checks above (logonCount, lastLogon, DNS resolution) to identify them before touching them.

## Evasion checklist

- ✅ Before kerberoasting, filter out accounts with `logonCount = 0`
- ✅ Before lateral movement, verify target hosts resolve in DNS and respond to SMB
- ✅ Don't open random documents on shares — inspect metadata first
- ✅ Don't use found credentials without verifying they're real (check `lastLogon`)
- ✅ In BloodHound, exclude zero-logon nodes from attack paths
- ✅ Don't enumerate all users/SPNs in one LDAP query — paginate, space out

## Detection and defence (blue team perspective)

- Deploy decoy accounts in every OU with realistic names and SPNs
- Set SACL auditing on honeytoken files; forward events to SIEM
- Use MDI honeytoken tagging for instant alerting
- Rotate canary tokens periodically — stale ones get flagged and avoided
- Monitor for LDAP queries filtering on `logonCount=0` — that's someone hunting decoys

## References

- [Thinkst Canary / Canarytokens](https://canarytokens.org/)
- [Microsoft — MDI honeytoken accounts](https://learn.microsoft.com/en-us/defender-for-identity/entity-tags)
- [SpecterOps — BloodHound deception detection](https://posts.specterops.io/)
- [DVID — Detecting Deception in AD](https://github.com/stealthcopter/dvid)

See also: [[kerberoasting]], [[bloodhound]], [[bloodhound-ce-deployment]], [[defender-for-identity-evasion]], [[ad-recon-low-noise]], [[snaffler-share-mining]], [[host-recon-tradecraft]], [[opsec-fundamentals]]
