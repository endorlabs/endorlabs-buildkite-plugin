# Changelog

All notable changes to this project are documented here.

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
