# AGENTS.md

Guidance for coding agents working in this repository.

## Project Summary

This is a Docker-backed Jekyll study guide. The generated site is built from Markdown pages under `docs/`, navigation data under `_data/study_nav.yml`, study deck data under `_data/study_decks.yml`, and local theme assets in `_layouts`, `_includes`, and `assets`.

The default local server port is `4030`. Do not change the default port unless the user explicitly asks. If the port is busy, stop the existing project container with `make stop` before choosing a different port.

## Expected Workflow

1. Inspect the existing files before editing.
2. Keep changes scoped to the user request.
3. Preserve unrelated dirty work in the working tree.
4. Use [compose.yaml](compose.yaml), not `docker-compose.yml`.
5. Prefer Makefile targets over hand-written Docker commands.
6. Update tests when adding substantive content pages or browser-visible behavior.
7. Run the narrowest useful check first, then `make test-all` for broad content or UI changes.

## Common Commands

```bash
make help
make build
make test
make e2e
make test-all
make serve
make stop
make clean
```

Use `make serve` for local preview at <http://127.0.0.1:4030/>.

Use `make stop` or `make cleanup` to stop any running container for this site.

## Docker and Serving

The Docker image is built from [Dockerfile](Dockerfile). The Compose service is defined in [compose.yaml](compose.yaml).

`make serve` installs signal traps around Compose, so `Ctrl-C` should shut down the server cleanly. Avoid backgrounding one-off `docker run` serve commands unless the user asks for that specifically.

## Content Conventions

Each study page should usually include:

- front matter with `title`, `layout: page`, `permalink`, `summary`, and `tags`,
- an H1 matching the page title,
- practical checks or commands near the top when relevant,
- tables for comparisons and protocol roles,
- a troubleshooting or debugging flow for operational topics,
- at least three study cards,
- references for protocol, product, or version-specific claims.

When adding a new major topic:

- create the page under `docs/<topic>/`,
- add it to `_data/study_nav.yml`,
- add or update study cards in `_data/study_decks.yml` when appropriate,
- update `test/site_test.rb` search-index and researched-topic checks,
- update `tests/e2e/site.spec.js` for major rendered pages.

## Testing Guidance

Use these checks:

```bash
ruby -c test/site_test.rb
make test
make test-all
```

`make test` builds the site and runs Ruby assertions against generated HTML.

`make test-all` runs `make test`, starts the local Compose server, runs Playwright, and then stops the server.

If Docker access is unavailable, report that clearly and still run any non-Docker checks that apply.

## Safety Notes

- Do not run destructive git commands such as `git reset --hard` or `git checkout --` unless the user explicitly asks.
- Do not remove unrelated generated or user-edited files.
- Do not rename or remove existing docs unless the user requested a restructuring.
- Keep README and AGENTS instructions aligned with the actual Makefile and Compose behavior.
