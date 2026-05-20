# Maintainer-only: local Docker smoke tests

Optional tooling for plugin maintainers. **Not required** to use the
[Endor Labs Buildkite plugin](https://github.com/endorlabs/endorlabs-buildkite-plugin)
in production pipelines.

These scripts run `hooks/post-command` with a real `endorctl` binary inside a
Linux container, mounting a local git checkout and credentials from a
**gitignored** `.env` at the repository root.

## Prerequisites

- Docker (Docker Desktop on Windows/macOS)
- A `.env` file with `ENDOR_API`, `ENDOR_API_CREDENTIALS_KEY`,
  `ENDOR_API_CREDENTIALS_SECRET`, and `ENDOR_NAMESPACE` (do not commit `.env`)
- `VALIDATION_WORK_DIR` pointing at a git checkout of
  [juice-shop v20.0.0](https://github.com/juice-shop/juice-shop/releases/tag/v20.0.0)
  (`git checkout f356a09207c7a9550eb6fc4c3945e081922cf998` after clone)

Do not set `ENDOR_TOKEN` in the same environment as API credentials; endorctl
returns exit code 4 for conflicting auth.

## Usage

From the **repository root**:

```bash
export VALIDATION_WORK_DIR=/path/to/your/checkout
bash contrib/local-smoke/local-smoke.sh baseline
```

```powershell
$env:VALIDATION_PLUGIN_DIR = (Get-Location).Path -replace '\\', '/'
$env:VALIDATION_WORK_DIR = "/path/to/your/checkout"
./contrib/local-smoke/run-docker-smoke.ps1 -Scenario baseline
```

Scenarios: `baseline`, `ai-models`, `soft-fail`, `container` (container needs Docker socket).

Logs and scan JSON are written under `.local/logs/` and `.local/scans/` in this
repository (gitignored). The Juice Shop checkout is not modified with scan outputs.

See [docs/maintainers/validation.md](../../docs/maintainers/validation.md) for the
Buildkite validation matrix runbook.
