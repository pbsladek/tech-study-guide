# Tech Study Guide

A searchable Jekyll study guide for infrastructure, networking, databases, Linux, Kubernetes, DNS, identity, and related engineering topics.

The site uses a project-local theme called StudyGraph. It includes full-text search, tags, expandable navigation, light/dark mode, reader mode, live font controls, syntax highlighting, study cards, and a generated knowledge graph.

## Requirements

- Docker Desktop or a Docker-compatible engine
- Node.js and npm for Playwright browser tests
- `make`

Ruby and Jekyll run inside Docker, so they do not need to be installed on the host.

## Quick Start

Build the Jekyll image and generated site:

```bash
make build
```

Serve the site locally:

```bash
make serve
```

Open <http://127.0.0.1:4030/>.

`make serve` uses Docker Compose through [compose.yaml](compose.yaml). Press `Ctrl-C` in the terminal to stop the server; the Makefile trap runs `docker compose down --remove-orphans` afterward.

If a container is already running for this app, stop it with:

```bash
make stop
```

Use a different port only when needed:

```bash
make serve PORT=4040
```

The default port is `4030`.

## Common Commands

```bash
make help
make docker-build
make build
make test
make e2e
make test-all
make check
make serve
make stop
make cleanup
make clean
```

Command summary:

| Command | Purpose |
| --- | --- |
| `make docker-build` | Build the local Jekyll Docker image. |
| `make build` | Generate `_site` with production Jekyll settings. |
| `make test` | Build the site and run Ruby generated-HTML tests. |
| `make e2e` | Start the Compose server, run Playwright, then stop the server. |
| `make test-all` | Run Ruby generated-HTML tests and Playwright browser tests. |
| `make serve` | Serve the site at `http://127.0.0.1:4030/` by default. |
| `make stop` | Stop Compose and any running containers with the project prefix. |
| `make clean` | Remove generated Jekyll output. |

## Browser Tests

Install Node dependencies and the Chromium browser once:

```bash
npm install
npm run playwright:install
```

Run the browser suite:

```bash
make e2e
```

`make e2e` starts the Docker Compose Jekyll server, waits for it to answer, runs Playwright, and stops the server afterward.

`npm run test:e2e` runs Playwright directly and expects a server to already be available at `BASE_URL` or `http://127.0.0.1:4030`.

Run all local checks:

```bash
make test-all
```

## Project Layout

```text
.
├── _data/
│   ├── study_decks.yml
│   └── study_nav.yml
├── _includes/
├── _layouts/
├── assets/
├── docs/
│   ├── ceph/
│   ├── databases/
│   ├── dns/
│   ├── identity/
│   ├── istio/
│   ├── kubernetes/
│   ├── linux/
│   └── networking/
├── test/
│   └── site_test.rb
├── tests/e2e/
├── compose.yaml
├── Dockerfile
├── Makefile
└── package.json
```

## Adding Study Notes

Create Markdown files under `docs/`.

Use front matter like this:

```yaml
---
title: New Topic
layout: page
permalink: /docs/new-topic/
summary: One sentence explaining what this note teaches.
tags:
  - example
  - networking
---
```

Add the page to [_data/study_nav.yml](_data/study_nav.yml) when it should appear in the left navigation. See [docs/template.md](docs/template.md) for a reusable note structure.

Study cards can be added to any page:

```liquid
{% include study-card.html question="What problem does this solve?" answer="A short answer for active recall." %}
```

For broad topic decks, add cards to [_data/study_decks.yml](_data/study_decks.yml).

## Testing New Content

For substantive content changes, update tests so the important terms cannot disappear silently:

- Add first-command-block expectations in [test/site_test.rb](test/site_test.rb) when the page starts with a command block.
- Add search-index content assertions for important terms.
- Add the page to study-card and researched-topic coverage when appropriate.
- Add Playwright visibility checks in [tests/e2e/site.spec.js](tests/e2e/site.spec.js) for major new pages.

Then run:

```bash
make test-all
```

## GitHub Pages

This repository includes a GitHub Actions workflow at `.github/workflows/pages.yml`.

After pushing to GitHub:

1. Open the repository settings.
2. Go to **Pages**.
3. Set **Build and deployment** to **GitHub Actions**.
4. Push to `main` or run the workflow manually.

## Agent Notes

See [AGENTS.md](AGENTS.md) for repo-specific guidance for coding agents and future automation.
