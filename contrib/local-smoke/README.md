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
- `VALIDATION_WORK_DIR` pointing at a git checkout (for example OWASP Juice Shop)

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

Logs are written under `.validation-logs/` (gitignored). Scan JSON written under the
workdir (`endor-local-*.json`) may contain sensitive findings — do not commit them.

See [docs/maintainers/validation.md](../../docs/maintainers/validation.md) for the
Buildkite validation matrix runbook.
