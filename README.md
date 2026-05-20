# Tech Study Guide

A personal, searchable Jekyll study guide for infrastructure, networking, databases, and related engineering topics.

The site uses a project-local theme called StudyGraph. It is built for study guides and technical notes with full-text search, tags, expandable navigation, light/dark mode, reader mode, live font controls, syntax highlighting, study cards, and a generated knowledge graph.

## Local Preview

The local workflow uses Docker so the host machine does not need Ruby or Jekyll installed.

Build the site:

```bash
make build
```

Serve the site locally with Docker Compose:

```bash
make serve
```

Open <http://127.0.0.1:4030/>.

Press `Ctrl-C` in the `make serve` terminal to stop the local server. To clean up any already-running container for this site:

```bash
make stop
```

The default local port is `4030` because `4000`, `4010`, and `4020` are commonly already in use. To use another port:

```bash
make serve PORT=4040
```

Useful targets:

```bash
make docker-build
make build
make test
make e2e
make test-all
make serve
make stop
make clean
```

## Browser Tests

Playwright covers the interactive browser behavior: search, navigation, theme and reader controls, Study Mode, and current major topic pages.

Install the Node dependencies and Chromium browser once:

```bash
npm install
npm run playwright:install
```

Run the browser suite. This target starts the Docker Compose Jekyll server, waits for it, runs Playwright, and stops the server afterward:

```bash
make e2e
```

`npm run test:e2e` runs Playwright directly and expects a server to already be available at `BASE_URL` or `http://127.0.0.1:4030`.

Run all local checks:

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

Add the page to `_data/study_nav.yml` when it should appear in the left navigation. See `docs/template.md` for a reusable note structure.

Study cards can be added to any page:

```liquid
{% include study-card.html question="What problem does this solve?" answer="A short answer for active recall." %}
```

## Current Structure

```text
docs/
  linux/
  kubernetes/
  dns/
  networking/
  ceph/
  databases/
    postgres/
```
