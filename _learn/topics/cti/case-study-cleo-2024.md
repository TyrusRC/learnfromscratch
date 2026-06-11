---
title: "Case study: Cleo Harmony/VLTrader/LexiCom exploitation (Dec 2024)"
slug: case-study-cleo-2024
aliases: [cleo-mft-2024, cve-2024-50623-case-study]
---
{% raw %}

In December 2024, Cl0p turned Cleo's managed file transfer (MFT) products — Harmony, VLTrader, LexiCom — into another mass-exploitation event in the same mold as MOVEit (2023), GoAnywhere (2023), and Accellion FTA (2020). The chain was a plain unrestricted file upload landing in an "autorun" directory that the service eagerly executed. Cleo shipped a patch for CVE-2024-50623 on 2024-10-30 that turned out to be incomplete; active in-the-wild exploitation against patched appliances was confirmed by Huntress around 2024-12-08, and Cleo issued CVE-2024-55956 plus a real fix (5.8.0.21) on 2024-12-11. By the time the dust settled, Cl0p's leak site had named on the order of 66 victims, almost entirely organisations that had exposed Cleo's HTTP listener to the internet. If you run an MFT, this story is your story too — see [[third-party-risk-management-practitioner]].

## Mental model / How it works

Cleo Harmony, VLTrader, and LexiCom share a common autorun directory pattern. Files dropped into `autorun/` (or the configured "Host" autorun folder) are interpreted as host action XML and executed by the service on a short polling interval. The product also exposed an HTTP file-import endpoint that did not authenticate properly and did not constrain the destination path, so an unauthenticated attacker could:

1. POST a crafted file with a traversal-style filename or use the import API to place arbitrary content anywhere the service user could write.
2. Place a host action XML stub into the autorun directory.
3. Wait a few seconds. The Cleo service parses the XML, expands the embedded `System` host action, and runs an arbitrary command — in observed cases, `powershell.exe -enc ...` to fetch a second-stage downloader (Cleopatra / Malichus, a Java-based loader, plus PowerShell helpers).

Diagram as text:

```
Internet ──HTTPS──> Cleo HTTP listener (CVE-2024-50623 / -55956)
                          │  arbitrary write
                          ▼
                 <CleoRoot>\autorun\evil.xml
                          │  cron-like poller (seconds)
                          ▼
                 LexiCom.exe / Harmony.exe / VLTrader.exe
                          │  spawns
                          ▼
                 powershell.exe -enc ... ──> C2 / Cleopatra loader
```

CVE-2024-50623 (CVSS 9.8) was filed as "unrestricted file upload and download" in Harmony, VLTrader, and LexiCom <= 5.8.0.20. CVE-2024-55956 (also 9.8) covers the bypass of the original patch — same primitive, same autorun outcome — fixed in 5.8.0.21. Treat them as one chain. Map cleanly to MITRE: T1190 (Exploit Public-Facing Application) → T1059.001 (PowerShell) → T1105 (Ingress Tool Transfer) → T1567 (Exfil over web). See [[mitre-attack-mapping]].

## Tradecraft / Hands-on

Defanged sketch of what the stage looks like — do not run, do not host. The host action XML is the actual primitive; the PowerShell is just the most-seen payload.

```xml
<!-- <CleoRoot>\autorun\healthcheck.xml  (defanged) -->
<Host alias="local">
  <Mailbox>
    <Action type="Commands">
      <Cmds>
        System "cmd.exe /c powershell -nop -w hidden -enc BASE64HERE"
      </Cmds>
    </Action>
  </Mailbox>
</Host>
```

Quick triage you can actually run on a suspected appliance (read-only):

```powershell
# 1. Inventory autorun directories under the Cleo install root
Get-ChildItem -Recurse -Path 'C:\Program Files\Cleo' -Filter autorun -Directory |
  ForEach-Object { Get-ChildItem $_.FullName -File | Select FullName, LastWriteTime, Length }

# 2. Recent XML written to any autorun folder in the last 30 days
Get-ChildItem -Recurse 'C:\Program Files\Cleo' -Include *.xml |
  Where-Object { $_.FullName -match '\\autorun\\' -and $_.LastWriteTime -gt (Get-Date).AddDays(-30) }

# 3. PowerShell or cmd children of Cleo services (last 7 days)
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688; StartTime=(Get-Date).AddDays(-7)} |
  Where-Object { $_.Message -match 'LexiCom\.exe|VLTrader\.exe|Harmony\.exe' -and
                 $_.Message -match 'powershell\.exe|cmd\.exe' }
```

YARA-style hunt for the early-wave stage filenames Huntress published (`healthchecktemplate.txt`, `healthcheck.txt`, and `*-healthcheck.xml`):

```bash
yara -r - /opt/cleo <<'EOF'
rule Cleo_Autorun_Stage_2024 {
  strings:
    $a = "healthchecktemplate" nocase
    $b = "healthcheck.txt" nocase
    $c = "<Cmds>" ascii
    $d = "powershell" nocase
  condition:
    filesize < 200KB and ($a or $b) and $c and $d
}
EOF
```

Patch and harden (this is the non-negotiable part):

```text
Harmony / VLTrader / LexiCom  ==>  5.8.0.21 or later
Block inbound to the Cleo HTTP/AS2 ports from the public internet
Move autorun to a non-default path; deny SYSTEM/service write where possible
Front the appliance with an authenticating reverse proxy / VPN
```

## Detection / Telemetry

Defender signals, in priority order:

- File create events (Sysmon EID 11, EDR file telemetry) where the target path matches `*\Cleo*\autorun\*.xml` and the writing process is the Cleo service itself with no scheduled-task or operator context — that is the literal exploit primitive.
- Process create (Sysmon EID 1 / Security 4688) where `LexiCom.exe`, `VLTrader.exe`, or `Harmony.exe` spawns `cmd.exe`, `powershell.exe`, `rundll32.exe`, `regsvr32.exe`, or `java.exe` outside its install tree. Cleo legitimately spawns Java for some workflows — baseline first, then alert on encoded PowerShell.
- Outbound network from the appliance to non-business destinations: any HTTP/HTTPS egress from a Cleo host to a fresh-registration domain or a raw IP is a strong signal. MFTs talk to a small, known set of partners — anomaly detection is cheap here.
- Web access logs: POSTs to the Cleo HTTP listener with multipart bodies, unusual `filename=` values containing path separators, or User-Agents seen in Huntress / Rapid7 IOCs (early waves used a small pool).
- 4624 logon events on the appliance that are not the Cleo service account, especially interactive logons that follow a child PowerShell event.

This is textbook detection-engineering: pin a high-fidelity signal (service writes XML into its own autorun, then spawns PowerShell) and let everything else corroborate. See [[detection-engineering-fundamentals]] and [[threat-hunting-fundamentals]]. The autorun-write + child-process pair sits high on the [[cti-pyramid-of-pain]] — it costs Cl0p real work to evade because it is the capability, not an indicator.

## OPSEC pitfalls / common mistakes

- Assuming the October patch (5.8.0.20) closed the hole. It did not. The November–December activity was largely against "patched" hosts; you need 5.8.0.21+.
- Treating the MFT as an "app" instead of an internet-exposed crown jewel. MOVEit, GoAnywhere, Accellion, Cleo — same vendor class, same outcome, four years running. If it brokers customer data, it gets the same controls as a DMZ web app.
- Trusting EDR coverage on the appliance. Many Cleo boxes ran with EDR in audit-only or with the Cleo install path excluded "for performance." Verify exclusions before you assume visibility.
- Hunting only on the published filenames (`healthcheck*`). Cl0p rotated names within days. Hunt on the behaviour (autorun write + service-spawned shell), not the string.
- Skipping retro-hunt. The exploitation window was open from at least early December; CVE-2024-50623 was disclosed in October. Pull 60–90 days of process and file telemetry, not 7. The affiliate playbook is well documented in [[ransomware-affiliate-playbook]].

## References

- https://www.huntress.com/blog/threat-advisory-oh-no-cleo-cleo-software-actively-being-exploited-in-the-wild
- https://nvd.nist.gov/vuln/detail/CVE-2024-50623
- https://nvd.nist.gov/vuln/detail/CVE-2024-55956
- https://support.cleo.com/hc/en-us/articles/27140294267799-Cleo-Product-Security-Advisory-CVE-2024-55956
- https://www.rapid7.com/blog/post/2024/12/10/etr-cleo-file-transfer-software-zero-day-exploited-in-the-wild/
- https://www.cisa.gov/news-events/alerts/2024/12/13/cisa-adds-one-vulnerability-kev-catalog

See also: [[ransomware-affiliate-playbook]], [[cti-pyramid-of-pain]], [[detection-engineering-fundamentals]], [[threat-hunting-fundamentals]], [[mitre-attack-mapping]], [[third-party-risk-management-practitioner]]

{% endraw %}
