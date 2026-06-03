# Changelog

All notable changes to this project are documented here.

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
  ([docs/customer-buildkite-setup.md](docs/customer-buildkite-setup.md) §2).

## [0.1.0] - 2026-06-02

Initial public release.

### Features

- `post-command` hook: install `endorctl`, authenticate, and scan (SCA, secrets, SAST, tools, GitHub Actions, AI models, Bazel, package)
- Container scan, PR baseline/incremental/comments, artifact sign/verify
- Buildkite branch/PR context mapping, annotations, soft-fail and policy exit handling, artifact upload
- Cloud keyless auth (AWS, Azure, GCP) and API-key auth via env-var indirection
- CI for this repository: GitHub Actions and `.buildkite/pipeline.yml` (shellcheck, plugin-linter, BATS)

### Documentation

- Customer setup: [docs/customer-buildkite-setup.md](docs/customer-buildkite-setup.md)
- Pipeline examples: [docs/examples.md](docs/examples.md)
- Reference build: [repro-sandbox](https://github.com/endorlabs/repro-sandbox)
