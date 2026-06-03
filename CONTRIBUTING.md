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

## CI checks

Pull requests and pushes to `main` run [.github/workflows/ci.yml](.github/workflows/ci.yml):

1. **shellcheck** on `hooks/` and `lib/`
2. **buildkite/plugin-linter** CLI — validates `plugin.yml` and `docs/examples.md` (`id: endorlabs`)
3. **BATS** via `docker compose run --rm tests` (image digest in [docker-compose.yml](docker-compose.yml))

The same checks run on Buildkite via [`.buildkite/pipeline.yml`](.buildkite/pipeline.yml).

## Implementation references

When changing scan behaviour or flags, cross-check:

- [Writing Buildkite plugins](https://buildkite.com/docs/pipelines/integrations/plugins/writing) — `plugin.yml` schema, hooks, BATS, directory publish
- [Endor Labs GitHub Action](https://github.com/endorlabs/github-action) — input → endorctl mapping
- [endorctl CLI documentation](https://docs.endorlabs.com/developers-api/cli/commands/scan)

Do not commit API keys, bearer tokens, `.env`, or anything under `.local/`. Tests use
stubbed credentials only.

## Hosted end-to-end validation

Real `endorctl` scans against Endor Labs run in [repro-sandbox](https://github.com/endorlabs/repro-sandbox)
with a vendored copy of this plugin and Buildkite cluster secrets — not in this repo's PR CI.

## Releasing (maintainers)

1. `docker compose run --rm tests`
2. Sync vendored copy into [repro-sandbox](https://github.com/endorlabs/repro-sandbox); confirm default pipeline build is green
3. Tag release; update [CHANGELOG.md](CHANGELOG.md)

## Pull requests

- Keep changes focused; extend BATS when behaviour changes.
- Do not log or print secret values in hooks or docs.
- Run `docker compose run --rm tests` before opening a PR.
