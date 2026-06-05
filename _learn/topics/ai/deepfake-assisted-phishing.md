---
title: Deepfake-assisted phishing
slug: deepfake-assisted-phishing
aliases: [deepfake-phishing, voice-cloning-phishing]
---

{% raw %}

> **TL;DR:** Voice cloning needs 30 seconds of audio; video deepfakes need a minute or two of source footage. In 2024-25 real engagements began incorporating: (1) voice-cloned CFO calling AP for wire transfers, (2) live deepfake video on Zoom for "executive direction" SE, (3) AI-generated phishing copy at scale, (4) AI-generated supporting evidence (fake LinkedIn profiles, screenshots). Defence shifts from "spot the grammar errors" to "verify out-of-band". Companion to [[phishing-infrastructure-design]] and [[pretext-design-for-engagements]].

## What's now feasible

| Capability | What you need | Output quality |
|---|---|---|
| Voice clone | 30s of clean audio | indistinguishable on phone in casual context |
| Real-time voice over phone | clone + Voicebox / ElevenLabs / RVC | near-real-time with 200-500ms latency |
| Live video deepfake on Zoom | source video + DeepFaceLive / FaceFusion | passable in low-light; tells visible on closer look |
| Style-matched phishing copy | LLM + a sample of target's tone | indistinguishable from human |
| Synthetic employee LinkedIn | LLM + synthesised profile picture | passes casual scrutiny |

## Real-world incidents (public)

- 2019: UK CEO scam — voice-cloned executive directed €220k wire transfer.
- 2024: Arup HK engineer joined a "Zoom call" with multiple deepfaked executives, transferred $25M.
- Many smaller incidents at SMB scale; under-reported.

## Attack chain — voice-clone wire transfer

1. **Recon.** Identify the target — typically AP or treasury staff who can authorise wires.
2. **Voice harvest.** Pull 30-60s of the impersonated executive's voice from:
   - YouTube earnings calls, conference talks.
   - Company podcast / town hall.
   - Voicemail (in some cases, public).
3. **Clone.** ElevenLabs / RVC / Tortoise-TTS produces a voice model.
4. **Timing.** Off-cycle (Friday afternoon, executive away on travel).
5. **Pretext.** "Urgent — I'm with a vendor at a contract closing — wire $X to $Y by 5pm, will email confirmation".
6. **Spoofed CallerID.** VOIP services let you spoof; arrives as "CEO_NAME on CallerID".
7. **Execute.** AP processes wire.
8. **Cover.** "Don't email me; I'm in meetings" — kills the verification step.

## Defence

- **Out-of-band verification.** Pre-agreed phrase / code for wire approval, communicated via separate channel.
- **Multi-party authorisation.** No single approver for large wires.
- **Time-delay.** Wires above threshold delayed 4-24 hours.
- **Caller ID training.** Staff trained that Caller ID is not authentication.
- **Voice biometric** — limited availability; can be evaded but adds friction.

## Attack chain — live Zoom deepfake

1. **Source video.** YouTube interview, internal video shared externally.
2. **Train.** DeepFaceLive / SimSwap / FaceFusion. A consumer GPU produces real-time face-swap.
3. **Hardware setup.** Webcam → OBS Virtual Camera (with face swap applied) → Zoom.
4. **Voice clone for matching audio**.
5. **Call victim.** Schedule the meeting via a plausible-looking calendar invite.
6. **Direct.** "Confirm this transaction now; don't loop anyone else in."

Tells (still detectable in many cases):
- Slow blink rate, unusual lighting on face boundary.
- Reflections in glasses don't match.
- Hand gestures partially occluding face cause artefacts.
- Voice latency mismatch.

Defence:
- Pre-scheduled meetings only from trusted calendar systems.
- Multi-party for high-stakes decisions.
- Liveness challenges — "Touch your left ear" (deepfakes struggle with novel hand-on-face).
- Skepticism training; "did this person just ask me to authorise a wire?" → escalate.

## Attack chain — AI-generated phishing at scale

LLM-written phishing:
- Tailored per target (LinkedIn-mined details).
- Grammar perfect.
- Matches the target company's tone.
- Generated at the rate of one per second.

A phishing campaign that used to take a week of copywriting can be generated in an hour.

Defence:
- Email gateways now use LLM-vs-LLM detection (less effective; arms race).
- Banner labels on external mail still help.
- Phishing-simulation training that includes AI-generated lures.

## Attack chain — synthetic employee

Job-search platforms used by attackers:
- Apply for a remote role with a synthetic profile.
- Pass video interview using deepfake.
- Get hired; insider threat from day one.

Reports from 2023-25 indicate this is happening at meaningful frequency, particularly for software roles.

Defence:
- Live in-person onboarding before access provisioning.
- Background checks beyond ID verification.
- Behavioural-anomaly detection on early-tenure employees.

## Attack chain — synthetic evidence for OSINT poisoning

Attacker generates supporting evidence for a scam:
- Fake LinkedIn profiles of co-workers / vendors.
- Synthesised GitHub commit history.
- Fake reference letters.
- AI-generated company website at a typo-squat domain.

When the victim "verifies" by Googling, the search results look consistent.

Defence:
- Don't accept LinkedIn as authoritative.
- Use known-good directories (vendor records, customer-listed contacts).
- Multi-source verification.

## Engagement use (pentest)

If your engagement letter explicitly authorises social engineering with synthetic media:
- Document the source video clip used.
- Capture audio waveform of cloned voice for evidence.
- Don't conduct real transfers; demonstrate to the point of "would have happened".
- Don't impersonate a specific executive without explicit written permission from that executive.

Many engagement letters now have a "no deepfake of executives by name" clause.

## Detection — defender side

- **Liveness checks** in video calls (Zoom is adding native; vendor-specific).
- **Voice biometric matching** (limited deployment).
- **Synthetic-media detection** APIs (Reality Defender, Sensity, Microsoft Azure AI Content Safety).
- **OOB verification** policy.

## OSCP/OSEP/OSWE relevance

Out of scope. Important for SE engagements and real-world risk modelling.

## Legal

Voice-cloning a specific person without their consent for fraudulent purposes is illegal in most jurisdictions. Engagement-letter authorisation must be explicit and specific. Cross-border (USA SAG-AFTRA, EU AI Act, deepfake laws in China, South Korea) varies widely.

## References
- [FBI — Voice and video deepfake advisories](https://www.fbi.gov/investigate/cyber)
- [Microsoft — Trust no AI / deepfake research](https://news.microsoft.com/)
- [Verizon DBIR — annual SE and BEC data](https://www.verizon.com/business/resources/reports/dbir/)
- [DeepFaceLive](https://github.com/iperov/DeepFaceLive) — research only
- [ElevenLabs](https://elevenlabs.io/) — voice cloning (commercial, with safety review)
- See also: [[phishing-infrastructure-design]], [[pretext-design-for-engagements]], [[ai-agent-confusion-attacks]], [[multimodal-attacks]], [[client-side-attacks-primer]]

{% endraw %}
