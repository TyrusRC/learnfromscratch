---
title: Evil twin and Karma attacks
slug: evil-twin-and-karma-attacks
aliases: [evil-twin, karma-attacks, rogue-ap]
---

{% raw %}

> **TL;DR:** A WiFi attacker stands up an AP that impersonates a network the client trusts. Three flavours: (1) **evil twin** — same SSID as a legit AP, signal-louder, hopes clients roam; (2) **Karma** — answers ANY probe-request, so devices searching for their saved networks attach to you; (3) **captive portal / evil portal** — redirect to a credential-harvest page. Each has a defensive countermeasure shipped years ago — many client devices still don't enforce it. Companion to [[wifi-and-802-11-primer]] and [[wpa-and-wpa2-cracking]].

## Evil twin — the mechanic

1. Survey: identify a target SSID, channel, BSSID.
2. Stand up your AP on a *different* BSSID, same SSID, same channel (or adjacent).
3. Send deauth at the legit AP to nudge clients off.
4. Devices configured to "auto-rejoin" use signal strength — your louder AP wins.
5. Once connected: capture handshake (for offline crack), serve captive portal, or just be the gateway.

For open networks the chain is trivial. For WPA2 the client expects the same PSK as the legit AP — you can either:
- Make your AP open (and rely on user confusion to ignore the "no lock" icon).
- Capture the 4-way handshake attempt the client makes against your AP and crack offline.

## Tools

```bash
# Identify target
sudo airodump-ng wlan0mon

# Run a rogue AP
sudo airbase-ng -e "CorpWiFi" -c 6 wlan0mon       # creates at0 interface
sudo ifconfig at0 192.168.42.1/24 up
sudo dnsmasq -C /tmp/dns.conf                       # serve DHCP + DNS
# point everything at your portal:
echo "address=/#/192.168.42.1" >> /tmp/dns.conf

# Deauth target clients off the legit AP
sudo aireplay-ng --deauth 0 -a AA:BB:CC:DD:EE:FF wlan0mon
```

Modern toolkits that automate the chain:
- **wifiphisher** — one-command rogue AP + captive portal + deauth.
- **hostapd-wpe** — WPA2-Enterprise variant; captures MSCHAPv2.
- **eaphammer** — same idea, more EAP methods.
- **bettercap** — full layer-2 toolkit with `wifi.recon`, `wifi.deauth`, `wifi.ap`.

## Karma — answer any probe

When a device leaves home, it transmits probe-requests for every SSID it remembers ("Are you home? Are you Starbucks? Are you Tim Hortons?"). A Karma-mode AP says "yes" to *any* probe — the device attaches.

```bash
# hostapd-wpe with Karma mode
sudo hostapd-mana /etc/hostapd-mana/hostapd-mana.conf
# 'mana' = updated Karma
```

Modern smartphones reduced this surface (don't broadcast saved SSIDs continuously; require user opt-in to auto-join open networks). But IoT, older laptops, and PoS terminals still leak. Defenders should turn off "auto-join" for any non-Enterprise network they cannot validate by certificate.

## Captive portal / Evil portal

Once clients are on your AP, redirect HTTP traffic to a phishing page that imitates the target's branding. The page asks for "your work account to access WiFi" and forwards the credentials.

```html
<form action="/login" method="POST">
  <input name="user" placeholder="Email">
  <input name="pass" type="password" placeholder="Password">
  <input type="submit" value="Connect">
</form>
```

For HTTPS sites this is partial — sslstrip and `bettercap` can downgrade some, but HSTS + HSTS-preload cuts the surface heavily. Plain HTTP captive portals (airport, hotel) still work as decoys.

## KARMA / MANA / known beacon

Variants:
- **KARMA** (original 2004) — answer any probe.
- **MANA** (2014) — only respond to probes you've seen the device send (avoid detection).
- **Loud MANA** — flood device with multiple SSIDs at once.
- **Known Beacon** — beacon out common SSIDs (`xfinitywifi`, `Starbucks`, `attwifi`) at high volume; harvest devices configured to auto-join.

## OPSEC and detection

Defenders see:
- Same SSID, different BSSID, much hotter signal → likely evil twin.
- Probe-response storms for unrelated SSIDs → likely Karma/MANA.
- Captive-portal pages on unusual DNS responses.

Wireless IDS (`Kismet` + `nzyme` + Aruba/Cisco WIDS) catches these. Don't run evil-twin against networks not in scope; the airspace is shared and your AP affects neighbours.

## OSCP/OSEP relevance

- **OSCP**: wireless modules in PEN-200 cover handshake capture and offline WPA crack. Evil twin is touched briefly; full evil-twin labs are in OSWP (the older Wireless cert).
- **OSEP**: assumed-breach scenarios sometimes assume "you're on the WiFi"; understanding how clients trust APs informs the persistence / lateral options once you're on.

For both, knowing the trust model matters more than memorising tool commands.

## Defence

- 802.1X with EAP-TLS and server-cert pinning on managed devices.
- 802.11w (PMF) to prevent deauth.
- Don't broadcast common SSIDs on enterprise devices ("no `Starbucks` autojoin on the work laptop").
- WIDS that tracks BSSID-to-SSID stability.

## References
- [Wifiphisher](https://wifiphisher.org/)
- [Sensepost — MANA evolution](https://www.sensepost.com/blog/)
- [eaphammer](https://github.com/s0lst1c3/eaphammer)
- [bettercap WiFi modules](https://www.bettercap.org/modules/wifi/)
- See also: [[wifi-and-802-11-primer]], [[wpa-and-wpa2-cracking]], [[phishing-infrastructure-design]]

{% endraw %}
