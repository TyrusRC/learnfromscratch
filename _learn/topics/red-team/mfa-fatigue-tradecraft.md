---
title: MFA fatigue / push-bombing tradecraft
slug: mfa-fatigue-tradecraft
aliases: [mfa-fatigue, mfa-push-bombing, push-fatigue]
---

> **TL;DR:** MFA fatigue exploits the cognitive load of repeated push prompts. Attacker has the victim's password and triggers many push notifications in a short window; eventually the victim approves to make the prompts stop. Used famously in the Uber 2022 breach. Defeated by number-matching push, contextual push (showing IP/geo/app), and phish-resistant FIDO2. Companion to [[aitm-evilginx-modern-phishing]] and [[conditional-access-bypass-modern]].

## Why it still works

- Push prompts are designed to be **frictionless** — a single tap.
- Users associate prompts with **their own activity**, not adversary activity.
- The first prompt at 3am is alarming; the tenth is annoying; the fiftieth is "I'll just approve to stop it."
- Push apps default to **silent** vibration; many users approve while in meetings to silence notifications.
- The credential validity is **unchanged** — push approval gives the attacker the same MFA token as the user.

## The mechanic

Pre-conditions:
- Attacker has the victim's username and password (credential stuffing / breach data / phishing).
- Victim's MFA method is push (not TOTP, not FIDO2).
- The IdP doesn't rate-limit failed pushes effectively.

Sequence:
1. Attacker initiates sign-in at the IdP.
2. IdP sends push to victim's device.
3. Victim ignores or denies.
4. Attacker retries — IdP sends another push.
5. Loop. Some IdPs throttle after N pushes per minute; many don't.
6. Victim eventually approves to stop the noise.
7. Attacker has session; immediately enrolls a new device / changes password / pivots.

## Uber 2022 case

The Uber September 2022 breach used MFA-fatigue against a contractor account. After repeated push prompts, the attacker contacted the contractor on WhatsApp posing as IT and asked them to approve the push to "fix the notification spam." Contractor approved. Attacker logged in, found internal documentation pointing to credential stores, escalated to wider compromise.

The combination of **MFA fatigue + WhatsApp social engineering** is the playbook now.

## Variants

- **Targeted timing** — push during a meeting, while travelling, late at night.
- **Multi-channel** — send simultaneous prompts to push + SMS to maximise confusion.
- **Tab-impersonation** — open a tab claiming to be IT support page, accompany the push.
- **Voice-call coercion** — phone the victim mid-prompt-storm, urge them to approve.
- **Deepfake voice** — see [[deepfake-assisted-phishing]].

## Defensive baseline

### Number-matching push

The push prompt shows a number, and the user must type it into the device that initiated the auth. AitM proxies can capture the number (it's in the IdP's response) but **MFA fatigue specifically** is defeated — there's no number for the user to type.

### Contextual push

Push prompt shows:
- Application name (e.g., "Outlook").
- IP and city of the requester.
- User-agent / device type.

User sees "Outlook from Lagos, Nigeria" when they're in London → denies.

Microsoft Authenticator and Duo support this.

### Phish-resistant MFA

FIDO2 / passkeys / Windows Hello for Business / certificate-based auth. The user can't "accidentally" approve — they must perform an explicit physical interaction. Defeats both MFA fatigue and AitM.

### Rate-limit pushes

IdPs should throttle pushes from a single source after N within a window. Some do this by default; many leave it tunable.

### User training

- **"Never approve a push you didn't initiate, even if the prompts won't stop."**
- **Report the prompts** to security via a one-tap "this isn't me" path.
- **Sign out and back in** to break the loop.

### Identity Protection / risk-based MFA

Detect the access-pattern of repeated push-denials followed by approval; treat as risky sign-in; require additional verification.

## Recon for red team (authorised engagement)

If MFA fatigue is in scope:
- Confirm target's MFA method via OSINT / leaked breach data.
- Confirm IdP push-prompting behaviour with test account.
- Plan timing for psychological effectiveness.
- Coordinate with internal sponsor on detection thresholds.

## Detection signals

- N push prompts to one user within M minutes, particularly from different IPs.
- Sign-in following denied prompts.
- Sign-in from a new IP after push fatigue.
- User reports of unsolicited prompts.

## Workflow to study (defender lab)

1. Stand up a tenant with push MFA on a test account.
2. Use a scripted IdP login from a different machine; observe push delivery.
3. Trigger 50 pushes in 5 minutes; observe whether the IdP throttles.
4. Enable number-matching; observe attack failing.
5. Enable contextual info; observe attack failing.
6. Enable FIDO2; observe attack failing entirely.

## Related

- [[aitm-evilginx-modern-phishing]] — different MFA-bypass class.
- [[oauth-device-code-phishing-m365]] — different MFA-bypass class.
- [[tycoon2fa-and-modern-phish-kits]] — kit landscape.
- [[deepfake-assisted-phishing]] — companion social-engineering vector.
- [[conditional-access-bypass-modern]] — post-MFA-bypass operation.

## References
- [Uber 2022 incident statement](https://www.uber.com/newsroom/security-update/)
- [CISA — MFA fatigue advisory](https://www.cisa.gov/news-events/news/cisa-strongly-urges-organizations-implement-phishing-resistant-mfa)
- [Microsoft — number-matching documentation](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-mfa-number-match)
- [Duo — push security context](https://duo.com/blog/)
- See also: [[aitm-evilginx-modern-phishing]], [[oauth-device-code-phishing-m365]], [[conditional-access-bypass-modern]], [[deepfake-assisted-phishing]]
