---
title: Session hijacking from source review
slug: session-hijacking-from-source
aliases: [session-management-audit, session-fixation-source]
---

> **TL;DR:** Audit session management by reading the session middleware/configuration, not by fuzzing cookies. Look for predictable session IDs, missing regeneration on auth state change, absent cookie flags, and session fixation in framework-specific code.

## What it is
Session hijacking from source means auditing how the application creates, stores, validates, and destroys sessions by reading the code rather than testing blind. The source reveals weaknesses that are invisible from the outside — predictable ID generation, fixation-prone login flows, overly broad cookie scopes, and missing invalidation on password change.

## Preconditions / where it applies
- Whitebox access to a web application's session management code
- Knowledge of the framework's session subsystem (Django, Rails, Express, Spring, PHP, etc.)
- Related to [[xss-from-source-review]] — XSS is the primary delivery mechanism for session theft

## Predictable session IDs

**What to audit:** The session ID generation function. Secure frameworks use CSPRNGs; custom implementations often don't.

```python
# VULNERABLE — predictable: MD5 of timestamp + username
import hashlib, time
session_id = hashlib.md5(f"{time.time()}{username}".encode()).hexdigest()

# SECURE — Python stdlib CSPRNG
import secrets
session_id = secrets.token_hex(32)
```

```java
// VULNERABLE — java.util.Random is predictable (linear congruential)
String sessionId = Long.toHexString(new Random().nextLong());

// SECURE — SecureRandom uses OS entropy
String sessionId = new BigInteger(130, new SecureRandom()).toString(32);
```

```php
// VULNERABLE — custom session ID from mt_rand (Mersenne Twister, predictable)
$sid = md5(mt_rand() . time());

// SECURE — use PHP's built-in session handler
session_regenerate_id(true);  // uses /dev/urandom internally
```

**Grep patterns:** `md5(.*time`, `Random()` (not `SecureRandom`), `mt_rand`, `Math.random`, `uuid1` (time-based, not random).

## Session fixation

Session fixation occurs when the app accepts a session ID set by the attacker and doesn't regenerate it after authentication.

**Vulnerable flow:**
1. Attacker visits login page, gets session ID `abc123`
2. Attacker sends victim a link with `?sessionid=abc123` (or sets the cookie via XSS/subdomain)
3. Victim logs in — server promotes `abc123` to an authenticated session
4. Attacker uses `abc123` — now authenticated as victim

**Source review — what to look for:**

```python
# Django — SECURE by default: calls cycle_key() on login
# But custom auth backends might skip it:
def custom_login(request, user):
    request.session['user_id'] = user.id  # VULNERABLE — no session regeneration
    # Missing: request.session.cycle_key()
```

```ruby
# Rails — reset_session should be called on login
def create
  user = User.authenticate(params[:email], params[:password])
  if user
    # VULNERABLE if reset_session is missing here
    session[:user_id] = user.id
  end
end

# FIXED:
def create
  user = User.authenticate(params[:email], params[:password])
  if user
    reset_session  # Destroys old session, creates new one
    session[:user_id] = user.id
  end
end
```

```php
// PHP — session_regenerate_id(true) must be called on login
session_start();
if (authenticate($user, $pass)) {
    // VULNERABLE without this line:
    session_regenerate_id(true);  // true = delete old session file
    $_SESSION['user'] = $user;
}
```

**Grep patterns:** Search login/authentication handlers for absence of `cycle_key`, `reset_session`, `session_regenerate_id`, `changeSessionId`, `invalidate().then(create)`.

## Missing cookie flags

Read the session configuration, not the HTTP response headers — the source is the ground truth.

```python
# Django settings.py
SESSION_COOKIE_HTTPONLY = True   # Blocks document.cookie access (XSS mitigation)
SESSION_COOKIE_SECURE = True    # Cookie only sent over HTTPS
SESSION_COOKIE_SAMESITE = 'Lax' # CSRF mitigation
CSRF_COOKIE_HTTPONLY = True
```

```javascript
// Express / express-session
app.use(session({
    secret: process.env.SESSION_SECRET,
    cookie: {
        httpOnly: true,    // MUST be true
        secure: true,      // MUST be true in production
        sameSite: 'lax',   // or 'strict'
        maxAge: 3600000
    },
    resave: false,
    saveUninitialized: false
}));
```

```php
// php.ini or runtime
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.cookie_samesite', 'Lax');
ini_set('session.use_strict_mode', 1);  // Rejects uninitialized session IDs
```

| Flag | Missing = | Impact |
|------|-----------|--------|
| `HttpOnly` | XSS can read `document.cookie` | Session theft via XSS |
| `Secure` | Cookie sent over HTTP | Network sniffing captures session |
| `SameSite` | Cookie sent on cross-origin requests | CSRF, cross-site request attacks |

## Cookie scope issues

```python
# DANGEROUS — cookie set on parent domain, shared with all subdomains
SESSION_COOKIE_DOMAIN = '.example.com'
# Any subdomain (even user-controlled ones) can read/write this cookie
```

A cookie scoped to `.example.com` is accessible to `evil.user.example.com`. If the app allows user-controlled subdomains (SaaS multi-tenant), this is a session hijacking vector.

## Concurrent session handling

Check whether the app limits active sessions per user:

```python
# No concurrent session control — attacker's stolen session stays valid
# even after the victim logs in again from another device

# SECURE pattern: track sessions per user, invalidate old ones on login
def login(request, user):
    # Kill all existing sessions for this user
    Session.objects.filter(user=user).delete()
    request.session.cycle_key()
    request.session['user_id'] = user.id
```

## Session invalidation on password change

**Critical check:** Does changing the password destroy all other sessions?

```python
# VULNERABLE — password changes but sessions persist
def change_password(request):
    request.user.set_password(request.POST['new_password'])
    request.user.save()
    # All other sessions for this user remain valid!

# FIXED — invalidate all sessions, re-auth current
from django.contrib.auth import update_session_auth_hash
def change_password(request):
    request.user.set_password(request.POST['new_password'])
    request.user.save()
    update_session_auth_hash(request, request.user)  # Keeps current session, kills others
```

**Grep patterns:** Search password-change handlers for presence/absence of session invalidation calls. Also check: password reset, email change, role change, and account deactivation flows.

## References
- [[xss-from-source-review]] — XSS is the #1 vector for stealing sessions client-side
- [[oswe-exploit-scripting-guide]] — scripting cookie extraction chains
- [[ruby-rails-audit-patterns]] — Rails session store and `reset_session`
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
