# Endor Labs Buildkite Plugin

[![CI](https://github.com/endorlabs/endorlabs-buildkite-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/endorlabs/endorlabs-buildkite-plugin/actions/workflows/ci.yml)

Endor Labs is a unified application security platform that helps you ship secure
code by default. This repository is the **Buildkite plugin** for running
[endorctl](https://docs.endorlabs.com/developers-api/cli/commands/scan) in your
pipelines — product and CLI reference: [docs.endorlabs.com](https://docs.endorlabs.com/).

The plugin is aligned with the official
[Endor Labs GitHub Action](https://github.com/endorlabs/github-action) so the
same scan flags and outputs work across CI providers.

**New customer on Buildkite?** Follow [docs/getting-started.md](docs/getting-started.md)
(end-to-end: secrets → vendoring → first green build). Reference:
[docs/customer-buildkite-setup.md](docs/customer-buildkite-setup.md),
[docs/examples.md](docs/examples.md),
[docs/troubleshooting.md](docs/troubleshooting.md).

## Quick example (vendored plugin)

Run your step `command` first; the plugin `post-command` hook installs
`endorctl`, authenticates, and scans afterward.

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

Vendor with [`scripts/sync-vendor-endorlabs-plugin.sh`](scripts/sync-vendor-endorlabs-plugin.sh)
and commit `.buildkite/vendor/endorlabs-buildkite-plugin/` plus `VENDOR_SOURCE.json`.
After `v0.1.0` is public, you may use `endorlabs#v0.1.0` if agents can clone this repo.

Demo pipeline: [repro-sandbox](https://github.com/endorlabs/repro-sandbox) on Buildkite.

## Configuration

Schema is in [`plugin.yml`](plugin.yml); `additionalProperties: false`
means typos are rejected by the [buildkite/plugin-linter](https://github.com/buildkite-plugins/buildkite-plugin-linter) CLI at PR time.

### Core options

| Option | Required | Default | endorctl flag | Description |
|--------|----------|---------|---------------|-------------|
| `mode` | no | `scan` | command path | Execution mode: `scan`, `sign`, or `verify` |
| `namespace` | yes | — | `--namespace=` | Endor Labs tenant namespace |
| `api` | no | `https://api.endorlabs.com` | `--api=` | Endor Labs API endpoint |
| `api_key_env` | no\* | — | (env) | Name of env var holding the API key (mapped to `ENDOR_API_CREDENTIALS_KEY`) |
| `api_secret_env` | no\* | — | (env) | Name of env var holding the API secret (mapped to `ENDOR_API_CREDENTIALS_SECRET`) |
| `aws_role_arn` | no | — | `--aws-role-arn=` | AWS keyless auth target role ARN (for EC2/EKS with ambient AWS credentials) |
| `enable_azure_managed_identity` | no | `false` | `--enable-azure-managed-identity` | Azure keyless auth using managed identity |
| `gcp_service_account` | no | — | `--gcp-service-account=` | GCP keyless auth target service account (federation service account) |
| `scan_dependencies` | no | `true` | `--dependencies=true` | Run SCA dependency scan |
| `scan_secrets` | no | `false` | `--secrets=true` | Scan repository files for leaked secrets |
| `scan_sast` | no | `false` | `--sast=true` | Run SAST checks |
| `scan_tools` | no | `false` | `--tools=true` | Scan CI/CD tooling dependencies |
| `scan_github_actions` | no | `false` | `--ghactions=true` | Scan GitHub Actions workflow dependencies |
| `scan_ai_models` | no | `false` | `--ai-models=true` | Detect AI model usage (requires `scan_dependencies: true`) |
| `scan_git_logs` | no | `false` | `--git-logs=true` | Scan repository history for secrets (requires `scan_secrets: true`) |
| `scan_package` | no | `false` | `--package=true` | Scan artifact/package path (exclusive with repo scan kinds) |
| `scan_container` | no | `false` | `container scan` | Container scan mode (exclusive with repo/package scan kinds) |
| `project_name` | no\*\*\* | — | `--project-name=` | Project name for package scans (`scan_package: true`) |
| `image` | no\*\*\*\* | — | `--image=` | Container image reference when `scan_container: true` |
| `image_tar` | no\*\*\*\* | — | `--image-tar=` | Absolute path to container tarball (mutually exclusive with `image`) |
| `as_ref` | no | `false` | `--as-ref` | Keep container scan as persistent ref (typically with `project_name`) |
| `os_reachability` | no | `false` | `--os-reachability` | Enable OS package reachability analysis in container scans |
| `project_tags` | no | — | `--project-tags=` | Tags for container standalone project |
| `container_scan_path` | no | `.` | `--path=` | Repository path context for container scan association |
| `profiling_data_dir` | no | — | `--profiling-data-dir=` | Directory of collected profiling data for container reachability |
| `artifact_name` | yes (sign/verify) | — | `--name=` | Artifact identifier for `mode: sign` / `mode: verify` |
| `certificate_oidc_issuer` | yes (sign/verify) | — | `--certificate-oidc-issuer=` | OIDC issuer constraint for signing/verifying |
| `source_repository_ref` | yes (sign) | — | `--source-repository-ref=` | Source ref for artifact signing provenance |
| `certificate_identity` | no | — | `--certificate-identity=` | Certificate identity filter for signing |
| `source_repository` | no | — | `--source-repository=` | Source repository used during signing |
| `source_repository_owner` | no | — | `--source-repository-owner=` | Owner/organization of source repository |
| `source_repository_digest` | no | — | `--source-repository-digest=` | Source commit/digest for signing metadata |
| `build_config_name` | no | — | `--build-config-name=` | Top-level build config name for signing metadata |
| `build_config_digest` | no | — | `--build-config-digest=` | Top-level build config digest for signing metadata |
| `runner_environment` | no | — | `--runner-environment=` | Runner environment label for signing metadata |
| `phantom_dependencies` | no | `false` | `--phantom-dependencies=true` | Enable phantom dependency analysis |
| `disable_code_snippet_storage` | no | `false` | `--disable-code-snippet-storage=true` | Disable code snippet storage for SAST findings (requires `scan_sast: true`) |
| `use_bazel` | no | `false` | `--use-bazel=true` | Enable Bazel-aware scan mode |
| `bazel_include_targets` | no | — | `--bazel-include-targets=` | Comma-separated Bazel targets to include |
| `bazel_exclude_targets` | no | — | `--bazel-exclude-targets=` | Comma-separated Bazel targets to exclude |
| `bazel_targets_query` | no | — | `--bazel-targets-query=` | Bazel query used to discover targets |
| `scan_path` | no | repo root | `--path=` | Sub-directory to scan |
| `endorctl_version` | no | latest from API | (install) | Pin a specific endorctl release |
| `endorctl_checksum` | no\*\* | — | (install) | SHA-256 of the pinned binary (required when `endorctl_version` is set) |
| `endorctl_skip_install` | no | `false` | (install) | Set to `true` to use the `endorctl` already on the agent's PATH |
| `log_level` | no | `info` | `--log-level=` | endorctl log level |
| `log_verbose` | no | `false` | `--verbose=` | Verbose endorctl logging |
| `output_type` | no | `json` | `--output-type=` | Scan-summary format (`json`, `yaml`, `summary`, `table`) |
| `sarif_file` | no | — | `--sarif-file=` | Write SARIF results to file |
| `output_file` | no | — | (stdout tee) | Tee endorctl stdout to a file |
| `tags` | no | — | `--tags=` | Scan tags |
| `exit_on_policy_warning` | no | `false` | `--exit-on-policy-warning` | Treat policy warnings as failures |
| `annotate` | no | `false` | Buildkite `annotate` | Publish a sanitized Buildkite annotation after scan |
| `annotate_context` | no | (by mode) | `buildkite-agent annotate --context` | Unique per step when one build runs multiple scans; default `endorlabs-scan` (or container/sign/verify) |
| `soft_fail` | no | `false` | plugin behavior | Return success even when endorctl exits non-zero |
| `fail_on_policy` | no | `true` | plugin behavior | When false, convert policy exit `128` to success |
| `upload_artifacts` | no | `false` | Buildkite `artifact upload` | Upload `output_file` and/or `sarif_file` after command |
| `artifact_paths` | no | — | Buildkite `artifact upload` | Whitespace-delimited explicit artifact paths (overrides defaults) |
| `pr` | no | (auto) | `--pr=true` | When `false`, never emit PR scan flags, even if `BUILDKITE_PULL_REQUEST` is numeric. When omitted or `true`, PR mode follows a numeric pull request id or an explicit `pr_baseline` |
| `pr_baseline` | no | — | `--pr-baseline=` | Merge-target ref (e.g. `main`). Overrides `BUILDKITE_PULL_REQUEST_BASE_BRANCH` when both are set. With `enable_pr_comments` and no explicit value, endorctl infers the baseline from the PR merge target |
| `pr_incremental` | no | `false` | `--pr-incremental=true` | Incremental PR scan; requires numeric `BUILDKITE_PULL_REQUEST` or `pr_baseline`, and baseline context via `pr_baseline`, `BUILDKITE_PULL_REQUEST_BASE_BRANCH`, or `enable_pr_comments` |
| `enable_pr_comments` | no | `false` | `--enable-pr-comments=true` | Post policy findings as SCM review comments; requires a PR build, `pr` not `false`, and `scm_token_env` |
| `scm_token_env` | no | — | `--scm-token=` | Name of env var whose value is passed as `--scm-token` when `enable_pr_comments` is true (value is never printed; required with `enable_pr_comments`) |
| `additional_args` | no | — | (passthrough) | Whitespace-split flags appended verbatim |

\* If both `api_key_env` and `api_secret_env` are omitted, the plugin
falls back to pre-set `ENDOR_API_CREDENTIALS_KEY` / `ENDOR_API_CREDENTIALS_SECRET`
on the agent (matching endorctl's native env-var contract).

\*\* `endorctl_checksum` is required when `endorctl_version` is pinned
so that downloads can be verified offline. When `endorctl_version` is
unset, the checksum is fetched alongside the version from
`${api}/meta/version`.

\*\*\* `project_name` is required when `scan_package: true`.

\*\*\*\* One of `image` or `image_tar` is required when `scan_container: true`,
and they are mutually exclusive.

### Validation rules

The plugin fails fast for invalid combinations (mirroring the GitHub Action scan validation logic):

- `scan_package` is mutually exclusive with `scan_dependencies`, `scan_secrets`, `scan_sast`, and `scan_ai_models`
- `scan_container` requires one of `image` or `image_tar` (not both), and is mutually exclusive with all repo/package scan kinds
- `scan_ai_models` requires `scan_dependencies: true`
- `scan_git_logs` requires `scan_secrets: true`
- `disable_code_snippet_storage` requires `scan_sast: true`
- At least one scan kind must be enabled
- Exactly one auth mode must be configured: API key mode (`api_key_env`+`api_secret_env` or pre-exported `ENDOR_API_CREDENTIALS_*`), `aws_role_arn`, `enable_azure_managed_identity`, or `gcp_service_account`
- `pr_incremental` cannot be combined with `pr: false`, and requires PR id
  and/or baseline context (see option table)
- `enable_pr_comments` requires a numeric `BUILDKITE_PULL_REQUEST`, `pr` not
  `false`, and `scm_token_env` pointing to a non-empty token
- `mode: sign` and `mode: verify` reject any `scan_*` keys; `artifact_name` and
  `certificate_oidc_issuer` are required in both modes; `source_repository_ref`
  is additionally required in `mode: sign`

### Cloud keyless authentication

The plugin supports Endor keyless auth on AWS, Azure, and GCP using endorctl
global auth flags:

- **AWS:** set `aws_role_arn` (`--aws-role-arn=...`)
- **Azure:** set `enable_azure_managed_identity: true`
- **GCP:** set `gcp_service_account` (`--gcp-service-account=...`)

These modes are mutually exclusive with each other and with API-key auth mode.
For cloud modes, API keys are not required. This matches endorctl auth-mode
behavior and avoids conflicting credentials.

### Buildkite annotations

When `annotate: true`, the plugin calls `buildkite-agent annotate` after
`endorctl` finishes. It only publishes sanitized high-level status (and finding
count when JSON shape allows parsing), never secrets or raw credential values.

**Annotation `--context`** (Buildkite upsert key) defaults by mode so different
modes do not overwrite each other on the same build. For multiple scan steps in
one build (layered comparisons), set `annotate_context` on each step.

| Mode | Default `annotate --context` |
|------|------------------------------|
| `mode: scan` (repository) | `endorlabs-scan` |
| `mode: scan` with `scan_container: true` | `endorlabs-container` |
| `mode: sign` | `endorlabs-sign` |
| `mode: verify` | `endorlabs-verify` |

### Artifact signing and verification

Set `mode: sign` to run `endorctl artifact sign`, or `mode: verify` to run
`endorctl artifact verify`.

- **Sign required keys:** `artifact_name`, `certificate_oidc_issuer`, `source_repository_ref`
- **Verify required keys:** `artifact_name`, `certificate_oidc_issuer`

Both modes continue to use the same auth configuration (`api_key_env` /
cloud keyless), and support `additional_args` for advanced flags.

Sign and verify require tenant and artifact configuration in Endor Labs; the
plugin wires CLI flags only. See [docs/troubleshooting.md](docs/troubleshooting.md).

### Pull requests (auto-detect)

On pull-request builds, Buildkite sets `BUILDKITE_PULL_REQUEST` to the pull
request number (a string of digits). Outside PR builds it is the literal string
`false` or empty — the plugin treats non-numeric values as non-PR context and
does not emit `--pr` / `--scm-pr-id`.

When `pr` is omitted or `true`, a numeric `BUILDKITE_PULL_REQUEST` enables PR
scan flags. Set `pr: false` to force a non-PR scan even when those variables are
present (for example, to benchmark a full default-branch-style scan on a PR
agent).

`pr_baseline` defaults from `BUILDKITE_PULL_REQUEST_BASE_BRANCH` when you do
not set it explicitly, except when `enable_pr_comments` is `true` and you omit
`pr_baseline`: endorctl then infers the baseline from the PR merge target (see
[endorctl scan PR flags](https://docs.endorlabs.com/developers-api/cli/commands/scan)).

### PR comments (SCM token)

Posting review comments uses endorctl’s generic SCM flags (`--enable-pr-comments`,
`--scm-pr-id`, `--scm-token`), not GitHub-only flags. Your SCM integration must
support the commenting API Endor Labs expects (GitHub, GitLab, etc.); the
Buildkite plugin does not implement Buildkite-native OIDC for SCM — supply a
suitable token on the agent.

Set `enable_pr_comments: true` and `scm_token_env` to the **name** of an
environment variable that holds the PAT or token. The plugin reads the value and
passes it to endorctl; it never prints the token in logs. Align token permissions
with your SCM (for example, `pull-requests: write` on GitHub).

### Buildkite context mapping

These Buildkite environment variables are translated to endorctl flags
automatically:

| Buildkite env | endorctl flag | When |
|---------------|---------------|------|
| `BUILDKITE_BRANCH` | `--detached-ref-name=` | Always (CI usually checks out a detached SHA) |
| `BUILDKITE_PULL_REQUEST` (numeric) | `--pr=true`, `--scm-pr-id=` | PR builds when `pr` is not `false` |
| `BUILDKITE_PULL_REQUEST_BASE_BRANCH` | `--pr-baseline=` | PR builds when `pr_baseline` is unset and `enable_pr_comments` is not used |

## Hook strategy

The plugin defines a single `post-command` hook so the user's step
command (build / test / package) runs first and the scan runs after.
This avoids the duplicate-hook pitfall seen in some scanner plugins,
where shipping both `command` and `post-command` would silently replace
the user's command.

If you want compile-then-scan in a single step but need the scan to run
even when the user command fails, wrap the command yourself and invoke
the plugin from a downstream step.

### Scan outputs

`output_file`, `sarif_file`, and uploaded artifacts may contain sensitive findings.
The plugin does not log API keys or SCM tokens. See [SECURITY.md](SECURITY.md) and
[docs/troubleshooting.md](docs/troubleshooting.md).

## Hosted quickstart (Buildkite Elastic)

1. Set `ENDOR_NAMESPACE` and cluster secrets `ENDOR_API_CREDENTIALS_KEY` /
   `ENDOR_API_CREDENTIALS_SECRET`, and add a `secrets:` block in your pipeline
   YAML — see [docs/customer-buildkite-setup.md](docs/customer-buildkite-setup.md).
2. Prefer a **vendored** plugin path (`./.buildkite/vendor/endorlabs-buildkite-plugin:`)
   when the plugin repo is in another org; use a git URL only if agents can clone it.

```yaml
secrets:
  - ENDOR_NAMESPACE
  - ENDOR_API_CREDENTIALS_KEY
  - ENDOR_API_CREDENTIALS_SECRET

steps:
  - command: "make build"
    plugins:
      - endorlabs#v0.1.0:
          namespace: "${ENDOR_NAMESPACE}"
          api_key_env: ENDOR_API_CREDENTIALS_KEY
          api_secret_env: ENDOR_API_CREDENTIALS_SECRET
          annotate: true
```

Reference integration: [repro-sandbox](https://github.com/endorlabs/repro-sandbox)
`.buildkite/pipeline.yml`.

## Developing

See [CONTRIBUTING.md](CONTRIBUTING.md). Hosted end-to-end scans run in
[repro-sandbox](https://github.com/endorlabs/repro-sandbox) with a vendored copy
of this plugin.

Quick test run:

```bash
docker compose run --rm tests
```

PR scans, incremental mode, and SCM comments: [docs/troubleshooting.md](docs/troubleshooting.md).

## License

[Apache License 2.0](LICENSE).
