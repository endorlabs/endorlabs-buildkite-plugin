# Contributing

Thank you for improving the Endor Labs Buildkite plugin.

## Prerequisites

- [Docker](https://www.docker.com/) (tests run in Linux containers from any host)
- Bash 4+ for hooks and libraries

## Run tests

From the repository root:

```bash
docker compose run --rm tests
```

Alternative:

```bash
docker run --rm -v "${PWD}:/plugin" -w /plugin \
  buildkite/plugin-tester@sha256:86c728d8526e22f5d26c1b65e2cae1dfb2d9767fe24d560563895d051b258c84 \
  bats tests/
```

On Windows, ensure `hooks/`, `lib/`, and `tests/` use LF line endings (see `.gitattributes`).

## CI checks (GitHub Actions)

Pull requests and pushes to `main` run [.github/workflows/ci.yml](.github/workflows/ci.yml):

1. **shellcheck** on `hooks/`, `lib/`, and maintainer scripts
2. **plugin-linter** (`buildkite/plugin-linter`) with `id: endorlabs`, `readme: docs/examples.md`
3. **BATS** via `docker compose run --rm tests`

## CI checks (Buildkite)

This repository’s `.buildkite/pipeline.yml` runs the same checks on Buildkite:

1. **shellcheck** on `hooks/**`, `lib/**`, and `scripts/validation/render-matrix.sh`
2. **plugin-linter** with `id: endorlabs` and `readme: docs/examples.md`
3. **BATS** via `docker-compose#v5.0.0`

## Implementation references

When changing scan behaviour or flags, cross-check:

- [Endor Labs GitHub Action](https://github.com/endorlabs/github-action) — input → endorctl mapping
- [endorctl CLI documentation](https://docs.endorlabs.com/developers-api/cli/commands/scan)

Do not commit API keys, bearer tokens, `.env`, or anything under `.local/`. Tests use
stubbed credentials only.

## What gets pushed vs maintainer-only local runs

**Push to this repo:** plugin code, `plugin.yml`, `docs/examples.md`, BATS tests, and
CI config (shellcheck, plugin-linter, BATS). That is what PRs gate.

**Stay on your machine (gitignored under `.local/`):** real-scan logs, scan JSON,
`paths.env`, rendered matrix YAML, and credentials in `.env`. Optional real scans use
[contrib/local-smoke/](contrib/local-smoke/) — see
[docs/maintainers/validation.md](docs/maintainers/validation.md).

## Pull requests

- Keep changes focused; extend BATS when behaviour changes.
- Do not log or print secret values in hooks or docs.
- Run `docker compose run --rm tests` before opening a PR.
