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
docker run --rm -v "${PWD}:/plugin" -w /plugin buildkite/plugin-tester:v4.3.0 bats tests/
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

Do not commit API keys, bearer tokens, or `.env` files. Tests use stubbed credentials only.

## Maintainer-only local smoke tests

Optional Docker-based runs with a real `endorctl` binary live under
[contrib/local-smoke/](contrib/local-smoke/). See
[docs/maintainers/validation.md](docs/maintainers/validation.md) for the Buildkite matrix.

## Pull requests

- Keep changes focused; extend BATS when behaviour changes.
- Do not log or print secret values in hooks or docs.
- Run `docker compose run --rm tests` before opening a PR.
