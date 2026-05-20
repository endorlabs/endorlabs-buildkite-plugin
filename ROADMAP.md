# Roadmap

Public usage: [README.md](README.md) and [docs/examples.md](docs/examples.md).

## Shipped in v0.1.0

- `post-command` hook: install `endorctl`, authenticate, scan (SCA, secrets, SAST, tools, GH Actions, AI models, Bazel, package), container scan, PR baseline/incremental/comments, artifact sign/verify
- Buildkite branch/PR context mapping, annotations, soft-fail and policy exit handling, artifact upload
- CI for this repo: GitHub Actions and `.buildkite/pipeline.yml` (shellcheck, plugin-linter, BATS only)

## Maintainer validation (optional)

Real-repo matrix and local Docker smoke tests are documented in
[docs/maintainers/validation.md](docs/maintainers/validation.md). They require
Endor credentials and cloned repositories on your agents; they are not part of
PR CI for this plugin repository.

## Open questions

1. **Buildkite OIDC** — if endorctl gains generic CI OIDC, add first-class plugin support.
2. **Wrap-and-scan `command` hook** — optional pattern when the user command fails but the scan should still run.
3. **Pre-installed endorctl** — `endorctl_skip_install: true` for agents with a baked binary.

## Out of scope

- Buildkite Test Analytics / GitHub Code Scanning upload integration
- Severity threshold CLI flags (use Endor policies and `additional_args`)
