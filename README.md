# Learn From Scratch

> Security knowledge base — 1,155 notes · 26 domains · 32 learning paths

[![Build and Deploy](https://github.com/TyrusRC/learnfromscratch/actions/workflows/pages-deploy.yml/badge.svg)](https://github.com/TyrusRC/learnfromscratch/actions/workflows/pages-deploy.yml)
[![Built with Jekyll](https://img.shields.io/badge/built%20with-Jekyll-red?logo=jekyll)](https://jekyllrb.com)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

🌐 **Live:** <https://tyrusrc.github.io/learnfromscratch/>

---

## Topics

| Domain | # | Domain | # | Domain | # |
|--------|---|--------|---|--------|---|
| Web | 161 | Red Team | 99 | Bug Bounty | 90 |
| Cloud | 86 | Exploit Dev | 85 | Code Audit | 68 |
| Network | 64 | Active Directory | 51 | Forensics | 48 |
| Compliance | 45 | Mobile | 43 | AI/LLM | 40 |
| Windows | 34 | CTI | 33 | Crypto | 33 |
| Linux | 28 | Blockchain | 26 | API | 26 |
| Reverse Eng | 25 | macOS | 19 | Lateral Movement | 15 |
| Privesc | 12 | CVE Walkthroughs | 9 | Hardware | 6 |
| AWD | 6 | Embedded | 3 | | |

## Certification Roadmaps

`_learn/paths/` — study plans with note mappings for each cert.

| Offensive | Defensive | Web | Red Team |
|-----------|-----------|-----|----------|
| OSCP | OSDA | BSCP | CRTO |
| OSEP | | OSWE | MCRTA |
| OSED | | OSWA | |
| OSEE | | | |
| OSMR | | | |

## Knowledge Graph

`graphify-out/graph.html` — interactive graph (4,801 nodes · 5,856 edges · 502 communities).

Rebuild: `graphify --update` after adding notes.

## Structure

```
_learn/
├── topics/        # 1,155 atomic notes (26 domains)
├── paths/         # 32 certification & learning paths
├── playbooks/     # 11 step-by-step attack chain playbooks
├── tools.md       # Tool index
└── references.md  # External resources
graphify-out/      # Knowledge graph outputs
docs/gap-analysis/ # Gap analysis vs certs & external KBs
```

## Development

```bash
git clone https://github.com/TyrusRC/learnfromscratch.git
cd learnfromscratch
bundle install
bundle exec jekyll serve --livereload
# → http://127.0.0.1:4000/learnfromscratch/
```

### CI link check

```bash
bundle exec jekyll build -d "_site/learnfromscratch"
bundle exec htmlproofer _site --disable-external \
  --ignore-urls "/^http:\/\/127.0.0.1/,/^http:\/\/0.0.0.0/,/^http:\/\/localhost/"
```

## Stack

- [Jekyll](https://jekyllrb.com) 4.4 + [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) 7.5
- Ruby 3.3.6 · [html-proofer](https://github.com/gjtorikian/html-proofer) 5.x
- GitHub Actions + GitHub Pages

## Licence

- **Code** — Apache License 2.0 ([`LICENSE`](./LICENSE))
- **Content** — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
