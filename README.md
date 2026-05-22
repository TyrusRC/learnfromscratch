# Learn From Scratch

> *Share my learning journey.*

[![Build and Deploy](https://github.com/TyrusRC/learnfromscratch/actions/workflows/pages-deploy.yml/badge.svg)](https://github.com/TyrusRC/learnfromscratch/actions/workflows/pages-deploy.yml)
[![Built with Jekyll](https://img.shields.io/badge/built%20with-Jekyll-red?logo=jekyll)](https://jekyllrb.com)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)

🌐 **Live at:** <https://tyrusrc.github.io/learnfromscratch/>

---

## About

*Learn From Scratch* is a personal technical-learning blog. I publish
notes here as I work through programming topics — languages, security,
dev tools — from the ground up. Each post is a snapshot of what I
understood about a topic at the time I wrote it.

## Project structure

```text
learnfromscratch/
├── .github/workflows/   # GitHub Actions build & deploy workflow
├── _config.yml          # Jekyll site config (theme, identity, defaults)
├── _posts/              # Blog posts (YYYY-MM-DD-slug.md)
├── _tabs/               # Sidebar tabs (about, categories, tags, archives)
├── assets/css/          # Custom CSS overrides on top of Chirpy
├── index.html           # Home page (uses Chirpy's `home` layout)
├── Gemfile              # Ruby dependencies
├── Gemfile.lock         # Pinned dep versions (committed)
├── .ruby-version        # Ruby 3.3.6 (rbenv)
├── LICENSE              # Apache License 2.0
└── README.md            # You are here
```

## Local development

```bash
git clone https://github.com/TyrusRC/learnfromscratch.git
cd learnfromscratch

# Ensure Ruby 3.3.6 is available (rbenv picks .ruby-version automatically)
rbenv install 3.3.6 --skip-existing

bundle install
bundle exec jekyll serve --livereload
# → http://127.0.0.1:4000/learnfromscratch/
```

### Reproduce CI's link check locally

```bash
bundle exec jekyll build -d "_site/learnfromscratch"
bundle exec htmlproofer _site --disable-external \
  --ignore-urls "/^http:\/\/127.0.0.1/,/^http:\/\/0.0.0.0/,/^http:\/\/localhost/"
```

The `-d "_site/learnfromscratch"` flag mirrors what `actions/configure-pages`
does in CI so that internal links resolve against the same baseurl prefix.

## Writing a new post

1. Copy `_posts/2026-05-22-welcome-to-learn-from-scratch.md` and rename it
   to `YYYY-MM-DD-your-slug.md`.
2. Edit the front matter:
   - `title:` — quoted string.
   - `date:` — `YYYY-MM-DD HH:MM:SS +0700`.
   - `categories:` — exactly one category, 1–2 levels broad-to-narrow,
     e.g. `[Python, Async]`.
   - `tags:` — any number, lowercase, e.g. `[asyncio, decorators]`.
3. Write the body in Markdown. Fenced code blocks need a language hint
   so Rouge can highlight them.
4. `git add`, `git commit`, `git push`. The workflow builds and deploys
   automatically (~1–2 minutes).

## Deployment

Every push to `main` triggers
[`.github/workflows/pages-deploy.yml`](./.github/workflows/pages-deploy.yml),
which sets up Ruby 3.3, installs gems (cached), builds with
`JEKYLL_ENV=production`, runs `htmlproofer` to catch broken internal
links, and publishes via `actions/deploy-pages`. CI failures block
deployment.

## Tech stack

- **[Jekyll](https://jekyllrb.com)** 4.4 — static site generator
- **[Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy)** 7.5 — theme
- **Ruby** 3.3.6 (pinned via `.ruby-version`)
- **[html-proofer](https://github.com/gjtorikian/html-proofer)** 5.x — link checker in CI
- **GitHub Actions** + **GitHub Pages** — build and hosting

## Licence

- **Code** (workflows, config, theme overrides) — Apache License 2.0; see [`LICENSE`](./LICENSE).
- **Content** (blog posts and pages) — [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/), matching the footer notice the Chirpy theme renders.

## Acknowledgements

- The [Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme by Cotes Chung.
- The [Jekyll](https://jekyllrb.com) project.
