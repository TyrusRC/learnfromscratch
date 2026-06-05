---
title: PyPI supply chain audit
slug: python-pypi-supply-chain-audit
aliases: [pypi-security-audit, python-supply-chain]
---

{% raw %}

> **TL;DR:** PyPI's risks: `setup.py` runs arbitrary Python at install time (analog of npm `postinstall`), `pip install` resolves names without strict signature, dependency confusion targets private package names, and the namespace allows visually-similar typosquats. Auditing means: pin transitively, prefer wheels, scan for `setup.py` and `pyproject.toml` build hooks, and use a private index with allowlist for production builds.

## Attack surface

### 1. `setup.py` exec on install
- `pip install pkg` invokes `setup.py` if no wheel is available — arbitrary Python with full user privileges.
- Even with wheels, `pyproject.toml` build backends (`setuptools.build_meta`, `poetry-core`, `hatchling`) run code during build / install of source distributions.
- `entry_points` registered in metadata can execute on first import via `pkg_resources` cache.

### 2. Typosquats
- `requests` vs `requets`, `urllib3` vs `urlib3`, `python-dateutil` vs `python-dateutils`.
- PyPI namespace policy is lax compared to npm; reports from Phylum/Sonatype list dozens per month.

### 3. Dependency confusion
- Private package `acme-internal-utils` referenced in `requirements.txt`. Attacker publishes same name on PyPI with higher version. Default `pip install --index-url` falls back to PyPI if not found in private → resolves to attacker's.
- Use `--index-url` pointing to your private index only, or `pip config set global.index-url` to override default + `--extra-index-url` for fallback (still risky).

### 4. Wheel substitution
- Pre-built wheels (`*.whl`) are zip files of compiled bytes — auditor cannot easily inspect for malicious code. Sdists (`*.tar.gz`) are auditable but slower to install.
- Some packages ship native extensions (`.so`/`.dll`) compiled by maintainer — opaque binary, attacker has multiple injection points (compiler, post-build).

### 5. Compromised maintainer / account
- `ctx`, `phpass`, `jellyfish` incidents — maintainer accounts compromised, malicious versions pushed.
- PyPI added 2FA mandatory for top maintainers in 2023; check status of your deps' maintainers.

### 6. Compromised compile-time tools
- `pip install --no-binary` for security-sensitive packages forces source build. But the source build's `setup.py` is the attack surface — it can run anything during the build.

## Audit workflow

### Repo audit
```bash
# Dependencies (top-level + pinned)
cat requirements.txt requirements*.txt pyproject.toml

# Lockfile diff in PRs
git log --oneline -- poetry.lock uv.lock pdm.lock

# Find every setup.py that ships in installed packages
find .venv -name setup.py | head -20

# Find every build backend (pyproject.toml [build-system])
grep -l '\[build-system\]' $(find .venv -name pyproject.toml)
```

### Suspicious indicators
- Recent first publish (<90 days) for a dep that claims maturity.
- No GitHub URL in metadata, or URL is to a different project.
- Single maintainer with no commit history elsewhere.
- `setup.py` that imports `urllib`, `socket`, `subprocess`, `os.system` outside of platform detection.

### Tools
- **pip-audit** (PyPA) — CVE deps based on OSV.
- **safety** (Pyup) — same surface, commercial features.
- **bandit** — not supply chain, but catches some patterns in vendored copies.
- **Socket.dev**, **Phylum** — both cover PyPI now.
- **OSV-Scanner** — open-source.
- **pip-licenses** — license audit (compliance, not security, but related).
- **pep-740** signed wheels (rolling out) — verify provenance via Sigstore signatures.

## Hardening

### Build pipeline
- `pip install --require-hashes -r requirements.txt` — every dep + transitive pinned with `--hash=sha256:...`. `pip-compile --generate-hashes` produces it.
- `pip install --no-deps` then `pip install <dep>==<version>` per dep — explicit only, no transitive surprise.
- Build in container; ephemeral; no secrets in env beyond what install needs.
- Prefer `--only-binary :all:` to force wheels (no `setup.py` exec for installed deps) — but wheel ≠ trusted, just less code-on-install.

### Private index
- `--index-url https://pypi.internal.example.com/simple/` — internal only.
- No `--extra-index-url` to PyPI; mirror public deps explicitly into the internal index.
- Allowlist what can be mirrored.

### Lockfile + pinning
- `poetry.lock` / `uv.lock` / `pdm.lock` (or pip-tools `requirements.txt` with hashes).
- Pin to specific versions, NOT ranges, for production.
- Renovate / Dependabot PRs reviewed by human.

### Sigstore signed deps
- PEP 740 + PyPI Sigstore integration verifies wheel provenance.
- `pip install --require-virtual-env --require-hashes --no-deps` + verify Sigstore attestation in CI.

### Pre-install screen
- `pip install --dry-run` shows what would be installed; diff against expected.
- Custom wrapper that rejects deps without allowlist match.

## References
- [PyPA security guide](https://packaging.python.org/en/latest/guides/security/)
- [PEP 740 — Sigstore signing](https://peps.python.org/pep-0740/)
- [pip-audit](https://github.com/pypa/pip-audit)
- [Phylum, Sonatype, ReversingLabs incident writeups]
- See also: [[python-code-auditing]]

{% endraw %}
