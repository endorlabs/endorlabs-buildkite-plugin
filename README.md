# Endor Labs Buildkite Plugin

[![CI](https://github.com/endorlabs/endorlabs-buildkite-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/endorlabs/endorlabs-buildkite-plugin/actions/workflows/ci.yml)

Buildkite plugin to run [endorctl](https://docs.endorlabs.com/developers-api/cli/commands/scan) after your step `command` — aligned with the [Endor Labs GitHub Action](https://github.com/endorlabs/github-action) for scan flags and outputs.

## Documentation

- **Endor Labs** — [scan](https://docs.endorlabs.com/scan), [exit codes](https://docs.endorlabs.com/best-practices/troubleshooting/endorctl-exitcodes)
- **Buildkite** — [writing plugins](https://buildkite.com/docs/pipelines/integrations/plugins/writing), [cluster secrets](https://buildkite.com/docs/agent/v3/clusters/secrets)
- **This plugin** — [setup](docs/setup.md) · [examples](docs/examples.md) · [troubleshooting](docs/troubleshooting.md)

## Quick example (vendored plugin)

```yaml
secrets:
  - ENDOR_NAMESPACE
  - ENDOR_API_CREDENTIALS_KEY
  - ENDOR_API_CREDENTIALS_SECRET

steps:
  - label: ":hammer: Build and scan"
    command: "make build"
    plugins:
      - ./.buildkite/vendor/endorlabs-buildkite-plugin:
          namespace: "${ENDOR_NAMESPACE}"
          api_key_env: ENDOR_API_CREDENTIALS_KEY
          api_secret_env: ENDOR_API_CREDENTIALS_SECRET
          scan_dependencies: true
          annotate: true
```

Vendor with [`scripts/sync-vendor-endorlabs-plugin.sh`](scripts/sync-vendor-endorlabs-plugin.sh). Public git ref: `https://github.com/endorlabs/endorlabs-buildkite-plugin.git#v0.1.4` (or `endorlabs#v0.1.4` after [directory sync](https://buildkite.com/docs/integrations/buildkite-plugins)). Demo: [repro-sandbox](https://github.com/endorlabs/repro-sandbox).

## How it works

- Single **`post-command`** hook — your `command` runs first, then install/auth/scan (avoids replacing the user command).
- **`plugin.yml`** — full JSON Schema; validated by [plugin-linter](https://github.com/buildkite-plugins/buildkite-plugin-linter) in CI (`additionalProperties: false`).
- **Credentials** — `api_key_env` / `api_secret_env` (or pre-exported `ENDOR_API_CREDENTIALS_*`); never passed as `--api-key` on the CLI. See [SECURITY.md](SECURITY.md).
- **Build tools** — plugin installs endorctl only; put Bazel/Node/etc. on the agent or in `command`. See [docs/setup.md §2](docs/setup.md#2-agent-and-cluster-build-tool-prerequisites).
- **Windows** — `post-command.bat` / `.ps1` delegate to Bash; requires Git Bash on the agent ([writing plugins](https://buildkite.com/docs/pipelines/integrations/plugins/writing)).

## Common options

| Option | Default | Notes |
|--------|---------|--------|
| `namespace` | (required) | Endor tenant |
| `scan_dependencies` | `true` | SCA |
| `scan_secrets` / `scan_sast` | `false` | Enable per need |
| `scan_container` | `false` | Requires `image` or `image_tar`; separate from repo scans |
| `annotate` | `false` | HTML summary after scan (severity counts, top findings table, artifact link) |
| `annotate_scope` | `build` | `job` shows annotation on the step job drawer (agent v3.112+) |
| `annotate_findings_limit` | `-1` | `-1` = all critical/high in table; `N>0` adds up to N medium/low rows; `0` = counts only (needs `jq` + JSON output) |
| `fail_on_policy` | `true` | Exit `128` fails the step |
| `soft_fail` | `false` | Softens other exits; does not bypass `128` when `fail_on_policy` is true |
| `mode` | `scan` | `sign` / `verify` for artifact signing |

All keys, validation rules, and cloud keyless auth: [`plugin.yml`](plugin.yml). Copy-paste pipelines: [docs/examples.md](docs/examples.md).

## Buildkite context mapping

| Buildkite env | endorctl |
|---------------|----------|
| `BUILDKITE_BRANCH` | `--detached-ref-name=` |
| `BUILDKITE_PULL_REQUEST` (numeric) | `--pr=true`, `--scm-pr-id=` (unless `pr: false`) |
| `BUILDKITE_PULL_REQUEST_BASE_BRANCH` | `--pr-baseline=` |

PR comments need `enable_pr_comments` + `scm_token_env` — see [docs/troubleshooting.md](docs/troubleshooting.md).

## Developing

```bash
docker compose run --rm tests
```

See [CONTRIBUTING.md](CONTRIBUTING.md). E2E validation: vendored plugin in [repro-sandbox](https://github.com/endorlabs/repro-sandbox).

## License

[Apache License 2.0](LICENSE).
