# Changelog

All notable changes to this project are documented here.

## [Unreleased]

## [0.1.7] - 2026-06-09

### Changed

- Pass `--scm-pr-id` only when `enable_pr_comments` is true (matches endorctl
  validation and the GitHub Action). Default PR builds use `--pr` + `--pr-baseline`
  only.
- `annotate: true` and `output_file` capture endorctl JSON stdout to a file or
  temp path instead of teeing it into the Buildkite step log (endorctl has no
  `--output-file` flag).
- Document `--pr` (PR scan mode) vs `--scm-pr-id` (PR/MR identity) in README,
  `plugin.yml`, `docs/examples.md`, and `docs/troubleshooting.md`.
- Clarify that `enable_pr_comments` depends on SCM API access (GitHub/GitLab/
  Bitbucket per the Endor project), not Buildkite env alone.

## [0.1.6] - 2026-06-10

### Changed

- `plugin.yml` descriptions for `aws_role_arn`, `certificate_oidc_issuer`,
  `scm_token_env`, and `additional_args` clarify Buildkite OIDC vs Endor API auth,
  PR comment tokens, and artifact provenance issuers.
- `docs/troubleshooting.md` and `docs/examples.md` — same auth/OIDC guidance for
  Buildkite users.

## [0.1.5] - 2026-06-10

### Added

- Richer Buildkite annotations when `annotate: true`: scan-kind icon in title, status-line
  emojis by exit code, ✨ no findings / 📋 counts, 📊 blocking vs warning lists, severity
  breakdown, HTML table with reachability (✅ / ⚠️ / ➖), colored ● severity, category icons,
  up to two row badges (blocker, fix available, etc.), finding title, and clickable
  `location_urls` or SAST `custom.location` links (file:line when `#L` present). No code
  snippets in annotations; full JSON via `artifact://` link; ℹ️ hint when `jq` is missing.
  Links to the Endor Labs app: branch/PR findings tab (non-dismissed filter), and
  per-finding titles opening the findings drawer via `resourceDetail`.
- `annotate_scope` (`build` | `job`) and `annotate_findings_limit` plugin options.

### Changed

- `plugin.yml` option descriptions rewritten with markdown links to
  [docs.endorlabs.com](https://docs.endorlabs.com) for Buildkite plugin directory and
  docs-site rendering (replaces GitHub Actions–centric wording).

## [0.1.4] - 2026-06-03

### Fixed

- CI shellcheck: lint `hooks/post-command` and `lib/*.bash` only (exclude Windows
  `.bat`/`.ps1` wrappers).

## [0.1.3] - 2026-06-03

### Fixed

- **Policy exit precedence:** `soft_fail: true` no longer converts endorctl exit **128**
  (blocking admission policy) to a successful step when `fail_on_policy` is true (default).
  Use `fail_on_policy: false` on informational jobs to ignore policy blocks.

### Added

- BATS coverage (72 tests): credential argv invariants, `ENDOR_TOKEN` unset in API-key mode,
  pre-exported `ENDOR_API_CREDENTIALS_*`, `soft_fail` vs exit 128, annotate/upload edge cases,
  pinned endorctl install with checksum, `BUILDKITE_ENV_FILE` / MSYS / Windows wrapper contracts.

### Changed

- **Documentation:** single customer guide [`docs/setup.md`](docs/setup.md); slim
  [`README.md`](README.md) (options live in [`plugin.yml`](plugin.yml)).
- Removed redundant docs: `docs/getting-started.md`, `docs/customer-buildkite-setup.md`,
  `docs/release-checklist.md`; empty `scripts/validation/` directory.
- Maintainer release steps moved to [`CONTRIBUTING.md`](CONTRIBUTING.md).

### Documentation

- Policy / `soft_fail` / `fail_on_policy` precedence table in
  [`docs/troubleshooting.md`](docs/troubleshooting.md); `plugin.yml` and [`SECURITY.md`](SECURITY.md)
  updated to match.

## [0.1.2] - 2026-06-03

### Added

- Windows hook entrypoints per [Writing plugins](https://buildkite.com/docs/pipelines/integrations/plugins/writing):
  `hooks/post-command.bat` and `hooks/post-command.ps1` delegate to the Bash implementation
  (Git Bash required on Windows agents).

### Fixed

- Git Bash / MSYS: set `MSYS_NO_PATHCONV=1` during `post-command` and when loading
  `BUILDKITE_ENV_FILE` (matches docker-compose plugin pattern).

### Documentation

- README: Windows agent requirements; `docs/examples.md` examples use `v0.1.1` and document
  full GitHub plugin URL vs `endorlabs#` shorthand.

## [0.1.1] - 2026-06-03

### Fixed

- `post-command` sources `BUILDKITE_ENV_FILE` (and `BUILDKITE_TOOL_DIR`) so build tools
  installed in the step `command` are on `PATH` when `endorctl` runs.

### Documentation

- Agent and cluster build-tool prerequisites
  ([docs/setup.md](docs/setup.md) §2).

## [0.1.0] - 2026-06-02

Initial public release.

### Features

- `post-command` hook: install `endorctl`, authenticate, and scan (SCA, secrets, SAST, tools, GitHub Actions, AI models, Bazel, package)
- Container scan, PR baseline/incremental/comments, artifact sign/verify
- Buildkite branch/PR context mapping, annotations, soft-fail and policy exit handling, artifact upload
- Cloud keyless auth (AWS, Azure, GCP) and API-key auth via env-var indirection
- CI for this repository: GitHub Actions and `.buildkite/pipeline.yml` (shellcheck, plugin-linter, BATS)

### Documentation

- Customer setup: [docs/setup.md](docs/setup.md)
- Pipeline examples: [docs/examples.md](docs/examples.md)
- Reference build: [repro-sandbox](https://github.com/endorlabs/repro-sandbox)
