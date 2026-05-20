# Development roadmap

Internal delivery phases for the [Endor Labs Buildkite plugin](https://github.com/endorlabs/endorlabs-buildkite-plugin).
Customer-facing usage is documented in [README.md](README.md) and [docs/examples.md](docs/examples.md).

## Status (v0.1.0)

| Area | Status |
|------|--------|
| Install, auth, dependency scan, Buildkite branch/PR mapping | Done |
| Scan kinds (secrets, SAST, tools, GH Actions, AI models, Bazel, package) | Done |
| PR baseline, incremental, SCM comments (`scm_token_env`) | Done |
| Container scan | Done |
| Artifact sign / verify (`mode`) | Done |
| Annotations, soft-fail, policy exit handling, artifact upload | Done |
| Optional real-repo validation matrix | Harness in-repo; evidence operator-owned |

## CI for this repository

`.buildkite/pipeline.yml`: shellcheck → plugin-linter → BATS (`docker compose run --rm tests`).

## GitHub Action parity

Plugin options mirror the official [Endor Labs GitHub Action](https://github.com/endorlabs/github-action)
where applicable. For authoritative flag names and env vars, see
[endorctl CLI documentation](https://docs.endorlabs.com/developers-api/cli/commands/scan).

| GitHub Action input | Plugin key | endorctl |
|---------------------|------------|----------|
| `namespace` | `namespace` | `--namespace=` |
| `api` | `api` | `--api=` |
| `api_key` / `api_secret` | `api_key_env` / `api_secret_env` | env `ENDOR_API_CREDENTIALS_*` |
| `scan_dependencies` | `scan_dependencies` | `--dependencies=true` |
| `scan_secrets` | `scan_secrets` | `--secrets=true` |
| `scan_sast` | `scan_sast` | `--sast=true` |
| `scan_tools` | `scan_tools` | `--tools=true` |
| `scan_github_actions` | `scan_github_actions` | `--ghactions=true` |
| `scan_ai_models` | `scan_ai_models` | `--ai-models=true` |
| `scan_container` | `scan_container` | `container scan` |
| `pr` / `pr_baseline` / `pr_incremental` | same | PR flags |
| `enable_pr_comments` | `enable_pr_comments` | `--enable-pr-comments` |
| `endorctl_version` / checksum | same | pinned install |

Deprecated GH inputs (`ci_run`, `ci_run_tags`) → use `pr` and `tags`.

## Phase 7 — optional validation

End-to-end checks against real repositories on Buildkite agents:

- Runbook: [docs/phase7-validation.md](docs/phase7-validation.md)
- Matrix pipeline: [.buildkite/pipeline.phase7.yml](.buildkite/pipeline.phase7.yml)
- Path config: [scripts/phase7/phase7.paths.env.example](scripts/phase7/phase7.paths.env.example)
- Maintainer Docker smoke tests: [contrib/phase7-local/](contrib/phase7-local/)

Evidence templates: [docs/phase7/evidence/README.md](docs/phase7/evidence/README.md).
Gap tracking: [docs/phase7/gap-report.md](docs/phase7/gap-report.md).

## Open questions

1. **Buildkite OIDC** — if/when endorctl supports generic CI OIDC, add first-class plugin support.
2. **Wrap-and-scan `command` hook** — optional pattern when the user command fails but scan should still run.
3. **Pre-installed endorctl** — `endorctl_skip_install: true` for agents with a baked binary.

## Out of scope

- Buildkite Test Analytics / GitHub Code Scanning upload integration
- Severity threshold CLI flags (use Endor policies + `additional_args`)
