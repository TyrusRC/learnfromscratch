---
title: OneNote and modern document formats payload delivery
slug: onenote-and-modern-document-formats-payload-delivery
aliases: ["onenote-phishing","modern-document-phishing"]
date: 2026-06-08
---
{% raw %}

When Microsoft finally flipped the Mark-of-the-Web macro block to default in mid-2022, the cottage industry of maldoc crews did not retire. They migrated. OneNote `.one` files became the dominant phishing payload format for roughly fifteen months, and when that vector was burned in early 2023, operators rotated through a predictable carousel of formats that the Office trust model never properly covered. Understanding that progression is essential for tuning detections and for picking believable lures on red team engagements.

## Why OneNote worked

OneNote notebooks are not Office documents in the OOXML sense. They are a separate binary container that supported arbitrary file embedding for years with almost no security ceremony. Three properties made them ideal:

- No Protected View. Opening a `.one` from an email attachment dropped the user straight into an editable notebook.
- Embedded files (`FileDataStoreObject`) could be any executable type, launched on double click after a single tame warning.
- The visual surface is freeform, so a full page graphic could overlay the embedded icon. The standard lure was a blurred "protected document, click View to unhide" banner with one or more `.hta`, `.cmd`, `.vbs`, `.js`, or `.lnk` files hidden beneath the click target.

Crews like the operators behind Qakbot, IcedID, and AsyncRAT all converged on the same template within weeks. The typical chain was OneNote opens, user clicks the fake button, embedded HTA runs `mshta.exe`, which pulls a second stage with `curl` or BITS. See [[jscript-hta-wsh-initial-access]] for the HTA mechanics and [[living-off-the-land]] for the LOLBins involved.

## What Microsoft shipped

The first defensive change came in the OneNote build released March 2023, which added a dialog warning specifically for embedded files of dangerous extensions. The second, in the May 2023 build, hard-blocked a list of about 120 extensions from being launched out of OneNote at all, mirroring the Outlook attachment block list. By late 2023 the embedded file path was effectively dead for naive lures. Defenders can also push the same posture via group policy:

```
HKCU\Software\Policies\Microsoft\Office\16.0\OneNote\Options
    DisableEmbeddedFiles = 1
    EmbeddedFileExtensionsToBlock = "REG_MULTI_SZ list"
```

ASR rule `Block Office communication application from creating child processes` does not cover OneNote, but the dedicated rule `Block Win32 API calls from Office macros` is also irrelevant here. The one that matters is `Block execution of potentially obfuscated scripts` plus a custom rule or EDR detection on `ONENOTE.EXE` spawning anything that is not Office itself.

## The rotation after OneNote

Once OneNote was burned, the same crews tried several alternates in parallel. None achieved the same dominance, which is itself a useful signal: the era of one universal maldoc format is probably over.

- PDF with embedded JavaScript. Adobe Reader still executes JS in PDFs by default with limited API access, but operators used social engineering to drive the user to download a separate stage from a link painted as a button. Chrome and Edge PDF viewers ignore embedded JS, which limits effectiveness.
- WSF (Windows Script File). Runs under `wscript.exe`, bypasses some MOTW prompts depending on how it arrives, and is rarely flagged by users because the extension looks obscure rather than dangerous.
- SVG smuggling. SVG is XML, and modern browsers happily execute JavaScript inside `<script>` tags when the file is opened directly. Operators embed an HTML smuggling blob that reassembles a ZIP in the browser, dropping a LNK or ISO to disk. This took off in 2024 and remains active.
- ISO, IMG, VHD container abuse persisted but was hampered by Microsoft's late 2022 change propagating MOTW into mounted containers on Windows 11.
- LNK files inside ZIPs, often with an icon spoof and a command line that calls `powershell` or `mshta`. Cheap, ugly, still works against unhardened endpoints.

For the broader taxonomy and how it maps to operator tradecraft, see [[modern-phishing-payload-formats-post-vba]] and the lifecycle framing in [[client-side-attacks-primer]]. For VBA-era context that this all replaced, see [[office-vba-macros-initial-access]].

## Detections that hold up

The single highest signal rule, even now, is process lineage. ONENOTE.EXE spawning `cmd.exe`, `mshta.exe`, `wscript.exe`, `cscript.exe`, `powershell.exe`, `rundll32.exe`, `regsvr32.exe`, or any user-writable path executable is almost always malicious. A Sigma-style rule:

```yaml
detection:
  parent_image: '\ONENOTE.EXE'
  child_image:
    - '\mshta.exe'
    - '\wscript.exe'
    - '\cscript.exe'
    - '\powershell.exe'
    - '\cmd.exe'
    - '\rundll32.exe'
  condition: selection
```

Pair that with file write detections for `%TEMP%\OneNote\` where the embedded payload is extracted before launch. For SVG and HTML smuggling, focus on browser child processes writing executables to `%USERPROFILE%\Downloads\` followed by user execution of a LNK or ISO. For PDF, log Acrobat spawning anything other than its own updater.

## Operator takeaways

If you are building a current phishing campaign, OneNote is a poor first choice unless your target is demonstrably behind on patches. SVG smuggling delivering an ISO with an internal LNK is the closest current analogue to the 2023 OneNote playbook, and tooling like Evilginx covered in [[aitm-evilginx-modern-phishing]] handles the credential side cleanly while a parallel payload track handles execution. Mix formats per target tier rather than reusing one template, and assume any embedded file rule that worked yesterday is being written into a detection today.

{% endraw %}
